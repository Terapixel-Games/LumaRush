extends "res://tests/framework/TestCase.gd"

const PHASE_FRAME_MS := 200.0


func test_first_match_perf_metrics_are_recorded() -> void:
	var metrics: Dictionary = _run_driver_with_metrics("rush_combo_push", 1200, 5511, "balanced")
	_assert_common_perf_metrics(metrics, "rush_combo_push")
	_assert_metric_at_least(metrics, "first_game_entry_frame", 0)
	_assert_metric_at_least(metrics, "first_match_action_frame", 0)
	_assert_metric_at_least(metrics, "first_results_entry_frame", 0)
	_assert_metric_at_least(metrics, "perf_first_game_entry_window_frames", 1)
	_assert_metric_at_least(metrics, "perf_first_match_action_window_frames", 1)
	_assert_metric_at_least(metrics, "perf_first_results_entry_window_frames", 1)
	_assert_metric_less_equal(metrics, "perf_first_match_action_window_max_frame_ms", PHASE_FRAME_MS)
	_assert_metric_less_equal(metrics, "perf_first_results_entry_window_max_frame_ms", PHASE_FRAME_MS)


func test_powerup_results_and_restart_perf_metrics_are_recorded() -> void:
	var metrics: Dictionary = _run_driver_with_metrics("rush_powerup_recovery", 1200, 5512, "manic")
	_assert_common_perf_metrics(metrics, "rush_powerup_recovery")
	_assert_metric_at_least(metrics, "runs_started", 2)
	_assert_metric_at_least(metrics, "first_match_action_frame", 0)
	_assert_metric_at_least(metrics, "first_powerup_action_frame", 0)
	_assert_metric_at_least(metrics, "perf_first_match_action_window_frames", 1)
	_assert_metric_at_least(metrics, "perf_first_powerup_action_window_frames", 1)
	_assert_metric_less_equal(metrics, "perf_first_match_action_window_max_frame_ms", PHASE_FRAME_MS)
	_assert_metric_less_equal(metrics, "perf_first_powerup_action_window_max_frame_ms", PHASE_FRAME_MS)


func _run_driver_with_metrics(scenario_id: String, frames: int, seed: int, persona: String) -> Dictionary:
	var exe_path: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var metrics_path: String = ProjectSettings.globalize_path(
		"user://perf_uat/%s_%d.json" % [scenario_id, seed]
	)
	DirAccess.make_dir_recursive_absolute(metrics_path.get_base_dir())
	if FileAccess.file_exists(metrics_path):
		DirAccess.remove_absolute(metrics_path)

	var output: Array = []
	var args := PackedStringArray([
		"--headless",
		"--path", project_path,
		"--script", "res://tools/capture/ScenarioDriver.gd",
		"--",
		"--mode=perf",
		"--strictness=hybrid",
		"--persona=%s" % persona,
		"--scenario_id=%s" % scenario_id,
		"--frames=%d" % frames,
		"--seed=%d" % seed,
		"--metrics_json=%s" % metrics_path,
	])
	var code: int = OS.execute(exe_path, args, output, true)
	if code != 0:
		fail("driver output: %s" % "\n".join(output))
		return {}
	if not FileAccess.file_exists(metrics_path):
		fail("metrics file was not written: %s" % metrics_path)
		return {}

	var file := FileAccess.open(metrics_path, FileAccess.READ)
	if file == null:
		fail("metrics file could not be opened: %s" % metrics_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		fail("metrics JSON was not an object: %s" % metrics_path)
		return {}
	return parsed as Dictionary


func _assert_common_perf_metrics(metrics: Dictionary, scenario_id: String) -> void:
	assert_equal(metrics.get("status", ""), "ok", "%s scenario should pass" % scenario_id)
	assert_equal(metrics.get("scenario_id", ""), scenario_id, "scenario id should be preserved")
	_assert_metric_at_least(metrics, "frames_run", 1)
	_assert_metric_at_least(metrics, "perf_frames_timed", 1)
	assert_equal(
		int(metrics.get("perf_frames_timed", -1)),
		int(metrics.get("frames_run", -2)),
		"all scenario frames should be timed"
	)
	_assert_metric_less_equal(metrics, "perf_p95_frame_ms", PHASE_FRAME_MS)


func _assert_metric_at_least(metrics: Dictionary, key: String, expected: float) -> void:
	if not metrics.has(key):
		fail("missing metric: %s" % key)
		return
	var actual: float = float(metrics.get(key))
	if actual < expected:
		fail("metric %s expected >= %s but got %s" % [key, str(expected), str(actual)])


func _assert_metric_less_equal(metrics: Dictionary, key: String, expected: float) -> void:
	if not metrics.has(key):
		fail("missing metric: %s" % key)
		return
	var actual: float = float(metrics.get(key))
	if actual > expected:
		fail("metric %s expected <= %s but got %s" % [key, str(expected), str(actual)])
