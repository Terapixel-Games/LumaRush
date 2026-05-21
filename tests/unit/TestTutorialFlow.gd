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
	assert_that(message.text).contains("advances when you make the move")

	var next_button: Button = overlay.get_node_or_null("Panel/Margin/VBox/Buttons/Next") as Button
	var skip_button: Button = overlay.get_node_or_null("Panel/Margin/VBox/Buttons/Skip") as Button
	assert_that(next_button).is_not_null()
	assert_that(skip_button).is_not_null()
	assert_that(skip_button.text).is_equal("Skip Tutorial")
	assert_that(skip_button.custom_minimum_size.x).is_greater_equal(160.0)
	assert_that(next_button.custom_minimum_size.x).is_less(150.0)
	assert_that(next_button.size_flags_horizontal & Control.SIZE_EXPAND).is_equal(0)

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Keep The Beat")
	assert_that(message.text).contains("music grows")

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Undo")
	assert_that(message.text).contains("rewinds your last move")
	assert_that(message.text).contains("Tap anywhere")
	assert_that(next_button.text).is_equal("Tap Anywhere")

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Prism")
	assert_that(message.text).contains("star button")
	assert_that(message.text).contains("rewarded ad")

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Hint")
	assert_that(message.text).contains("question mark")
	assert_that(message.text).contains("points out")

	next_button.pressed.emit()
	assert_that(title.text).is_equal("That's It")
	assert_that(message.text).contains("Tap anywhere to play")
	assert_that(next_button.text).is_equal("Done")

	next_button.pressed.emit()
	await get_tree().process_frame
	assert_that(SaveStore.is_tutorial_seen()).is_true()
	assert_that(game.get_node_or_null("UI/TutorialOverlay")).is_null()
	game.queue_free()

func test_powerup_tutorial_highlights_one_button_at_a_time() -> void:
	SaveStore.set_tutorial_seen(false)
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: Control = game.get_node_or_null("UI/TutorialOverlay") as Control
	var title: Label = overlay.get_node_or_null("Panel/Margin/VBox/Title") as Label
	var next_button: Button = overlay.get_node_or_null("Panel/Margin/VBox/Buttons/Next") as Button
	next_button.pressed.emit()
	next_button.pressed.emit()
	assert_that(title.text).is_equal("Undo")
	assert_that(_highlight_count(overlay)).is_equal(1)

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Prism")
	assert_that(_highlight_count(overlay)).is_equal(1)

	next_button.pressed.emit()
	assert_that(title.text).is_equal("Hint")
	assert_that(_highlight_count(overlay)).is_equal(1)
	game.queue_free()

func test_powerup_tutorial_can_advance_from_anywhere_click() -> void:
	SaveStore.set_tutorial_seen(false)
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: Control = game.get_node_or_null("UI/TutorialOverlay") as Control
	var title: Label = overlay.get_node_or_null("Panel/Margin/VBox/Title") as Label
	game.call("_advance_tutorial_step")
	game.call("_advance_tutorial_step")
	assert_that(title.text).is_equal("Undo")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	overlay.emit_signal("gui_input", click)
	assert_that(title.text).is_equal("Prism")
	game.queue_free()

func test_playing_a_match_advances_the_early_tutorial_steps() -> void:
	SaveStore.set_tutorial_seen(false)
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	assert_that(game).is_not_null()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var overlay: Control = game.get_node_or_null("UI/TutorialOverlay") as Control
	var title: Label = overlay.get_node_or_null("Panel/Margin/VBox/Title") as Label
	assert_that(title.text).is_equal("Tap A Group")
	game.call("_on_match_made", [Vector2i.ZERO, Vector2i.RIGHT])
	await get_tree().process_frame
	assert_that(title.text).is_equal("Keep The Beat")

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

func _highlight_count(overlay: Control) -> int:
	var count := 0
	for child in overlay.get_children():
		if child is Panel and child.name == "Highlight":
			count += 1
	return count
