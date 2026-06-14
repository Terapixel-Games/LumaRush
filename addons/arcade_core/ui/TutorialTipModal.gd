extends Control

signal dismissed(do_not_show_again: bool)

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var message_label: Label = $Center/Panel/VBox/Message
@onready var confirm_button: Button = $Center/Panel/VBox/Confirm
@onready var do_not_show_toggle: CheckButton = $Center/Panel/VBox/DoNotShow
@onready var center_layer: Control = $Center
@onready var panel: Panel = $Center/Panel
@onready var content_box: Control = $Center/Panel/VBox
@onready var dim: ColorRect = $Dim

var _pending_config: Dictionary = {}
var _bottom_offset: float = 112.0
var _target_rect: Rect2 = Rect2()
var _avoid_rect: Rect2 = Rect2()
var _icon_texture: Texture2D
var _icon_cluster: Control
var _target_highlight: Panel
var _pointer_outer: Polygon2D
var _pointer_inner: Polygon2D
var _panel_tween: Tween
var _panel_breath_tween: Tween
var _button_tween: Tween
var _target_tween: Tween
var _dust_tweens: Array[Tween] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_build_effect_nodes()
	if not _pending_config.is_empty():
		_apply_config(_pending_config)
	_apply_optional_style()
	_style_controls()
	_layout_tip()
	_play_entry_motion()
	_play_idle_motion()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_apply_optional_style()
		_style_controls()
		_layout_tip()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_emit_and_close()
		get_viewport().set_input_as_handled()

func configure(config: Dictionary) -> void:
	_pending_config = config.duplicate(true)
	_apply_config(_pending_config)

func _apply_config(config: Dictionary) -> void:
	_bottom_offset = float(config.get("bottom_offset", _bottom_offset))
	_target_rect = config.get("target_rect", Rect2()) as Rect2
	_avoid_rect = config.get("avoid_rect", Rect2()) as Rect2
	_icon_texture = config.get("icon_texture", null) as Texture2D
	if title_label:
		title_label.text = str(config.get("title", "Tip"))
	if message_label:
		message_label.text = str(config.get("message", ""))
	if confirm_button:
		confirm_button.text = str(config.get("confirm_text", "Got it"))
	if do_not_show_toggle:
		do_not_show_toggle.text = str(config.get("checkbox_text", "Don't show this again"))
		do_not_show_toggle.visible = bool(config.get("show_checkbox", true))
		do_not_show_toggle.button_pressed = false
	_apply_icon_texture()
	_layout_tip()

func _on_confirm_pressed() -> void:
	_emit_and_close()

func _on_dim_gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if click or touch:
		_emit_and_close()

func _emit_and_close() -> void:
	_stop_motion()
	var do_not_show_again := false
	if do_not_show_toggle and do_not_show_toggle.visible:
		do_not_show_again = do_not_show_toggle.button_pressed
	dismissed.emit(do_not_show_again)
	queue_free()

func _apply_optional_style() -> void:
	var typography := get_node_or_null("/root/Typography")
	if typography and typography.has_method("style_tutorial_tip"):
		typography.call("style_tutorial_tip", self)

func _style_controls() -> void:
	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36, 1.0))
		title_label.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.0, 0.95))
		title_label.add_theme_constant_override("outline_size", 4)
	if message_label:
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		message_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
		message_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.10, 0.94))
		message_label.add_theme_constant_override("outline_size", 3)
	if do_not_show_toggle:
		do_not_show_toggle.focus_mode = Control.FOCUS_NONE
		do_not_show_toggle.add_theme_color_override("font_color", Color(1.0, 1.0, 0.96, 1.0))
		do_not_show_toggle.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		do_not_show_toggle.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.46, 1.0))
		do_not_show_toggle.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.96))
		do_not_show_toggle.add_theme_constant_override("outline_size", 3)
	if confirm_button:
		confirm_button.focus_mode = Control.FOCUS_NONE
		confirm_button.clip_text = false
		confirm_button.add_theme_color_override("font_color", Color(0.03, 0.025, 0.01, 1.0))
		confirm_button.add_theme_color_override("font_hover_color", Color(0.02, 0.018, 0.006, 1.0))
		confirm_button.add_theme_color_override("font_pressed_color", Color(0.02, 0.018, 0.006, 1.0))
		confirm_button.add_theme_color_override("font_outline_color", Color(1.0, 0.92, 0.46, 0.55))
		confirm_button.add_theme_constant_override("outline_size", 1)
		confirm_button.add_theme_stylebox_override("normal", _button_style(Color(1.0, 0.78, 0.22, 1.0), Color(1.0, 0.91, 0.44, 1.0)))
		confirm_button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.86, 0.30, 1.0), Color(1.0, 0.98, 0.60, 1.0)))
		confirm_button.add_theme_stylebox_override("pressed", _button_style(Color(0.86, 0.55, 0.10, 1.0), Color(1.0, 0.78, 0.20, 1.0)))

func _build_effect_nodes() -> void:
	if panel == null or center_layer == null:
		return
	_style_panel()
	_pointer_outer = Polygon2D.new()
	_pointer_outer.name = "PointerOuter"
	_pointer_outer.color = Color(0.0, 1.0, 0.86, 0.96)
	center_layer.add_child(_pointer_outer)
	_pointer_inner = Polygon2D.new()
	_pointer_inner.name = "PointerInner"
	_pointer_inner.color = Color(0.02, 0.08, 0.16, 0.98)
	center_layer.add_child(_pointer_inner)
	_icon_cluster = Control.new()
	_icon_cluster.name = "IconCluster"
	_icon_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_layer.add_child(_icon_cluster)
	var glow := Panel.new()
	glow.name = "Glow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_circle_panel(glow, Color(1.0, 0.72, 0.14, 0.30), Color(1.0, 0.93, 0.44, 0.92), 72, 4)
	_icon_cluster.add_child(glow)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_cluster.add_child(icon)
	for i in range(8):
		var dust := ColorRect.new()
		dust.name = "Dust%d" % i
		dust.color = Color(1.0, 0.88, 0.38, 0.0)
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_cluster.add_child(dust)
	_target_highlight = Panel.new()
	_target_highlight.name = "TargetHighlight"
	_target_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_circle_panel(_target_highlight, Color(1.0, 0.58, 0.05, 0.14), Color(1.0, 0.84, 0.26, 0.96), 18, 5)
	center_layer.add_child(_target_highlight)

func _layout_tip() -> void:
	if panel == null or content_box == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = size
	var margin: float = clamp(view_size.x * 0.018, 18.0, 34.0)
	var panel_width: float = clamp(view_size.x * 0.72, 1040.0, 1200.0)
	if view_size.x < 720.0:
		panel_width = max(320.0, view_size.x - (margin * 2.0))
	var panel_height: float = clamp(view_size.y * 0.27, 252.0, 300.0)
	if view_size.x < 720.0:
		panel_height = clamp(view_size.y * 0.36, 292.0, 380.0)
	var panel_x: float = (view_size.x - panel_width) * 0.5
	var notch_gap: float = clamp(view_size.y * 0.048, 42.0, 58.0)
	var panel_y: float = _target_rect.position.y - panel_height - notch_gap if _target_rect.size.y > 0.0 else view_size.y - _bottom_offset - panel_height
	if panel_y < margin:
		panel_y = view_size.y - _bottom_offset - panel_height
	panel_y = clamp(panel_y, margin, max(margin, view_size.y - panel_height - margin))
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_width, panel_height)
	panel.pivot_offset = panel.size * 0.5
	if view_size.x >= 720.0:
		content_box.position = Vector2.ZERO
		content_box.size = panel.size
		content_box.offset_left = 0.0
		content_box.offset_top = 0.0
		content_box.offset_right = 0.0
		content_box.offset_bottom = 0.0
		_icon_cluster.position = panel.position + Vector2(44.0, 50.0)
		_icon_cluster.size = Vector2(124.0, 124.0)
		_layout_desktop_content(panel.size)
	else:
		content_box.position = Vector2.ZERO
		content_box.size = panel.size
		_icon_cluster.position = panel.position + Vector2((panel_width - 76.0) * 0.5, 18.0)
		_icon_cluster.size = Vector2(76.0, 76.0)
		_layout_mobile_content(panel.size)
	_layout_icon_children()
	_layout_pointer(panel.position, panel.size)
	_layout_target_effects(panel.position, panel.size)

func _layout_desktop_content(panel_size: Vector2) -> void:
	var text_x := 248.0
	var right_lane_width := 320.0
	var side_margin := 42.0
	var bottom_margin := 22.0
	if title_label:
		title_label.position = Vector2(text_x, 30.0)
		title_label.size = Vector2(panel_size.x - text_x - side_margin, 58.0)
	if message_label:
		message_label.position = Vector2(text_x, 94.0)
		message_label.size = Vector2(panel_size.x - text_x - right_lane_width - 20.0, 94.0)
	if do_not_show_toggle:
		do_not_show_toggle.position = Vector2(side_margin, panel_size.y - bottom_margin - 44.0)
		do_not_show_toggle.size = Vector2(370.0, 44.0)
	if confirm_button:
		confirm_button.position = Vector2(panel_size.x - side_margin - 308.0, panel_size.y - bottom_margin - 58.0)
		confirm_button.size = Vector2(308.0, 58.0)
		confirm_button.pivot_offset = confirm_button.size * 0.5

func _layout_mobile_content(panel_size: Vector2) -> void:
	if title_label:
		title_label.position = Vector2(24.0, 104.0)
		title_label.size = Vector2(panel_size.x - 48.0, 42.0)
	if message_label:
		message_label.position = Vector2(24.0, 150.0)
		message_label.size = Vector2(panel_size.x - 48.0, 86.0)
	if do_not_show_toggle:
		do_not_show_toggle.position = Vector2(24.0, panel_size.y - 116.0)
		do_not_show_toggle.size = Vector2(panel_size.x - 48.0, 44.0)
	if confirm_button:
		confirm_button.position = Vector2(24.0, panel_size.y - 66.0)
		confirm_button.size = Vector2(panel_size.x - 48.0, 52.0)
		confirm_button.pivot_offset = confirm_button.size * 0.5

func _layout_pointer(panel_position: Vector2, panel_size: Vector2) -> void:
	if _pointer_outer == null or _pointer_inner == null:
		return
	var has_target := _target_rect.size.x > 0.0 and _target_rect.size.y > 0.0
	_pointer_outer.visible = has_target
	_pointer_inner.visible = has_target
	if not has_target:
		return
	var tip_x: float = clamp(_target_rect.get_center().x, panel_position.x + 80.0, panel_position.x + panel_size.x - 80.0)
	var top_y: float = panel_position.y + panel_size.y - 1.0
	_pointer_outer.polygon = PackedVector2Array([
		Vector2(tip_x - 24.0, top_y),
		Vector2(tip_x + 24.0, top_y),
		Vector2(tip_x, top_y + 34.0),
	])
	_pointer_inner.polygon = PackedVector2Array([
		Vector2(tip_x - 18.0, top_y + 2.0),
		Vector2(tip_x + 18.0, top_y + 2.0),
		Vector2(tip_x, top_y + 25.0),
	])

func _layout_icon_children() -> void:
	if _icon_cluster == null:
		return
	var icon := _icon_cluster.get_node_or_null("Icon") as TextureRect
	if icon:
		icon.position = _icon_cluster.size * 0.18
		icon.size = _icon_cluster.size * 0.64
	for i in range(8):
		var dust := _icon_cluster.get_node_or_null("Dust%d" % i) as ColorRect
		if dust:
			dust.size = Vector2(4.0 + float(i % 3), 4.0 + float(i % 3))
			dust.position = Vector2(
				_icon_cluster.size.x * (0.18 + (float((i * 23) % 58) / 100.0)),
				_icon_cluster.size.y * (0.20 + (float((i * 17) % 55) / 100.0))
			)

func _layout_target_effects(panel_position: Vector2, panel_size: Vector2) -> void:
	if _target_highlight == null:
		return
	var has_target := _target_rect.size.x > 0.0 and _target_rect.size.y > 0.0
	_target_highlight.visible = has_target
	if not has_target:
		return
	var grow_amount: float = clamp(min(_target_rect.size.x, _target_rect.size.y) * 0.12, 6.0, 12.0)
	var grown := _target_rect.grow(grow_amount)
	_target_highlight.global_position = grown.position
	_target_highlight.size = grown.size
	_target_highlight.pivot_offset = grown.size * 0.5

func _apply_icon_texture() -> void:
	var icon := _icon_cluster.get_node_or_null("Icon") as TextureRect if _icon_cluster else null
	if icon:
		icon.texture = _icon_texture

func _play_entry_motion() -> void:
	if panel == null:
		return
	if _panel_tween:
		_panel_tween.kill()
	panel.scale = Vector2(0.96, 0.96)
	panel.modulate = Color(1, 1, 1, 0.0)
	_panel_tween = panel.create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(panel, "scale", Vector2(1.035, 1.035), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	_panel_tween.chain().tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_idle_motion() -> void:
	_stop_idle_motion()
	if panel:
		_panel_breath_tween = panel.create_tween()
		_panel_breath_tween.set_loops()
		_panel_breath_tween.tween_property(panel, "scale", Vector2(1.012, 1.012), 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_panel_breath_tween.tween_property(panel, "scale", Vector2.ONE, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if confirm_button:
		confirm_button.pivot_offset = confirm_button.size * 0.5
		_button_tween = confirm_button.create_tween()
		_button_tween.set_loops()
		_button_tween.tween_property(confirm_button, "modulate", Color(1.08, 1.03, 0.88, 1.0), 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_button_tween.tween_property(confirm_button, "modulate", Color.WHITE, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _target_highlight and _target_highlight.visible:
		_target_tween = _target_highlight.create_tween()
		_target_tween.set_loops()
		_target_tween.tween_property(_target_highlight, "scale", Vector2(1.12, 1.12), 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.parallel().tween_property(_target_highlight, "modulate:a", 0.68, 0.52)
		_target_tween.tween_property(_target_highlight, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.parallel().tween_property(_target_highlight, "modulate:a", 1.0, 0.52)
	_play_dust_motion()

func _play_dust_motion() -> void:
	if _icon_cluster == null:
		return
	for i in range(8):
		var dust := _icon_cluster.get_node_or_null("Dust%d" % i) as ColorRect
		if dust == null:
			continue
		var start := dust.position
		var tween := dust.create_tween()
		tween.set_loops()
		tween.tween_interval(float(i) * 0.11)
		tween.tween_property(dust, "color:a", 0.86, 0.16)
		tween.parallel().tween_property(dust, "position", start + Vector2(0.0, -12.0 - float(i % 4) * 3.0), 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "color:a", 0.0, 0.24)
		tween.tween_callback(func() -> void:
			if is_instance_valid(dust):
				dust.position = start
		)
		_dust_tweens.append(tween)

func _stop_motion() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = null
	_stop_idle_motion()

func _stop_idle_motion() -> void:
	if _panel_breath_tween:
		_panel_breath_tween.kill()
	if _button_tween:
		_button_tween.kill()
	if _target_tween:
		_target_tween.kill()
	for tween in _dust_tweens:
		if tween:
			tween.kill()
	_dust_tweens.clear()
	_panel_breath_tween = null
	_button_tween = null
	_target_tween = null

func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.08, 0.17, 0.97)
	style.border_color = Color(0.0, 1.0, 0.86, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", style)

func _style_circle_panel(target: Panel, fill: Color, border: Color, radius: int, border_width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(1.0, 0.7, 0.16, 0.42)
	style.shadow_size = 24
	target.add_theme_stylebox_override("panel", style)

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
