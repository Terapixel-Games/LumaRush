extends GdUnitTestSuite

func test_gameplay_layout_stays_inside_wide_short_viewports() -> void:
	var original_window_size: Vector2i = DisplayServer.window_get_size()
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var board: BoardView = game.get_node_or_null("BoardView") as BoardView
	var board_frame: Control = game.get_node_or_null("UI/BoardFrame") as Control
	var top_bar_bg: Control = game.get_node_or_null("UI/TopBarBg") as Control
	var top_bar: Control = game.get_node_or_null("UI/TopBar") as Control
	var top_right_bar: Control = game.get_node_or_null("UI/TopRightBar") as Control
	var score_box: Control = game.get_node_or_null("UI/TopBar/ScoreBox") as Control
	var score_caption: Control = game.get_node_or_null("UI/TopBar/ScoreBox/ScoreCaption") as Control
	var score_value: Control = game.get_node_or_null("UI/TopBar/ScoreBox/ScoreValue") as Control
	var pause_button: Control = game.get_node_or_null("UI/TopBar/Pause") as Control
	var pause_icon: Control = game.get_node_or_null("UI/TopBar/Pause/Center/PauseIcon") as Control
	var top_bar_inner_highlight: Control = game.get_node_or_null("UI/TopBarBg/TopBarInnerHighlight") as Control
	var cabinet_title: Label = game.get_node_or_null("UI/CabinetTitle") as Label
	var combo_pod: Label = game.get_node_or_null("UI/TopBar/ComboPod") as Label
	var rival_pod: Label = game.get_node_or_null("UI/TopBar/RivalPod") as Label
	var pressure_hud: Control = game.get_node_or_null("UI/PressureHud") as Control
	var pressure_heat: Label = game.get_node_or_null("UI/PressureHud/Margin/Row/Heat") as Label
	var pressure_rival: Label = game.get_node_or_null("UI/PressureHud/Margin/Row/Rival") as Label
	var pressure_matches: Label = game.get_node_or_null("UI/PressureHud/Margin/Row/Matches") as Label
	var pressure_meter: ProgressBar = game.get_node_or_null("UI/PressureHud/Margin/Row/RivalMeter") as ProgressBar
	var pressure_glow: ColorRect = game.get_node_or_null("UI/PressureHud/Margin/Row/RivalMeter/PressureGlow") as ColorRect
	var account_button: Control = game.get_node_or_null("UI/TopRightBar/Account") as Control
	var shop_button: Control = game.get_node_or_null("UI/TopRightBar/Shop") as Control
	var audio_button: Control = game.get_node_or_null("UI/TopRightBar/Audio") as Control
	var powerups_row: Control = game.get_node_or_null("UI/Powerups") as Control
	var undo_button: Control = game.get_node_or_null("UI/Powerups/Undo") as Control
	var combo_drain_ring: Control = game.get_node_or_null("UI/TopBar/ComboPod/ComboDrainRing") as Control
	assert_that(board).is_not_null()
	assert_that(board_frame).is_not_null()
	assert_that(top_bar_bg).is_not_null()
	assert_that(top_bar).is_not_null()
	assert_that(top_right_bar).is_not_null()
	assert_that(score_box).is_not_null()
	assert_that(score_caption).is_not_null()
	assert_that(score_value).is_not_null()
	assert_that(pause_button).is_not_null()
	assert_that(pause_icon).is_not_null()
	assert_that(top_bar_inner_highlight).is_not_null()
	assert_that(cabinet_title).is_not_null()
	assert_that(cabinet_title.text).is_equal("LUMARUSH")
	assert_that(combo_pod).is_not_null()
	assert_that(rival_pod).is_not_null()
	assert_that(combo_pod.text).contains("COMBO")
	assert_that(rival_pod.text).contains("RIVAL")
	assert_that(pressure_hud).is_not_null()
	assert_that(pressure_heat).is_not_null()
	assert_that(pressure_rival).is_not_null()
	assert_that(pressure_matches).is_not_null()
	assert_that(pressure_meter).is_not_null()
	assert_that(pressure_glow).is_not_null()
	assert_that(combo_drain_ring).is_not_null()
	assert_that(combo_drain_ring.visible).is_false()
	assert_that(pressure_heat.text).contains("HEAT")
	assert_that(pressure_rival.text).contains("RIVAL")
	assert_that(pressure_matches.text).contains("LIVE MATCHES")
	assert_that(account_button).is_not_null()
	assert_that(shop_button).is_not_null()
	assert_that(audio_button).is_not_null()
	assert_that(powerups_row).is_not_null()
	assert_that(undo_button).is_not_null()
	assert_that(board.width).is_equal(8)
	assert_that(board.height).is_equal(8)

	var viewport_sizes: Array[Vector2] = [
		Vector2(573.0, 967.0),
		Vector2(1898.0, 967.0),
		Vector2(1920.0, 1010.0),
		Vector2(1920.0, 720.0),
		Vector2(2560.0, 900.0),
		Vector2(2560.0, 720.0),
	]
	for size in viewport_sizes:
		DisplayServer.window_set_size(Vector2i(size))
		await get_tree().process_frame
		await get_tree().process_frame
		game.call("_center_board")
		await get_tree().process_frame
		var viewport_rect := Rect2(Vector2.ZERO, game.get_viewport_rect().size)
		var top_bg_rect: Rect2 = top_bar_bg.get_global_rect()
		var top_rect: Rect2 = top_bar.get_global_rect()
		var top_right_rect: Rect2 = top_right_bar.get_global_rect()
		var account_rect: Rect2 = account_button.get_global_rect()
		var shop_rect: Rect2 = shop_button.get_global_rect()
		var audio_rect: Rect2 = audio_button.get_global_rect()
		var score_box_rect: Rect2 = score_box.get_global_rect()
		var score_caption_rect: Rect2 = score_caption.get_global_rect()
		var score_value_rect: Rect2 = score_value.get_global_rect()
		var score_stack_rect: Rect2 = score_caption_rect.merge(score_value_rect)
		var pause_rect: Rect2 = pause_button.get_global_rect()
		var pause_icon_rect: Rect2 = pause_icon.get_global_rect()
		var inner_highlight_rect: Rect2 = top_bar_inner_highlight.get_global_rect()
		var cabinet_title_rect: Rect2 = cabinet_title.get_global_rect()
		var combo_pod_rect: Rect2 = combo_pod.get_global_rect()
		var rival_pod_rect: Rect2 = rival_pod.get_global_rect()
		var pressure_rect: Rect2 = pressure_hud.get_global_rect()
		var powerups_rect: Rect2 = powerups_row.get_global_rect()
		var undo_rect: Rect2 = undo_button.get_global_rect()
		var board_rect := Rect2(
			board.global_position,
			Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
		)
		var board_frame_rect: Rect2 = board_frame.get_global_rect()
		_assert_rect_inside(top_bg_rect, viewport_rect)
		_assert_rect_inside(cabinet_title_rect, viewport_rect)
		_assert_rect_inside(top_rect, viewport_rect)
		_assert_rect_inside(top_right_rect, viewport_rect)
		_assert_rect_inside(top_rect, top_bg_rect)
		assert_that(abs(top_rect.position.y - top_bg_rect.position.y)).is_less_equal(1.0)
		assert_that(abs(top_rect.size.y - top_bg_rect.size.y)).is_less_equal(1.0)
		assert_that(abs(_rect_center_x(top_bg_rect) - _rect_center_x(board_frame_rect))).is_less_equal(1.0)
		assert_that(top_bg_rect.size.x).is_greater_equal(board_frame_rect.size.x - 1.0)
		_assert_rect_inside(inner_highlight_rect, top_bg_rect)
		_assert_rect_inside(pressure_rect, viewport_rect)
		assert_that(pressure_rect.position.y).is_greater_equal(top_bg_rect.position.y + top_bg_rect.size.y - 1.0)
		assert_that(pressure_rect.position.y + pressure_rect.size.y).is_less_equal(board_rect.position.y + 1.0)
		assert_that(abs(_rect_center_y(inner_highlight_rect) - _rect_center_y(top_bg_rect))).is_less_equal(1.0)
		_assert_rect_inside(score_box_rect, top_bg_rect)
		_assert_rect_inside(combo_pod_rect, top_bg_rect)
		_assert_rect_inside(rival_pod_rect, top_bg_rect)
		_assert_rect_inside(score_caption_rect, top_bg_rect)
		_assert_rect_inside(score_value_rect, top_bg_rect)
		_assert_rect_inside(pause_rect, top_bg_rect)
		assert_that(abs(_rect_center_x(pause_icon_rect) - _rect_center_x(pause_rect))).is_less_equal(1.0)
		assert_that(abs(_rect_center_y(pause_icon_rect) - _rect_center_y(pause_rect))).is_less_equal(1.0)
		_assert_rect_inside(account_rect, top_right_rect)
		_assert_rect_inside(shop_rect, top_right_rect)
		_assert_rect_inside(audio_rect, top_right_rect)
		assert_that(account_rect.position.x + account_rect.size.x).is_less_equal(shop_rect.position.x + 1.0)
		assert_that(shop_rect.position.x + shop_rect.size.x).is_less_equal(audio_rect.position.x + 1.0)
		_assert_rect_inside(powerups_rect, viewport_rect)
		_assert_rect_inside(undo_rect, viewport_rect)
		assert_that(score_caption_rect.position.y + score_caption_rect.size.y).is_less_equal(score_value_rect.position.y + 1.0)
		var score_center_y: float = _rect_center_y(score_stack_rect)
		var expected_score_center_y: float = _rect_center_y(top_bg_rect)
		assert_that(abs(score_center_y - expected_score_center_y)).is_less_equal(3.0)
		var expected_pause_center_y: float = _rect_center_y(top_bg_rect)
		var pause_center_y: float = _rect_center_y(pause_rect)
		assert_that(abs(pause_center_y - expected_pause_center_y)).is_less_equal(2.0)
		assert_that(abs(_rect_center_x(pause_icon_rect) - _rect_center_x(pause_rect))).is_less_equal(1.0)
		assert_that(abs(_rect_center_y(pause_icon_rect) - _rect_center_y(pause_rect))).is_less_equal(1.0)
		assert_that(abs(_rect_center_y(top_right_rect) - _rect_center_y(top_bg_rect))).is_less_equal(2.0)
		if size.x / max(1.0, size.y) >= 1.45:
			assert_that(top_rect.size.x).is_greater_equal(viewport_rect.size.x * 0.45)
		assert_that(board_rect.position.x).is_greater_equal(0.0)
		assert_that(board_rect.position.x + board_rect.size.x).is_less_equal(viewport_rect.size.x + 1.0)
		assert_that(board_rect.position.y).is_greater_equal(top_rect.position.y + top_rect.size.y - 1.0)
		assert_that(board_rect.position.y + board_rect.size.y).is_less_equal(powerups_rect.position.y + 1.0)

	DisplayServer.window_set_size(original_window_size)
	game.queue_free()

func test_pressure_glow_and_combo_drain_ring_track_hud_state() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var pressure_glow: ColorRect = game.get_node_or_null("UI/PressureHud/Margin/Row/RivalMeter/PressureGlow") as ColorRect
	var combo_drain_ring: Control = game.get_node_or_null("UI/TopBar/ComboPod/ComboDrainRing") as Control
	assert_that(pressure_glow).is_not_null()
	assert_that(combo_drain_ring).is_not_null()
	var glow_material: ShaderMaterial = pressure_glow.material as ShaderMaterial
	assert_that(glow_material).is_not_null()
	var idle_intensity: float = float(glow_material.get_shader_parameter("intensity"))

	game.set("score", 999999)
	game.call("_update_pressure_hud")
	var full_intensity: float = float(glow_material.get_shader_parameter("intensity"))
	var full_color: Color = glow_material.get_shader_parameter("glow_color")
	assert_that(full_intensity).is_greater(idle_intensity)
	assert_that(full_intensity).is_greater(1.0)
	assert_that(full_color.r).is_greater(full_color.b)

	game.set("combo", 1)
	game.call("_arm_combo_timeout")
	game.call("_update_pressure_hud")
	assert_that(combo_drain_ring.visible).is_false()

	game.set("combo", 2)
	game.call("_arm_combo_timeout")
	game.call("_update_pressure_hud")
	assert_that(combo_drain_ring.visible).is_true()
	assert_that(float(combo_drain_ring.get("time_fraction"))).is_greater(0.99)

	game.set("_combo_timeout_remaining", 0.32)
	game.call("_update_combo_warning_fx")
	assert_that(float(combo_drain_ring.get("time_fraction"))).is_less(0.30)
	assert_that(float(combo_drain_ring.get("warning_amount"))).is_greater(0.0)

	game.call("_break_combo")
	assert_that(combo_drain_ring.visible).is_false()
	assert_that(game.get("combo")).is_equal(0)
	game.queue_free()

func test_powerup_juice_resets_board_scale_after_rapid_retrigger() -> void:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var board: BoardView = game.get_node_or_null("BoardView") as BoardView
	assert_that(board).is_not_null()
	var center_before: Vector2 = _board_visual_center(board)
	game.call("_play_powerup_juice", Color(1.0, 0.84, 0.18, 0.28))
	var scaled_during_cue := false
	for _i in range(12):
		await get_tree().process_frame
		if board.scale.x > 1.001:
			scaled_during_cue = true
			var center_during_cue: Vector2 = _board_visual_center(board)
			assert_that(absf(center_during_cue.x - center_before.x)).is_less_equal(0.5)
			assert_that(absf(center_during_cue.y - center_before.y)).is_less_equal(0.5)
			break
	assert_that(scaled_during_cue).is_true()
	await get_tree().process_frame
	game.call("_play_powerup_juice", Color(0.0, 0.96, 1.0, 0.28))
	await get_tree().process_frame
	game.call("_play_powerup_juice", Color(0.30, 0.20, 1.0, 0.28))
	for _i in range(40):
		await get_tree().process_frame

	assert_that(absf(board.scale.x - 1.0)).is_less_equal(0.001)
	assert_that(absf(board.scale.y - 1.0)).is_less_equal(0.001)
	game.queue_free()

func test_gameplay_top_right_opens_account_and_shop_modals() -> void:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var account_button: Button = game.get_node_or_null("UI/TopRightBar/Account") as Button
	var shop_button: Button = game.get_node_or_null("UI/TopRightBar/Shop") as Button
	assert_that(account_button).is_not_null()
	assert_that(shop_button).is_not_null()
	assert_that(account_button.tooltip_text).is_equal("Account")
	assert_that(shop_button.tooltip_text).is_equal("Shop")

	account_button.pressed.emit()
	await get_tree().process_frame
	var account_modal: Control = game.get_node_or_null("AccountModal") as Control
	assert_that(account_modal).is_not_null()
	account_modal.queue_free()
	await get_tree().process_frame

	shop_button.pressed.emit()
	await get_tree().process_frame
	var shop_modal: Control = game.get_node_or_null("ShopModal") as Control
	assert_that(shop_modal).is_not_null()
	game.queue_free()

func _assert_rect_inside(inner: Rect2, outer: Rect2, epsilon: float = 1.0) -> void:
	assert_that(inner.position.x).is_greater_equal(outer.position.x - epsilon)
	assert_that(inner.position.y).is_greater_equal(outer.position.y - epsilon)
	assert_that(inner.position.x + inner.size.x).is_less_equal(outer.position.x + outer.size.x + epsilon)
	assert_that(inner.position.y + inner.size.y).is_less_equal(outer.position.y + outer.size.y + epsilon)

func _rect_center_y(rect: Rect2) -> float:
	return rect.position.y + (rect.size.y * 0.5)

func _rect_center_x(rect: Rect2) -> float:
	return rect.position.x + (rect.size.x * 0.5)

func _board_visual_center(board: BoardView) -> Vector2:
	var board_size := Vector2(float(board.width) * board.tile_size, float(board.height) * board.tile_size)
	return board.global_position + Vector2(board_size.x * board.scale.x, board_size.y * board.scale.y) * 0.5
