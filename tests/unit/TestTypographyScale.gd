extends GdUnitTestSuite

func test_desktop_canvas_gets_readable_text_scale() -> void:
	var phone_scale: float = Typography.scale_factor_for_size(Vector2(1080.0, 1920.0))
	var desktop_scale: float = Typography.scale_factor_for_size(Vector2(3413.0, 1920.0))

	assert_that(phone_scale).is_greater_equal(1.15)
	assert_that(desktop_scale).is_greater_equal(1.55)
	assert_that(desktop_scale).is_greater(phone_scale)
	assert_that(desktop_scale).is_less_equal(1.65)

func test_tiny_viewports_keep_a_readable_floor() -> void:
	var tiny_scale: float = Typography.scale_factor_for_size(Vector2(720.0, 1280.0))

	assert_that(tiny_scale).is_greater_equal(0.78)
	assert_that(Typography.px(14.0)).is_greater_equal(11)

func test_font_roles_use_interface_and_body_faces() -> void:
	var title := Label.new()
	var body := Label.new()

	Typography.style_label(title, 32.0, Typography.WEIGHT_BOLD)
	Typography.style_body_label(body, 24.0, Typography.WEIGHT_REGULAR)

	assert_that(title.get_theme_font("font")).is_equal(Typography.interface_font(Typography.WEIGHT_BOLD))
	assert_that(body.get_theme_font("font")).is_equal(Typography.body_font(Typography.WEIGHT_REGULAR))

	title.free()
	body.free()
