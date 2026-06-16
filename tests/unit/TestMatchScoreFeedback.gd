extends GdUnitTestSuite

func before() -> void:
	ProjectSettings.set_setting("lumarush/visual_test_mode", true)
	ProjectSettings.set_setting("lumarush/audio_test_mode", true)
	SaveStore.set_tutorial_seen(true)

func test_normal_match_shows_single_score_popup() -> void:
	var game: Control = await _load_game()

	var ui: Control = game.get_node("UI") as Control
	var group: Array = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	game.call("_on_match_feedback", group, Vector2(320.0, 360.0), 0)
	assert_that(game.get("combo")).is_equal(1)
	assert_that(game.get("score")).is_equal(30)
	game.call("_on_match_made", group)
	await get_tree().process_frame
	assert_that(game.get("combo")).is_equal(1)
	assert_that(game.get("score")).is_equal(30)

	var score_burst: Label = ui.get_node_or_null("ScoreBurst") as Label
	assert_that(score_burst).is_not_null()
	assert_that(score_burst.visible).is_false()
	assert_that(_count_match_score_bursts(ui)).is_equal(1)
	var burst: Control = _first_match_score_burst(ui)
	assert_that(burst).is_not_null()
	assert_that(burst.get_node_or_null("ShockRing")).is_not_null()
	assert_that(burst.get_node_or_null("Badge")).is_not_null()
	assert_that(burst.find_child("Score", true, false)).is_not_null()
	game.queue_free()

func test_chain_match_score_uses_burst_badge_ribbon() -> void:
	var game: Control = await _load_game()
	var ui: Control = game.get_node("UI") as Control
	var group: Array = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	game.set("combo", 2)
	game.call("_on_match_feedback", group, Vector2(320.0, 360.0), 0)
	await get_tree().process_frame
	assert_that(game.get("combo")).is_equal(3)
	assert_that(game.get("score")).is_equal(90)

	assert_that(_count_match_score_bursts(ui)).is_equal(1)
	var burst: Control = _first_match_score_burst(ui)
	var score_label: Label = burst.find_child("Score", true, false) as Label
	var ribbon: Label = burst.find_child("Ribbon", true, false) as Label
	assert_that(score_label).is_not_null()
	assert_that(ribbon).is_not_null()
	assert_that(score_label.text).is_equal("+90")
	assert_that(ribbon.text).is_equal("CHAIN x3")
	game.queue_free()

func test_big_clear_match_score_uses_burst_badge_ribbon() -> void:
	var game: Control = await _load_game()
	var ui: Control = game.get_node("UI") as Control
	var group: Array = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	game.call("_on_match_feedback", group, Vector2(320.0, 360.0), 0)
	await get_tree().process_frame
	assert_that(game.get("combo")).is_equal(1)
	assert_that(game.get("score")).is_equal(50)

	assert_that(_count_match_score_bursts(ui)).is_equal(1)
	var burst: Control = _first_match_score_burst(ui)
	var score_label: Label = burst.find_child("Score", true, false) as Label
	var ribbon: Label = burst.find_child("Ribbon", true, false) as Label
	assert_that(score_label).is_not_null()
	assert_that(ribbon).is_not_null()
	assert_that(score_label.text).is_equal("+50")
	assert_that(ribbon.text).is_equal("BIG CLEAR")
	game.queue_free()

func _load_game() -> Control:
	var scene: PackedScene = load("res://src/scenes/Game.tscn") as PackedScene
	var game: Control = scene.instantiate() as Control
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game

func _count_match_score_bursts(root: Node) -> int:
	var count: int = 0
	for child in root.get_children():
		if child.name == "MatchScoreBurst":
			count += 1
	return count

func _first_match_score_burst(root: Node) -> Control:
	for child in root.get_children():
		if child.name == "MatchScoreBurst":
			return child as Control
	return null
