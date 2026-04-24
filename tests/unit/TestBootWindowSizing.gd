extends GdUnitTestSuite

const WINDOW_SIZING := preload("res://src/core/WindowSizing.gd")

func test_compute_window_size_for_display_matches_usable_height_when_width_allows() -> void:
	var target_size: Vector2i = WINDOW_SIZING.compute_window_size_for_display(
		Vector2i(1080, 1920),
		Rect2i(0, 0, 2560, 1440)
	)
	assert_that(target_size).is_equal(Vector2i(810, 1440))

func test_compute_window_size_for_display_falls_back_to_width_when_height_fit_would_overflow() -> void:
	var target_size: Vector2i = WINDOW_SIZING.compute_window_size_for_display(
		Vector2i(1080, 1920),
		Rect2i(0, 0, 400, 900)
	)
	assert_that(target_size).is_equal(Vector2i(400, 711))

func test_compute_window_position_centers_inside_usable_rect() -> void:
	var target_position: Vector2i = WINDOW_SIZING.compute_window_position(
		Rect2i(100, 50, 2560, 1440),
		Vector2i(810, 1440)
	)
	assert_that(target_position).is_equal(Vector2i(975, 50))
