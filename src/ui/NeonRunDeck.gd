extends RefCounted
class_name NeonRunDeck

const SURFACE_PANEL: Color = Color(0.055, 0.075, 0.17, 0.90)
const SURFACE_CARD: Color = Color(0.075, 0.10, 0.22, 0.82)
const TEXT_MAIN: Color = Color(0.94, 0.985, 1.0, 1.0)
const TEXT_SOFT: Color = Color(0.68, 0.80, 1.0, 0.94)
const TEXT_DIM: Color = Color(0.42, 0.55, 0.78, 0.88)
const SHADOW: Color = Color(0.005, 0.015, 0.045, 0.92)
const BACKDROP: Color = Color(0.01, 0.015, 0.04, 0.78)

static func apply_main_menu(scene: Node) -> void:
	var bg_controller := scene.get_node_or_null("BackgroundController")
	if bg_controller != null and bg_controller.is_node_ready() and bg_controller.has_method("set_theme_palette"):
		bg_controller.call(
			"set_theme_palette",
			Color(0.01, 0.025, 0.075, 1.0),
			Color(0.035, 0.07, 0.18, 1.0),
			Color(0.08, 0.04, 0.22, 1.0),
			Color(0.55, 0.10, 0.95, 1.0)
		)
	_style_color_rect(scene.get_node_or_null("BackgroundController/ColorRect"), Color(0.01, 0.02, 0.06, 1.0))
	_style_color_rect(scene.get_node_or_null("BackgroundController/CenterGlow"), Color(0.55, 0.10, 1.0, 0.18))
	_style_color_rect(scene.get_node_or_null("UI/RootMargin/Layout/Center/PanelShell/Panel"), Color(0.035, 0.052, 0.13, 0.95))
	_style_panels(scene, [
		"UI/RootMargin/Layout/Center/PanelShell",
		"UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/Scroll/VBox/DeckHeader/HeroCard",
		"UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/Scroll/VBox/DeckHeader/LaunchCard",
	], "panel")
	_style_panels(scene, _find_paths_containing(scene, "Card"), "card")
	_style_buttons(scene, [
		"UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/Scroll/VBox/DeckHeader/HeroCard/Margin/VBox/Start",
		"UI/RootMargin/Layout/Center/PanelShell/Panel/ContentMargin/Scroll/VBox/DeckHeader/LaunchCard/Margin/VBox/Start",
	], "primary")
	_style_buttons(scene, [
		"UI/RootMargin/Layout/TopBar/Account",
		"UI/RootMargin/Layout/TopBar/Shop",
		"UI/RootMargin/Layout/TopBar/Audio",
	], "icon")
	_style_buttons(scene, _find_button_paths(scene, "Toggle") + _find_button_paths(scene, "Info") + _find_button_paths(scene, "Promo"), "secondary")
	_style_panels(scene, ["UI/RootMargin/Layout/TopBar/Shop/CoinBadge"], "badge")
	_style_glass_surfaces(scene)
	_tint_labels(scene)

static func apply_game(scene: Node) -> void:
	_style_color_rect(scene.get_node_or_null("UI/TopBarBg"), Color(0.035, 0.055, 0.14, 0.78))
	_style_color_rect(scene.get_node_or_null("UI/BoardFrame"), Color(0.20, 0.92, 1.0, 0.15))
	_style_color_rect(scene.get_node_or_null("UI/BoardGlow"), Color(0.9, 0.20, 1.0, 0.08))
	_style_panels(scene, _find_paths_containing(scene, "Badge"), "hot_badge")
	_style_buttons(scene, ["UI/TopBar/Pause", "UI/TopRightBar/Audio"], "icon")
	_style_buttons(scene, ["UI/Powerups/Undo", "UI/Powerups/RemoveColor", "UI/Powerups/Hint", "UI/Powerups/Shuffle"], "powerup")
	_style_glass_surfaces(scene)
	_tint_labels(scene)

static func apply_results(scene: Node) -> void:
	_style_color_rect(scene.get_node_or_null("UI/Panel"), Color(0.035, 0.052, 0.13, 0.95))
	_style_panels(scene, ["UI/Panel"], "panel")
	_style_buttons(scene, ["UI/Panel/Scroll/VBox/PlayAgain"], "primary")
	_style_buttons(scene, ["UI/Panel/Scroll/VBox/DoubleReward"], "reward")
	_style_buttons(scene, ["UI/Panel/Scroll/VBox/Menu", "UI/TopRightBar/Audio"], "secondary")
	_style_glass_surfaces(scene)
	_tint_labels(scene)

static func apply_pause(scene: Node) -> void:
	_style_panels(scene, ["Panel"], "panel")
	_style_buttons(scene, ["VBox/Resume", "Panel/VBox/Resume"], "primary")
	_style_buttons(scene, ["VBox/Quit", "Panel/VBox/Quit"], "secondary")
	_style_glass_surfaces(scene)
	_tint_labels(scene)

static func apply_modal(scene: Node) -> void:
	_style_color_rect(scene.get_node_or_null("Backdrop"), BACKDROP)
	_style_color_rect(scene.get_node_or_null("Center/Panel"), SURFACE_PANEL)
	_style_panels(scene, ["Panel", "Center/Panel", "Panel/VBox/Footer"], "panel")
	_style_panels(scene, _find_paths_containing(scene, "Header") + _find_paths_containing(scene, "Card") + _find_paths_containing(scene, "Pack") + _find_paths_containing(scene, "Theme") + _find_paths_containing(scene, "Buy"), "card")
	_style_all_buttons(scene, "secondary")
	for path in [
		"Panel/VBox/SaveButton",
		"Center/Panel/VBox/SaveButton",
		"Panel/VBox/Scroll/Content/SendMagicLink",
		"Panel/VBox/Scroll/Content/UpdateUsername",
		"Panel/VBox/Scroll/Content/CreateMergeCode",
		"Panel/VBox/Scroll/Content/RedeemMergeCode",
	]:
		_style_button(scene.get_node_or_null(path), "primary")
	_style_line_edits(scene)
	_style_glass_surfaces(scene)
	_tint_labels(scene)

static func make_style(kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE_CARD
	style.border_color = Color(0.45, 0.86, 1.0, 0.34)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 5
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.2
	match kind:
		"panel":
			style.bg_color = SURFACE_PANEL
			style.border_color = Color(0.18, 0.86, 1.0, 0.42)
			style.corner_radius_top_left = 26
			style.corner_radius_top_right = 26
			style.corner_radius_bottom_left = 26
			style.corner_radius_bottom_right = 26
			style.shadow_color = Color(0.0, 0.02, 0.08, 0.48)
			style.shadow_size = 11
		"primary":
			style.bg_color = Color(1.0, 0.45, 0.10, 0.98)
			style.border_color = Color(1.0, 0.92, 0.52, 0.98)
			style.shadow_color = Color(1.0, 0.35, 0.0, 0.34)
			style.shadow_size = 7
			style.corner_radius_top_left = 20
			style.corner_radius_top_right = 20
			style.corner_radius_bottom_left = 20
			style.corner_radius_bottom_right = 20
		"reward":
			style.bg_color = Color(0.04, 0.12, 0.23, 0.78)
			style.border_color = Color(0.08, 0.88, 1.0, 0.92)
			style.shadow_color = Color(0.02, 0.8, 1.0, 0.18)
		"secondary":
			style.bg_color = Color(0.06, 0.10, 0.22, 0.74)
			style.border_color = Color(0.18, 0.84, 1.0, 0.72)
		"icon":
			style.bg_color = Color(0.06, 0.10, 0.22, 0.82)
			style.border_color = Color(0.82, 0.95, 1.0, 0.84)
		"powerup":
			style.bg_color = Color(0.09, 0.10, 0.25, 0.82)
			style.border_color = Color(0.82, 0.90, 1.0, 0.86)
			style.shadow_color = Color(0.50, 0.10, 1.0, 0.22)
			style.shadow_size = 6
		"badge", "hot_badge":
			style.bg_color = Color(1.0, 0.22, 0.34, 0.98)
			style.border_color = Color(1.0, 0.88, 0.92, 0.98)
			style.corner_radius_top_left = 999
			style.corner_radius_top_right = 999
			style.corner_radius_bottom_left = 999
			style.corner_radius_bottom_right = 999
			style.shadow_size = 2
	return style

static func _style_color_rect(node: Node, color: Color) -> void:
	if node is ColorRect:
		(node as ColorRect).color = color

static func _style_panels(scene: Node, paths: Array, kind: String) -> void:
	for path in paths:
		var node := scene.get_node_or_null(str(path))
		if node is PanelContainer:
			(node as PanelContainer).add_theme_stylebox_override("panel", make_style(kind))
		elif node is ColorRect:
			(node as ColorRect).color = make_style(kind).bg_color

static func _style_buttons(scene: Node, paths: Array, kind: String) -> void:
	for path in paths:
		_style_button(scene.get_node_or_null(str(path)), kind)

static func _style_all_buttons(scene: Node, kind: String) -> void:
	for node in scene.find_children("*", "Button", true, false):
		_style_button(node, kind)

static func _style_button(node: Node, kind: String) -> void:
	if not node is BaseButton:
		return
	var button := node as BaseButton
	var normal := make_style(kind)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.border_color = normal.border_color.lightened(0.12)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.14)
	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = normal.bg_color.darkened(0.22)
	disabled_style.border_color = normal.border_color * Color(1.0, 1.0, 1.0, 0.55)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", TEXT_MAIN)
	button.add_theme_color_override("font_focus_color", TEXT_MAIN)
	button.add_theme_color_override("font_disabled_color", TEXT_SOFT)
	button.add_theme_color_override("font_outline_color", SHADOW)
	button.add_theme_constant_override("outline_size", 2)
	_apply_glass_node(button, kind)
	if button.has_method("_sync_glass_state"):
		button.call_deferred("_sync_glass_state")

static func _tint_labels(scene: Node) -> void:
	for node in scene.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		var name_lower := label.name.to_lower()
		var color := TEXT_SOFT if name_lower.contains("meta") or name_lower.contains("status") or name_lower.contains("subtitle") or name_lower.contains("kicker") else TEXT_MAIN
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", SHADOW)
		label.add_theme_constant_override("outline_size", 2)

static func _style_line_edits(scene: Node) -> void:
	for node in scene.find_children("*", "LineEdit", true, false):
		var edit := node as LineEdit
		if edit == null:
			continue
		edit.add_theme_stylebox_override("normal", make_style("secondary"))
		edit.add_theme_stylebox_override("focus", make_style("reward"))
		edit.add_theme_color_override("font_color", TEXT_MAIN)
		edit.add_theme_color_override("font_placeholder_color", TEXT_DIM)
		edit.add_theme_font_size_override("font_size", 26)
		edit.custom_minimum_size.y = max(edit.custom_minimum_size.y, 64.0)

static func _style_glass_surfaces(scene: Node) -> void:
	for node in scene.find_children("*", "ColorRect", true, false):
		_apply_glass_node(node, "panel")

static func _apply_glass_node(node: Node, kind: String) -> void:
	if node == null:
		return
	var tint := Color(0.04, 0.07, 0.16, 0.72)
	var edge := Color(0.12, 0.86, 1.0, 0.62)
	if kind == "primary":
		tint = Color(1.0, 0.36, 0.08, 0.72)
		edge = Color(1.0, 0.88, 0.42, 0.9)
	elif kind == "powerup":
		tint = Color(0.08, 0.08, 0.22, 0.72)
		edge = Color(0.85, 0.92, 1.0, 0.82)
	if _has_property(node, "tint"):
		node.set("tint", tint)
	if _has_property(node, "edge"):
		node.set("edge", edge)
	if _has_property(node, "edge_highlight"):
		node.set("edge_highlight", edge)
	if _has_property(node, "corner_radius"):
		node.set("corner_radius", 0.08 if kind == "panel" else 0.32)
	if node is CanvasItem:
		var canvas := node as CanvasItem
		if canvas.material is ShaderMaterial:
			var material := canvas.material as ShaderMaterial
			material.set_shader_parameter("tint", tint)
			material.set_shader_parameter("edge_highlight", edge)
		if node is ColorRect and _has_property(node, "tint"):
			(node as ColorRect).color = tint

static func _has_property(node: Node, property_name: String) -> bool:
	for row in node.get_property_list():
		if str(row.get("name", "")) == property_name:
			return true
	return false

static func _find_paths_containing(scene: Node, needle: String) -> Array[String]:
	var out: Array[String] = []
	for node in scene.find_children("*%s*" % needle, "Control", true, false):
		var control := node as Control
		if control != null:
			out.append(str(scene.get_path_to(control)))
	return out

static func _find_button_paths(scene: Node, needle: String) -> Array[String]:
	var out: Array[String] = []
	for node in scene.find_children("*%s*" % needle, "Button", true, false):
		var button := node as Button
		if button != null:
			out.append(str(scene.get_path_to(button)))
	return out
