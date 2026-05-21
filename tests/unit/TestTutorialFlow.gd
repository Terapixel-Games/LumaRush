extends GdUnitTestSuite

var _original_tutorial_seen: bool = false

func before_test() -> void:
	_original_tutorial_seen = SaveStore.is_tutorial_seen()

func after_test() -> void:
	SaveStore.set_tutorial_seen(_original_tutorial_seen)

func test_first_run_tutorial_teaches_board_music_and_powerups() -> void:
	SaveStore.set_tutorial_seen(false)
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: Control = game.get_node_or_null("UI/TutorialOverlay") as Control
	assert_that(overlay).is_not_null()
	var title: Label = overlay.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var message: Label = overlay.get_node_or_null("Panel/Margin/VBox/Message") as Label
	assert_that(title).is_not_null()
	assert_that(message).is_not_null()
	assert_that(title.text).is_equal("Tap A Group")
	assert_that(message.text).contains("highlighted tiles")

	game.call("_on_tutorial_next_pressed")
	assert_that(title.text).is_equal("Keep The Beat")
	assert_that(message.text).contains("music grows")

	game.call("_on_tutorial_next_pressed")
	assert_that(title.text).is_equal("Powerups")
	assert_that(message.text).contains("starter charges")

	game.call("_on_tutorial_next_pressed")
	assert_that(title.text).is_equal("Refills")
	assert_that(message.text).contains("rewarded ad")

	game.call("_on_tutorial_next_pressed")
	await get_tree().process_frame
	assert_that(SaveStore.is_tutorial_seen()).is_true()
	assert_that(game.get_node_or_null("UI/TutorialOverlay")).is_null()
	game.queue_free()

func test_pause_overlay_can_request_tutorial_reenable() -> void:
	var scene: PackedScene = load("res://src/scenes/PauseOverlay.tscn") as PackedScene
	var pause_overlay: Control = scene.instantiate() as Control
	assert_that(pause_overlay).is_not_null()
	get_tree().root.add_child(pause_overlay)
	await get_tree().process_frame

	var tutorial_button: Button = pause_overlay.get_node_or_null("VBox/Tutorial") as Button
	assert_that(tutorial_button).is_not_null()
	assert_that(tutorial_button.text).is_equal("Enable Tutorial")
	pause_overlay.queue_free()
