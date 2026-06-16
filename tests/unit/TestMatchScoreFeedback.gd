extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	SaveStore.set_tutorial_seen(true)

func test_normal_match_shows_single_score_popup() -> void:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui: Control = game.get_node("UI") as Control
	var group: Array = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	game.call("_on_match_feedback", group, Vector2(320.0, 360.0), 0)
	game.call("_on_match_made", group)
	await get_tree().process_frame

	var score_burst: Label = ui.get_node_or_null("ScoreBurst") as Label
	assert_that(score_burst).is_not_null()
	assert_that(score_burst.visible).is_false()
	assert_that(_count_match_score_bursts(ui)).is_equal(1)
	game.queue_free()

func _count_match_score_bursts(root: Node) -> int:
	var count: int = 0
	for child in root.get_children():
		if child.name == "MatchScoreBurst":
			count += 1
	return count
