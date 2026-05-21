extends RefCounted
class_name ArcadeTutorialTemplate

const DEFAULT_TEMPLATE := {
	"panel_margin": Vector2(22.0, 18.0),
	"panel_min_width": 360.0,
	"panel_max_width": 680.0,
	"panel_min_height": 190.0,
	"panel_screen_margin": 18.0,
	"panel_top_gap": 14.0,
	"panel_bottom_gap": 18.0,
	"title_font_size": 24.0,
	"message_font_size": 20.0,
	"button_font_size": 15.0,
	"secondary_button_font_size": 14.0,
	"button_height": 56.0,
	"primary_button_width": 136.0,
	"secondary_button_width": 166.0,
	"highlight_growth": 10.0,
}

static func merged_template(overrides: Dictionary = {}) -> Dictionary:
	var template := DEFAULT_TEMPLATE.duplicate(true)
	for key in overrides.keys():
		template[key] = overrides[key]
	return template

static func style_panel(panel: Panel, template: Dictionary = {}) -> void:
	if panel == null:
		return
	template = merged_template(template)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.14, 0.94)
	style.border_color = Color(0.68, 0.95, 1.0, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)

static func style_label(label: Label, is_title: bool, template: Dictionary = {}) -> void:
	if label == null:
		return
	template = merged_template(template)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_title:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", _font_px(float(template["title_font_size"] if is_title else template["message_font_size"])))
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.76, 1.0) if is_title else Color(0.93, 0.97, 1.0, 0.98))

static func style_button(button: Button, primary: bool, template: Dictionary = {}) -> void:
	if button == null:
		return
	template = merged_template(template)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.custom_minimum_size = Vector2(
		float(template["primary_button_width"] if primary else template["secondary_button_width"]),
		float(template["button_height"])
	)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END if primary else Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", _font_px(float(template["button_font_size"] if primary else template["secondary_button_font_size"])))
	button.add_theme_color_override("font_color", Color(0.06, 0.08, 0.12, 1.0) if primary else Color(0.88, 0.96, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.03, 0.05, 0.08, 1.0) if primary else Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.03, 0.05, 1.0) if primary else Color(0.95, 0.98, 1.0, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.82, 0.22, 0.96) if primary else Color(0.08, 0.13, 0.22, 0.82)
	normal.border_color = Color(1.0, 0.94, 0.54, 0.95) if primary else Color(0.45, 0.83, 1.0, 0.55)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.9, 0.34, 1.0) if primary else Color(0.11, 0.18, 0.3, 0.92)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.95, 0.68, 0.16, 1.0) if primary else Color(0.05, 0.1, 0.18, 0.92)
	button.add_theme_stylebox_override("pressed", pressed)

static func apply_margins(margin: MarginContainer, template: Dictionary = {}) -> void:
	if margin == null:
		return
	template = merged_template(template)
	var panel_margin: Vector2 = template["panel_margin"]
	margin.add_theme_constant_override("margin_left", int(round(panel_margin.x)))
	margin.add_theme_constant_override("margin_top", int(round(panel_margin.y)))
	margin.add_theme_constant_override("margin_right", int(round(panel_margin.x)))
	margin.add_theme_constant_override("margin_bottom", int(round(panel_margin.y)))

static func calculate_text_height(message: String, panel_width: float, base_height: float, view_size: Vector2, top_limit: float, template: Dictionary = {}) -> float:
	template = merged_template(template)
	var panel_margin: Vector2 = template["panel_margin"]
	var inner_width: float = max(180.0, panel_width - (panel_margin.x * 2.0))
	var message_size: float = float(_font_px(float(template["message_font_size"])))
	var chars_per_line: int = max(20, int(floor(inner_width / max(8.0, message_size * 0.52))))
	var line_count: int = max(1, int(ceil(float(message.length()) / float(chars_per_line))))
	var title_height: float = float(_font_px(float(template["title_font_size"]) + 6.0))
	var message_height: float = float(line_count) * float(_font_px(float(template["message_font_size"]) + 6.0))
	var required_height: float = (panel_margin.y * 2.0) + title_height + 24.0 + message_height + float(template["button_height"])
	var max_height: float = max(float(template["panel_min_height"]), view_size.y - top_limit - (float(template["panel_screen_margin"]) * 2.0))
	return clamp(max(base_height, required_height), float(template["panel_min_height"]), max_height)

static func layout_panel(context: Dictionary, template: Dictionary = {}) -> Dictionary:
	template = merged_template(template)
	var view_size: Vector2 = context.get("view_size", Vector2(1080, 1920))
	var board_rect: Rect2 = context.get("board_rect", Rect2())
	var top_limit: float = float(context.get("top_limit", float(template["panel_screen_margin"])))
	var bottom_limit: float = float(context.get("bottom_limit", view_size.y - float(template["panel_screen_margin"])))
	var early_step: bool = bool(context.get("early_step", false))
	var powerup_step: bool = bool(context.get("powerup_step", false))
	var message: String = str(context.get("message", ""))
	var margin: float = float(template["panel_screen_margin"])
	var panel_width: float = clamp(
		view_size.x * (0.68 if early_step else 0.62),
		float(template["panel_min_width"]) + (20.0 if early_step else 0.0),
		float(template["panel_max_width"])
	)
	var panel_height: float = clamp(view_size.y * (0.25 if early_step else 0.22), 208.0 if early_step else 184.0, 292.0 if early_step else 260.0)
	var panel_x: float = (view_size.x - panel_width) * 0.5
	var panel_y: float = view_size.y - panel_height - clamp(view_size.y * 0.16, 120.0, 170.0)
	if early_step and board_rect.size != Vector2.ZERO:
		panel_height = calculate_text_height(message, panel_width, panel_height, view_size, top_limit, template)
		panel_y = board_rect.position.y - panel_height - clamp(view_size.y * 0.025, 18.0, 34.0)
		if panel_y < top_limit:
			panel_y = min(view_size.y - panel_height - 24.0, board_rect.position.y + board_rect.size.y + 18.0)
	elif powerup_step and board_rect.size != Vector2.ZERO:
		var side_gap: float = clamp(view_size.x * 0.035, 32.0, 72.0)
		var right_space: float = view_size.x - board_rect.end.x - side_gap - margin
		var left_space: float = board_rect.position.x - side_gap - margin
		var can_place_right: bool = right_space >= 300.0
		var can_place_left: bool = left_space >= 300.0
		if can_place_right or can_place_left:
			panel_width = min(560.0, max(300.0, right_space if can_place_right else left_space))
			panel_x = board_rect.end.x + side_gap if can_place_right else board_rect.position.x - side_gap - panel_width
		else:
			panel_width = clamp(view_size.x * 0.76, float(template["panel_min_width"]), float(template["panel_max_width"]))
			panel_x = (view_size.x - panel_width) * 0.5
		panel_height = calculate_text_height(message, panel_width, clamp(view_size.y * 0.26, 240.0, 330.0), view_size, top_limit, template)
		panel_y = clamp(bottom_limit - panel_height, top_limit, max(top_limit, view_size.y - panel_height - margin))
	else:
		panel_height = calculate_text_height(message, panel_width, panel_height, view_size, top_limit, template)
	panel_x = clamp(panel_x, margin, max(margin, view_size.x - panel_width - margin))
	panel_y = clamp(panel_y, top_limit, max(top_limit, view_size.y - panel_height - margin))
	return {
		"position": Vector2(panel_x, panel_y),
		"size": Vector2(panel_width, panel_height),
	}

static func style_highlight(highlight: Panel) -> void:
	if highlight == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.58, 0.05, 0.10)
	style.border_color = Color(1.0, 0.76, 0.18, 0.95)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	highlight.add_theme_stylebox_override("panel", style)

static func _font_px(value: float) -> int:
	var main_loop := Engine.get_main_loop()
	var typography: Node = null
	if main_loop is SceneTree:
		typography = (main_loop as SceneTree).root.get_node_or_null("/root/Typography")
	if typography and typography.has_method("px"):
		return int(typography.call("px", value))
	return int(round(value))
