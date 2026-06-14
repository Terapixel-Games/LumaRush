extends RefCounted
class_name MovieScenarioRunner

const RESULT_SCRIPT := preload("res://addons/arcade_core/testing/MovieScenarioResult.gd")


func run(scene_tree: SceneTree, scenario: Object, context: Dictionary) -> Dictionary:
	var ctx: Dictionary = context.duplicate(true)
	var result: Dictionary = RESULT_SCRIPT.make_base(ctx)
	var frames_requested: int = maxi(1, int(ctx.get("frames", 1800)))
	var fps: float = maxf(1.0, float(ctx.get("fps", 60.0)))
	var strictness: String = str(ctx.get("strictness", "hybrid")).strip_edges().to_lower()
	var frame_times_ms: Array[float] = []

	ctx["frames_requested"] = frames_requested
	ctx["fps"] = fps
	if scenario == null or not scenario.has_method("setup"):
		RESULT_SCRIPT.add_error(result, "scenario instance is invalid or missing setup()")
		RESULT_SCRIPT.finalize(result)
		return result
	scenario.call("setup", ctx)

	var frames_run := 0
	while frames_run < frames_requested:
		var frame_start_usec: int = Time.get_ticks_usec()
		scenario.call("step", frames_run, 1.0 / fps)
		frames_run += 1
		await scene_tree.process_frame
		var frame_elapsed_ms: float = float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
		frame_times_ms.append(frame_elapsed_ms)
		if scenario.has_method("is_complete") and bool(scenario.call("is_complete")):
			break

	result["frames_run"] = frames_run
	var raw_metrics: Variant = scenario.call("collect_metrics")
	var metrics: Dictionary = {}
	if typeof(raw_metrics) == TYPE_DICTIONARY:
		metrics = (raw_metrics as Dictionary).duplicate(true)
	metrics["frames_run"] = frames_run
	metrics.merge(_summarize_frame_times(frame_times_ms), true)
	metrics.merge(_summarize_marked_windows(frame_times_ms, metrics), true)
	RESULT_SCRIPT.apply_metrics(result, metrics)

	var raw_invariants: Variant = scenario.call("get_invariants")
	var invariants: Array[Dictionary] = []
	if typeof(raw_invariants) == TYPE_ARRAY:
		invariants = raw_invariants
	var invariant_eval: Dictionary = _evaluate_rules(invariants, metrics)
	result["invariants_passed"] = int(invariant_eval.get("failed_count", 0)) == 0
	for line in invariant_eval.get("messages", []):
		RESULT_SCRIPT.add_error(result, str(line))

	var checkpoint_eval := {
		"passed_count": 0,
		"failed_count": 0,
		"messages": [],
	}
	var checkpoints: Array[Dictionary] = []
	var raw_checkpoints: Variant = scenario.call("get_checkpoints")
	if typeof(raw_checkpoints) == TYPE_ARRAY:
		checkpoints = raw_checkpoints
	if strictness != "invariants":
		checkpoint_eval = _evaluate_rules(checkpoints, metrics)
		result["checkpoint_passed_count"] = int(checkpoint_eval.get("passed_count", 0))
		result["checkpoint_failed_count"] = int(checkpoint_eval.get("failed_count", 0))
		for line in checkpoint_eval.get("messages", []):
			RESULT_SCRIPT.add_error(result, str(line))
	if strictness == "deterministic" and checkpoints.is_empty():
		RESULT_SCRIPT.add_error(
			result,
			"deterministic strictness requires scenario checkpoints, but none were provided"
		)

	RESULT_SCRIPT.finalize(result)
	return result


func _summarize_frame_times(frame_times_ms: Array[float]) -> Dictionary:
	if frame_times_ms.is_empty():
		return {
			"perf_frames_timed": 0,
			"perf_avg_frame_ms": 0.0,
			"perf_max_frame_ms": 0.0,
			"perf_p95_frame_ms": 0.0,
			"perf_p99_frame_ms": 0.0,
			"perf_hitch_count_33ms": 0,
			"perf_hitch_count_50ms": 0,
			"perf_hitch_count_100ms": 0,
			"perf_worst_frame_index": -1,
		}

	var total := 0.0
	var max_frame := 0.0
	var worst_frame_index := -1
	var hitch_count_33ms := 0
	var hitch_count_50ms := 0
	var hitch_count_100ms := 0
	for index in range(frame_times_ms.size()):
		var frame_ms: float = frame_times_ms[index]
		total += frame_ms
		if frame_ms > max_frame:
			max_frame = frame_ms
			worst_frame_index = index
		if frame_ms > 33.333:
			hitch_count_33ms += 1
		if frame_ms > 50.0:
			hitch_count_50ms += 1
		if frame_ms > 100.0:
			hitch_count_100ms += 1

	var sorted_times: Array[float] = frame_times_ms.duplicate()
	sorted_times.sort()
	return {
		"perf_frames_timed": frame_times_ms.size(),
		"perf_avg_frame_ms": total / float(frame_times_ms.size()),
		"perf_max_frame_ms": max_frame,
		"perf_p95_frame_ms": _percentile(sorted_times, 0.95),
		"perf_p99_frame_ms": _percentile(sorted_times, 0.99),
		"perf_hitch_count_33ms": hitch_count_33ms,
		"perf_hitch_count_50ms": hitch_count_50ms,
		"perf_hitch_count_100ms": hitch_count_100ms,
		"perf_worst_frame_index": worst_frame_index,
	}


func _summarize_marked_windows(frame_times_ms: Array[float], metrics: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_add_window_summary(out, frame_times_ms, "perf_first_game_entry", int(metrics.get("first_game_entry_frame", -1)), 2, 10)
	_add_window_summary(out, frame_times_ms, "perf_first_match_action", int(metrics.get("first_match_action_frame", -1)), 2, 10)
	_add_window_summary(out, frame_times_ms, "perf_first_results_entry", int(metrics.get("first_results_entry_frame", -1)), 2, 10)
	_add_window_summary(out, frame_times_ms, "perf_first_powerup_action", int(metrics.get("first_powerup_action_frame", -1)), 2, 10)
	return out


func _add_window_summary(
	out: Dictionary,
	frame_times_ms: Array[float],
	prefix: String,
	center_frame: int,
	frames_before: int,
	frames_after: int
) -> void:
	if center_frame < 0 or frame_times_ms.is_empty():
		out["%s_window_frames" % prefix] = 0
		out["%s_window_max_frame_ms" % prefix] = 0.0
		out["%s_window_hitch_count_33ms" % prefix] = 0
		out["%s_window_hitch_count_50ms" % prefix] = 0
		return

	var start_index: int = clampi(center_frame - frames_before, 0, frame_times_ms.size() - 1)
	var end_index: int = clampi(center_frame + frames_after, 0, frame_times_ms.size() - 1)
	var max_frame := 0.0
	var hitch_count_33ms := 0
	var hitch_count_50ms := 0
	for index in range(start_index, end_index + 1):
		var frame_ms: float = frame_times_ms[index]
		max_frame = maxf(max_frame, frame_ms)
		if frame_ms > 33.333:
			hitch_count_33ms += 1
		if frame_ms > 50.0:
			hitch_count_50ms += 1
	out["%s_window_frames" % prefix] = end_index - start_index + 1
	out["%s_window_max_frame_ms" % prefix] = max_frame
	out["%s_window_hitch_count_33ms" % prefix] = hitch_count_33ms
	out["%s_window_hitch_count_50ms" % prefix] = hitch_count_50ms


func _percentile(sorted_times: Array[float], percentile: float) -> float:
	if sorted_times.is_empty():
		return 0.0
	var index: int = int(ceil(percentile * float(sorted_times.size()))) - 1
	index = clampi(index, 0, sorted_times.size() - 1)
	return sorted_times[index]


func _evaluate_rules(rules: Array[Dictionary], metrics: Dictionary) -> Dictionary:
	var passed_count := 0
	var failed_count := 0
	var messages: Array[String] = []

	for index in range(rules.size()):
		var rule: Dictionary = rules[index]
		var rule_id: String = str(rule.get("id", "rule_%d" % index))
		var ok := false
		var detail: String = ""

		if rule.has("ok"):
			ok = bool(rule.get("ok", false))
			detail = str(rule.get("message", "explicit rule failed"))
		elif rule.has("metric") and rule.has("op") and rule.has("value"):
			var metric_key: String = str(rule.get("metric", ""))
			var op: String = str(rule.get("op", "==")).strip_edges()
			var expected: Variant = rule.get("value")
			if not metrics.has(metric_key):
				ok = false
				detail = "missing metric '%s'" % metric_key
			else:
				var actual: Variant = metrics.get(metric_key)
				ok = _compare_values(actual, op, expected)
				if not ok:
					detail = "metric '%s' expected %s %s but got %s" % [
						metric_key,
						op,
						str(expected),
						str(actual),
					]
		else:
			ok = false
			detail = "rule is missing either 'ok' or ('metric','op','value')"

		if ok:
			passed_count += 1
		else:
			failed_count += 1
			if detail.is_empty():
				detail = str(rule.get("message", "rule failed"))
			messages.append("[%s] %s" % [rule_id, detail])

	return {
		"passed_count": passed_count,
		"failed_count": failed_count,
		"messages": messages,
	}


func _compare_values(actual: Variant, op: String, expected: Variant) -> bool:
	match op:
		"==":
			return actual == expected
		"!=":
			return actual != expected
		">", ">=", "<", "<=":
			if not _is_numeric(actual) or not _is_numeric(expected):
				return false
			var a: float = float(actual)
			var b: float = float(expected)
			match op:
				">":
					return a > b
				">=":
					return a >= b
				"<":
					return a < b
				"<=":
					return a <= b
		_:
			return false
	return false


func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
