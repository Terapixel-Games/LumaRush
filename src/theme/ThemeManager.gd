extends Node

const THEME_DEFAULT := "default"
const THEME_NEON := "neon"

const THEMES := {
	THEME_DEFAULT: {
		"display_name": "Default",
		"background_calm_a": Color(0.005, 0.012, 0.035, 1.0),
		"background_calm_b": Color(0.018, 0.032, 0.090, 1.0),
		"background_hype_a": Color(0.0, 0.10, 0.24, 1.0),
		"background_hype_b": Color(0.52, 0.0, 0.72, 1.0),
		"tile_palette": [
			Color(0.00, 0.96, 1.00, 0.98),
			Color(1.00, 0.12, 0.02, 0.98),
			Color(0.18, 1.00, 0.18, 0.98),
			Color(1.00, 0.88, 0.00, 0.98),
			Color(0.30, 0.20, 1.00, 0.98),
		],
		"vfx_palette": [
			Color(0.00, 0.96, 1.00, 0.94),
			Color(1.00, 0.18, 0.08, 0.94),
			Color(0.28, 1.00, 0.70, 0.94),
			Color(1.00, 0.90, 0.26, 0.94),
			Color(0.44, 0.46, 1.00, 0.94),
		],
		"panel_tint": Color(0.12, 0.18, 0.32, 0.22),
	},
	THEME_NEON: {
		"display_name": "Neon",
		"background_calm_a": Color(0.005, 0.012, 0.035, 1.0),
		"background_calm_b": Color(0.020, 0.032, 0.092, 1.0),
		"background_hype_a": Color(0.0, 0.10, 0.24, 1.0),
		"background_hype_b": Color(0.18, 0.0, 0.34, 1.0),
		"tile_palette": [
			Color(0.00, 0.96, 1.00, 0.98),
			Color(1.00, 0.12, 0.02, 0.98),
			Color(0.18, 1.00, 0.18, 0.98),
			Color(1.00, 0.88, 0.00, 0.98),
			Color(0.30, 0.20, 1.00, 0.98),
		],
		"vfx_palette": [
			Color(0.00, 0.96, 1.00, 0.94),
			Color(1.00, 0.18, 0.08, 0.94),
			Color(0.28, 1.00, 0.70, 0.94),
			Color(1.00, 0.90, 0.26, 0.94),
			Color(0.44, 0.46, 1.00, 0.94),
		],
		"panel_tint": Color(0.08, 0.05, 0.2, 0.34),
	},
}

func get_current_theme_id() -> String:
	var theme_id := SaveStore.get_equipped_theme()
	if not THEMES.has(theme_id):
		return THEME_DEFAULT
	return theme_id

func get_theme_config(theme_id: String = "") -> Dictionary:
	var resolved := theme_id.strip_edges().to_lower()
	if resolved.is_empty():
		resolved = get_current_theme_id()
	if not THEMES.has(resolved):
		resolved = THEME_DEFAULT
	return (THEMES[resolved] as Dictionary).duplicate(true)

func apply_to_scene(scene: Node) -> void:
	if scene == null:
		return
	var config := get_theme_config()
	apply_to_background(scene.get_node_or_null("BackgroundController"), config)
	apply_to_board(scene.get_node_or_null("BoardView"), config)
	apply_to_ui(scene, config)
	apply_to_vfx(config)

func apply_from_shop_state(shop: Dictionary) -> void:
	var theme_id := str(shop.get("equippedTheme", THEME_DEFAULT)).strip_edges().to_lower()
	if not THEMES.has(theme_id):
		theme_id = THEME_DEFAULT
	SaveStore.set_equipped_theme(theme_id)
	var owned_var: Variant = shop.get("ownedThemes", ["default"])
	if typeof(owned_var) == TYPE_ARRAY:
		SaveStore.set_owned_themes(owned_var as Array)
	var rentals_var: Variant = shop.get("themeRentals", {})
	if typeof(rentals_var) == TYPE_DICTIONARY:
		SaveStore.set_theme_rentals(rentals_var as Dictionary)

func apply_to_background(controller: Node, config: Dictionary) -> void:
	if controller == null:
		return
	if controller.has_method("set_theme_palette"):
		controller.call(
			"set_theme_palette",
			config.get("background_calm_a"),
			config.get("background_calm_b"),
			config.get("background_hype_a"),
			config.get("background_hype_b")
		)

func apply_to_board(board: Node, config: Dictionary) -> void:
	if board == null:
		return
	if board.has_method("set_theme_palette"):
		board.call("set_theme_palette", config.get("tile_palette", []))

func apply_to_vfx(config: Dictionary) -> void:
	if VFXManager and VFXManager.has_method("set_theme_palette"):
		VFXManager.call("set_theme_palette", config.get("vfx_palette", []))

func apply_to_ui(scene: Node, config: Dictionary) -> void:
	var panel: ColorRect = scene.get_node_or_null("UI/Panel")
	if panel:
		panel.color = config.get("panel_tint", panel.color)
