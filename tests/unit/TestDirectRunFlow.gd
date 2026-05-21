extends GdUnitTestSuite

func test_boot_routes_to_game_without_splash_delay() -> void:
	var source := FileAccess.get_file_as_string("res://src/scenes/Boot.gd")
	assert_that(source).contains('call_deferred("_go_game")')
	assert_that(source).contains("RunManager.start_game()")
	assert_that(source).not_contains("RunManager.goto_menu()")
	assert_that(source).not_contains("LOGO_STING_SECONDS")
	assert_that(source).not_contains("_play_logo_sting")
	assert_that(source).not_contains("TeraPixel")
	assert_that(source).not_contains("create_timer")

func test_legacy_menu_route_starts_game() -> void:
	var source := FileAccess.get_file_as_string("res://src/core/RunManager.gd")
	assert_that(source).contains("func goto_menu() -> void:\n\tstart_game()")

func test_results_has_single_visible_run_loop_action() -> void:
	var scene: PackedScene = load("res://src/scenes/Results.tscn") as PackedScene
	var results: Control = scene.instantiate() as Control
	assert_that(results).is_not_null()
	get_tree().root.add_child(results)
	await get_tree().process_frame
	await get_tree().process_frame

	var play_again: Button = results.get_node("UI/Panel/Scroll/VBox/PlayAgain") as Button
	var menu: Button = results.get_node("UI/Panel/Scroll/VBox/Menu") as Button
	var double_reward: Button = results.get_node("UI/Panel/Scroll/VBox/DoubleReward") as Button
	var online_status: Label = results.get_node("UI/Panel/Scroll/VBox/StatsSplit/RightColumn/OnlineStatus") as Label
	assert_that(play_again).is_not_null()
	assert_that(menu).is_not_null()
	assert_that(double_reward).is_not_null()
	assert_that(online_status).is_not_null()
	assert_that(play_again.visible).is_true()
	assert_that(play_again.text).is_equal("NEXT RUN")
	assert_that(menu.visible).is_false()
	assert_that(menu.disabled).is_true()
	assert_that(double_reward.visible).is_false()
	assert_that(online_status.visible).is_false()

	results.queue_free()
