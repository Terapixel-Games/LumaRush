extends GdUnitTestSuite

func test_default_board_is_8_by_8() -> void:
	var view := BoardView.new()
	assert_that(view.width).is_equal(8)
	assert_that(view.height).is_equal(8)
	view.free()

func test_emits_no_moves_once_when_board_is_stalled() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 1, 2],
		[1, 2, 0],
		[2, 0, 1],
	]
	var emitted_count: Array[int] = [0]
	view.connect("no_moves", func() -> void:
		emitted_count[0] += 1
	)
	assert_that(view._check_no_moves_and_emit()).is_false()
	assert_that(view._check_no_moves_and_emit()).is_false()
	assert_that(emitted_count[0]).is_equal(1)
	view.queue_free()

func test_hint_group_is_selected_by_hint_powerup() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 0, 0],
		[1, 2, 1],
		[2, 1, 2],
	]
	view._refresh_tiles()
	var changed: bool = await view.apply_hint_powerup()
	assert_that(changed).is_true()
	assert_that(view._hint_group.size()).is_equal(3)
	view.queue_free()

func test_hint_powerup_returns_false_while_animating() -> void:
	var view := BoardView.new()
	get_tree().root.add_child(view)
	view._animating = true
	var changed: bool = await view.apply_hint_powerup()
	assert_that(changed).is_false()
	view.queue_free()

func test_initial_board_respects_required_matches_normalizer() -> void:
	ProjectSettings.set_setting("lumarush/gameplay_matches_normalizer", 2.0)
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 5
	view.height = 5
	view.colors = 4
	get_tree().root.add_child(view)
	assert_that(view.board.count_available_matches()).is_greater_equal(2)
	view.queue_free()

func test_restore_snapshot_restores_grid_state() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	var snapshot: Array = [
		[0, 0, 0],
		[1, 2, 1],
		[2, 1, 2],
	]
	view.restore_snapshot(snapshot)
	assert_that(view.board.grid).is_equal(snapshot)
	view.queue_free()

func test_remove_color_powerup_removes_tiles() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 0, 1],
		[1, 0, 2],
		[2, 1, 2],
	]
	view._refresh_tiles()
	var result: Dictionary = await view.apply_remove_color_powerup(0)
	assert_that(int(result.get("removed", 0))).is_equal(3)
	for y in range(view.height):
		for x in range(view.width):
			var tile: ColorRect = view.tiles[y][x] as ColorRect
			assert_that(tile).is_not_null()
			assert_that(tile.modulate.a).is_equal(1.0)
	view.queue_free()

func test_prism_pick_mode_emits_selected_color() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[2, 1, 0],
		[1, 0, 2],
		[0, 2, 1],
	]
	view._refresh_tiles()
	var selected_color: Array[int] = [-1]
	view.connect("prism_color_selected", func(color_idx: int) -> void:
		selected_color[0] = color_idx
	)
	view.set_prism_pick_mode(true)
	view._handle_click(Vector2(8, 8))
	assert_that(selected_color[0]).is_equal(2)
	view.queue_free()

func test_match_feedback_emits_matched_color_index() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[2, 2, 2],
		[1, 0, 1],
		[0, 1, 0],
	]
	view._refresh_tiles()
	var emitted_color_idx: Array[int] = [-1]
	view.connect("match_feedback", func(_group: Array, _center: Vector2, color_idx: int) -> void:
		emitted_color_idx[0] = color_idx
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(8, 8)
	get_tree().root.push_input(click)
	await get_tree().process_frame
	assert_that(emitted_color_idx[0]).is_equal(2)
	view.queue_free()

func test_board_view_normalizes_to_palette_and_matches_exact_color() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 8
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 5, 1],
		[5, 0, 2],
		[3, 4, 6],
	]
	view._normalize_board_color_ids()
	assert_that(int(view.board.grid[0][1])).is_equal(0)
	assert_that(int(view.board.grid[1][0])).is_equal(0)
	var group: Array = view.board.find_group(Vector2i(0, 0))
	assert_that(group.size()).is_equal(4)
	view.queue_free()

func test_cell_from_screen_pos_accounts_for_board_position() -> void:
	var view := BoardView.new()
	view.width = 8
	view.height = 10
	view.tile_size = 96.0
	view.position = Vector2(156, 420)
	get_tree().root.add_child(view)
	var cell: Vector2i = view._cell_from_screen_pos(Vector2(156 + 96 * 2 + 8, 420 + 96 * 3 + 8))
	assert_that(cell).is_equal(Vector2i(2, 3))
	view.queue_free()

func test_board_input_can_be_disabled() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 0, 0],
		[1, 2, 1],
		[2, 1, 2],
	]
	view._refresh_tiles()
	var snapshot: Array = view.capture_snapshot()
	var committed: Array[bool] = [false]
	view.connect("move_committed", func(_group: Array, _snapshot: Array) -> void:
		committed[0] = true
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(8, 8)
	view.set_board_input_enabled(false)
	view._input(click)
	await get_tree().process_frame

	assert_that(view.is_board_input_enabled()).is_false()
	assert_that(committed[0]).is_false()
	assert_that(view.capture_snapshot()).is_equal(snapshot)
	view.set_board_input_enabled(true)
	assert_that(view.is_board_input_enabled()).is_true()
	view.queue_free()

func test_click_during_match_animation_replays_after_settle() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 6
	view.height = 4
	view.colors = 5
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 0, 0, 1, 2, 3],
		[1, 2, 3, 0, 1, 2],
		[2, 3, 1, 1, 2, 3],
		[3, 4, 2, 4, 4, 4],
	]
	view._refresh_tiles()
	var feedback_count: Array[int] = [0]
	view.connect("match_feedback", func(_group: Array, _center: Vector2, _color_idx: int) -> void:
		feedback_count[0] += 1
	)

	view._input(_make_mouse_click(Vector2(8.0, 8.0)))
	assert_that(feedback_count[0]).is_equal(1)
	view._input(_make_mouse_click(Vector2(16.0 * 3.0 + 8.0, 16.0 * 3.0 + 8.0)))

	await get_tree().create_timer(1.4).timeout
	assert_that(feedback_count[0]).is_equal(2)
	assert_that(view.get("_queued_click_pending")).is_false()
	view.queue_free()

func test_disabling_board_input_clears_queued_animation_click() -> void:
	ProjectSettings.set_setting("lumarush/min_match_size", 3)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	view.colors = 3
	view.tile_size = 16.0
	get_tree().root.add_child(view)
	view.board.grid = [
		[0, 0, 0],
		[1, 2, 1],
		[2, 1, 2],
	]
	view._refresh_tiles()
	view.set("_animating", true)
	view.set("_queue_clicks_after_animation", true)
	view._input(_make_mouse_click(Vector2(8.0, 8.0)))
	assert_that(view.get("_queued_click_pending")).is_true()

	view.set_board_input_enabled(false)
	assert_that(view.get("_queued_click_pending")).is_false()
	view.queue_free()

func test_legacy_tile_design_uses_squarer_shader_profile() -> void:
	ProjectSettings.set_setting("lumarush/tile_design_mode", FeatureFlags.TileDesignMode.LEGACY)
	var view := BoardView.new()
	view.width = 3
	view.height = 3
	get_tree().root.add_child(view)
	var mat: ShaderMaterial = view.tiles[0][0].material as ShaderMaterial
	assert_that(float(mat.get_shader_parameter("corner_radius"))).is_less_equal(0.07)
	assert_that(float(mat.get_shader_parameter("border"))).is_less_equal(0.06)
	view.queue_free()
	ProjectSettings.set_setting("lumarush/tile_design_mode", FeatureFlags.TileDesignMode.MODERN)

func test_modern_tile_palette_has_distinct_color_families() -> void:
	_assert_palette_is_distinct(BoardView.TILE_PALETTE_MODERN)
	for theme_id in [ThemeManager.THEME_DEFAULT, ThemeManager.THEME_NEON]:
		var config: Dictionary = ThemeManager.get_theme_config(theme_id)
		_assert_palette_is_distinct(config.get("tile_palette", []))

func test_default_and_neon_themes_use_modern_neon_tile_palette() -> void:
	for theme_id in [ThemeManager.THEME_DEFAULT, ThemeManager.THEME_NEON]:
		var config: Dictionary = ThemeManager.get_theme_config(theme_id)
		assert_that(config.get("tile_palette", [])).is_equal(BoardView.TILE_PALETTE_MODERN)

func test_tile_symbols_use_contrasting_foreground_colors() -> void:
	var view := BoardView.new()
	for color in BoardView.TILE_PALETTE_MODERN:
		var symbol_color: Color = view.call("_symbol_color_for_tile", color)
		assert_that(_contrast_ratio(color, symbol_color)).is_greater_equal(3.0)

func test_match_haptic_signal_emits_when_enabled() -> void:
	ProjectSettings.set_setting("lumarush/haptics_enabled", true)
	ProjectSettings.set_setting("lumarush/match_haptic_duration_ms", 20)
	ProjectSettings.set_setting("lumarush/match_haptic_amplitude", 0.4)
	var view := BoardView.new()
	get_tree().root.add_child(view)
	var emitted: Array[bool] = [false]
	var emitted_ms: Array[int] = [-1]
	var emitted_amp: Array[float] = [-1.0]
	view.connect("match_haptic_triggered", func(ms: int, amp: float) -> void:
		emitted[0] = true
		emitted_ms[0] = ms
		emitted_amp[0] = amp
	)
	assert_that(view._trigger_match_haptic()).is_true()
	assert_that(emitted[0]).is_true()
	assert_that(emitted_ms[0]).is_equal(20)
	assert_that(emitted_amp[0]).is_equal(0.4)
	view.queue_free()

func test_match_haptic_disabled_does_not_emit() -> void:
	ProjectSettings.set_setting("lumarush/haptics_enabled", false)
	var view := BoardView.new()
	get_tree().root.add_child(view)
	var emitted: Array[bool] = [false]
	view.connect("match_haptic_triggered", func(_ms: int, _amp: float) -> void:
		emitted[0] = true
	)
	assert_that(view._trigger_match_haptic()).is_false()
	assert_that(emitted[0]).is_false()
	view.queue_free()

func test_match_click_haptic_signal_emits_when_enabled() -> void:
	ProjectSettings.set_setting("lumarush/haptics_enabled", true)
	ProjectSettings.set_setting("lumarush/match_click_haptic_duration_ms", 12)
	ProjectSettings.set_setting("lumarush/match_click_haptic_amplitude", 0.3)
	var view := BoardView.new()
	get_tree().root.add_child(view)
	var emitted: Array[bool] = [false]
	var emitted_ms: Array[int] = [-1]
	var emitted_amp: Array[float] = [-1.0]
	view.connect("match_click_haptic_triggered", func(ms: int, amp: float) -> void:
		emitted[0] = true
		emitted_ms[0] = ms
		emitted_amp[0] = amp
	)
	assert_that(view._trigger_match_click_haptic()).is_true()
	assert_that(emitted[0]).is_true()
	assert_that(emitted_ms[0]).is_equal(12)
	assert_that(emitted_amp[0]).is_equal(0.3)
	view.queue_free()

func _assert_palette_is_distinct(palette: Array) -> void:
	assert_that(palette.size()).is_equal(5)
	assert_that((palette[1] as Color).g).is_less(0.36)
	assert_that((palette[1] as Color).b).is_less(0.18)
	assert_that((palette[4] as Color).r).is_less(0.36)
	assert_that((palette[4] as Color).b).is_greater(0.90)
	for i in range(palette.size()):
		for j in range(i + 1, palette.size()):
			assert_that(_rgb_distance(palette[i] as Color, palette[j] as Color)).is_greater_equal(0.45)

func _rgb_distance(a: Color, b: Color) -> float:
	var dr: float = a.r - b.r
	var dg: float = a.g - b.g
	var db: float = a.b - b.b
	return sqrt((dr * dr) + (dg * dg) + (db * db))

func _relative_luminance(color: Color) -> float:
	return (color.r * 0.2126) + (color.g * 0.7152) + (color.b * 0.0722)

func _contrast_ratio(a: Color, b: Color) -> float:
	var high: float = max(_relative_luminance(a), _relative_luminance(b))
	var low: float = min(_relative_luminance(a), _relative_luminance(b))
	return (high + 0.05) / (low + 0.05)

func _make_mouse_click(position: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	return click
