extends Control

signal dismissed(do_not_show_again: bool)

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var message_label: Label = $Center/Panel/VBox/Message
@onready var confirm_button: Button = $Center/Panel/VBox/Confirm
@onready var do_not_show_toggle: CheckButton = $Center/Panel/VBox/DoNotShow
@onready var center_layer: Control = $Center
@onready var panel: PanelContainer = $Center/Panel
@onready var content_box: VBoxContainer = $Center/Panel/VBox
@onready var dim: ColorRect = $Dim

var _pending_config: Dictionary = {}
var _bottom_offset: float = 112.0
var _target_rect: Rect2 = Rect2()
var _avoid_rect: Rect2 = Rect2()
var _icon_texture: Texture2D
var _icon_cluster: Control
var _target_highlight: Panel
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
	_layout_tip()
	_play_entry_motion()
	_play_idle_motion()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_apply_optional_style()
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

func _build_effect_nodes() -> void:
	if panel == null or center_layer == null:
		return
	_style_panel()
	_icon_cluster = Control.new()
	_icon_cluster.name = "IconCluster"
	_icon_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_layer.add_child(_icon_cluster)
	var glow := Panel.new()
	glow.name = "Glow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_circle_panel(glow, Color(1.0, 0.76, 0.22, 0.20), Color(1.0, 0.93, 0.48, 0.72), 44, 3)
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
	var panel_width: float = clamp(view_size.x * 0.74, 620.0, 940.0)
	if view_size.x < 720.0:
		panel_width = max(320.0, view_size.x - (margin * 2.0))
	var panel_height: float = clamp(view_size.y * 0.19, 172.0, 218.0)
	if view_size.x < 720.0:
		panel_height = clamp(view_size.y * 0.36, 292.0, 380.0)
	var panel_x: float = (view_size.x - panel_width) * 0.5
	var panel_y: float = _target_rect.position.y - panel_height - clamp(view_size.y * 0.035, 22.0, 40.0) if _target_rect.size.y > 0.0 else view_size.y - _bottom_offset - panel_height
	if panel_y < margin:
		panel_y = view_size.y - _bottom_offset - panel_height
	var proposed_rect := Rect2(Vector2(panel_x, panel_y), Vector2(panel_width, panel_height))
	if _should_side_place(proposed_rect, view_size, margin):
		var side_layout := _side_layout(view_size, margin, panel_width, panel_height)
		panel_x = side_layout.position.x
		panel_y = side_layout.position.y
		panel_width = side_layout.size.x
	panel_y = clamp(panel_y, margin, max(margin, view_size.y - panel_height - margin))
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_width, panel_height)
	panel.pivot_offset = panel.size * 0.5
	if view_size.x >= 720.0:
		content_box.offset_left = 132.0
		content_box.offset_top = 18.0
		content_box.offset_right = -28.0
		content_box.offset_bottom = -18.0
		_icon_cluster.position = panel.position + Vector2(30.0, 22.0)
		_icon_cluster.size = Vector2(78.0, 78.0)
	else:
		content_box.offset_left = 24.0
		content_box.offset_top = 104.0
		content_box.offset_right = -24.0
		content_box.offset_bottom = -24.0
		_icon_cluster.position = panel.position + Vector2((panel_width - 76.0) * 0.5, 18.0)
		_icon_cluster.size = Vector2(76.0, 76.0)
	_layout_icon_children()
	_layout_target_effects(panel.position, panel.size)

func _should_side_place(proposed_rect: Rect2, view_size: Vector2, margin: float) -> bool:
	if view_size.x < 960.0:
		return false
	if _avoid_rect.size == Vector2.ZERO:
		return false
	if not proposed_rect.intersects(_avoid_rect):
		return false
	var left_space: float = _avoid_rect.position.x - margin
	var right_space: float = view_size.x - _avoid_rect.end.x - margin
	return max(left_space, right_space) >= 420.0

func _side_layout(view_size: Vector2, margin: float, panel_width: float, panel_height: float) -> Rect2:
	var side_gap: float = clamp(view_size.x * 0.024, 28.0, 52.0)
	var left_space: float = _avoid_rect.position.x - side_gap - margin
	var right_space: float = view_size.x - _avoid_rect.end.x - side_gap - margin
	var place_right := right_space >= left_space
	var width: float = min(panel_width, max(420.0, right_space if place_right else left_space))
	var x: float = _avoid_rect.end.x + side_gap if place_right else _avoid_rect.position.x - side_gap - width
	var target_center_y: float = _target_rect.get_center().y if _target_rect.size != Vector2.ZERO else _avoid_rect.end.y
	var y: float = clamp(target_center_y - (panel_height * 0.68), margin, max(margin, view_size.y - _bottom_offset - panel_height))
	return Rect2(Vector2(x, y), Vector2(width, panel_height))

func _layout_icon_children() -> void:
	if _icon_cluster == null:
		return
	var icon := _icon_cluster.get_node_or_null("Icon") as TextureRect
	if icon:
		icon.position = _icon_cluster.size * 0.16
		icon.size = _icon_cluster.size * 0.68
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
	style.bg_color = Color(0.035, 0.045, 0.105, 0.96)
	style.border_color = Color(0.74, 0.96, 1.0, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(1.0, 0.64, 0.12, 0.26)
	style.shadow_size = 28
	style.shadow_offset = Vector2(0, 0)
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
