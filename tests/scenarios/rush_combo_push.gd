extends "res://addons/arcade_core/testing/MovieScenario.gd"

var _ctx: Dictionary = {}
var _actions_total: int = 0
var _runs_started: int = 0
var _runs_finished: int = 0
var _score_final: int = 0
var _actions_at_300: int = 0
var _action_interval: int = 6
var _menu_action_interval: int = 12
var _menu_settle_frames: int = 10
var _last_menu_action_frame: int = -100000
var _game_enter_frame: int = -1
var _last_scene_path: String = ""
var _last_scene_id: int = 0


func setup(context: Dictionary) -> void:
	_ctx = context.duplicate(true)
	var persona: Dictionary = actor_persona()
	_action_interval = maxi(
		1,
		int(persona.get("gameplay_action_interval_frames", persona.get("action_interval_frames", 6)))
	)
	_menu_action_interval = maxi(1, int(persona.get("menu_action_interval_frames", 12)))
	_menu_settle_frames = maxi(0, int(persona.get("menu_settle_frames", 10)))


func step(frame: int, _delta: float) -> void:
	if frame == 300:
		_actions_at_300 = _actions_total
	var scene: Node = _current_scene()
	if scene == null:
		return
	var scene_path: String = str(scene.scene_file_path)
	var scene_id: int = scene.get_instance_id()
	var scene_changed: bool = scene_path != _last_scene_path or scene_id != _last_scene_id
	_track_scene_transition(scene, scene_path)
	if scene_changed and scene_path.ends_with("Game.tscn"):
		_game_enter_frame = frame

	if scene_path.ends_with("Boot.tscn"):
		if _can_menu_action(frame):
			var run_manager_boot: Node = _run_manager()
			if run_manager_boot != null and run_manager_boot.has_method("goto_menu"):
				run_manager_boot.call("goto_menu")
				_last_menu_action_frame = frame
		return
	if scene_path.ends_with("MainMenu.tscn"):
		if _can_menu_action(frame):
			var run_manager_menu: Node = _run_manager()
			if run_manager_menu != null and run_manager_menu.has_method("start_game"):
				run_manager_menu.call("start_game")
				_last_menu_action_frame = frame
		return
	if scene_path.ends_with("Results.tscn"):
		var run_manager_results: Node = _run_manager()
		if run_manager_results != null:
			_score_final = maxi(_score_final, int(run_manager_results.get("last_score")))
		return
	if not scene_path.ends_with("Game.tscn"):
		return
	if _game_enter_frame >= 0 and frame - _game_enter_frame < _menu_settle_frames:
		return
	if frame % _action_interval != 0:
		return
	if _perform_best_match(scene):
		_actions_total += 1
		_score_final = maxi(_score_final, int(scene.get("score")))


func collect_metrics() -> Dictionary:
	if _actions_at_300 == 0:
		_actions_at_300 = _actions_total
	return {
		"actions_total": _actions_total,
		"score_final": _score_final,
		"runs_started": _runs_started,
		"runs_finished": _runs_finished,
		"actions_at_300": _actions_at_300,
	}


func get_invariants() -> Array[Dictionary]:
	return [
		{"id": "actions_non_idle", "metric": "actions_total", "op": ">=", "value": 20},
		{"id": "run_started", "metric": "runs_started", "op": ">=", "value": 1},
		{"id": "score_progress", "metric": "score_final", "op": ">=", "value": 100},
	]


func get_checkpoints() -> Array[Dictionary]:
	return [
		{"id": "actions_by_300", "metric": "actions_at_300", "op": ">=", "value": 8},
		{"id": "single_run_started", "metric": "runs_started", "op": "==", "value": 1},
	]


func _perform_best_match(game_scene: Node) -> bool:
	var board_view: Node = game_scene.get_node_or_null("BoardView")
	if board_view == null:
		return false
	var board = board_view.get("board")
	if board == null:
		return false
	var best_cell := Vector2i(-1, -1)
	var best_size := 0
	for y in range(int(board_view.get("height"))):
		for x in range(int(board_view.get("width"))):
			var cell := Vector2i(x, y)
			var group: Array = board.find_group(cell)
			if group.size() > best_size:
				best_size = group.size()
				best_cell = cell
	if best_size < 2:
		return false

	var snapshot: Array = board.get("grid").duplicate(true)
	var selected_group: Array = board.find_group(best_cell)
	var resolved: Array = board.resolve_move(best_cell)
	if resolved.size() < 2:
		return false

	board_view.call("_normalize_board_color_ids")
	board_view.call("_clear_hint")
	board_view.call("_rebuild_tiles_from_grid")
	board_view.emit_signal("move_committed", selected_group, snapshot)
	board_view.emit_signal("match_made", selected_group)
	board_view.call("_check_no_moves_and_emit")
	return true


func _track_scene_transition(scene: Node, scene_path: String) -> void:
	var scene_id: int = scene.get_instance_id()
	if scene_path == _last_scene_path and scene_id == _last_scene_id:
		return
	if scene_path.ends_with("Game.tscn") and scene_id != _last_scene_id:
		_runs_started += 1
	if scene_path.ends_with("Results.tscn") and _last_scene_path.ends_with("Game.tscn"):
		_runs_finished += 1
	_last_scene_path = scene_path
	_last_scene_id = scene_id


func _current_scene() -> Node:
	var tree: SceneTree = _ctx.get("scene_tree")
	if tree == null:
		return null
	return tree.current_scene


func _run_manager() -> Node:
	var tree: SceneTree = _ctx.get("scene_tree")
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("RunManager")


func _can_menu_action(frame: int) -> bool:
	return frame - _last_menu_action_frame >= _menu_action_interval
