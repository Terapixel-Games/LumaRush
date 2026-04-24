extends RefCounted
class_name ArcadeResponsiveLayout

const WIDE_ASPECT_THRESHOLD: float = 1.45
const ULTRA_WIDE_ASPECT_THRESHOLD: float = 1.9
const SHORT_HEIGHT_THRESHOLD: float = 760.0

static func viewport_aspect(viewport_size: Vector2) -> float:
	if viewport_size.y <= 0.0:
		return 1.0
	return viewport_size.x / viewport_size.y

static func is_wide(viewport_size: Vector2) -> bool:
	return viewport_aspect(viewport_size) >= WIDE_ASPECT_THRESHOLD

static func is_ultra_wide(viewport_size: Vector2) -> bool:
	return viewport_aspect(viewport_size) >= ULTRA_WIDE_ASPECT_THRESHOLD

static func is_wide_short(viewport_size: Vector2) -> bool:
	return is_wide(viewport_size) and viewport_size.y <= SHORT_HEIGHT_THRESHOLD

static func gameplay_content_ratio(viewport_size: Vector2) -> float:
	if is_ultra_wide(viewport_size):
		return 0.74
	if is_wide(viewport_size):
		return 0.7
	return 0.62

static func gameplay_hud_max_width(viewport_size: Vector2, portrait_max: float, landscape_max: float) -> float:
	return landscape_max if is_wide(viewport_size) else portrait_max

static func gameplay_powerups_max_width(viewport_size: Vector2, portrait_max: float, landscape_max: float) -> float:
	return landscape_max if is_wide(viewport_size) else portrait_max

static func results_panel_width_ratio(viewport_size: Vector2) -> float:
	if is_ultra_wide(viewport_size):
		return 0.72
	if is_wide_short(viewport_size):
		return 0.76
	if is_wide(viewport_size):
		return 0.7
	return 0.82

static func results_panel_height_ratio(viewport_size: Vector2) -> float:
	if is_wide_short(viewport_size):
		return 0.97
	if is_wide(viewport_size):
		return 0.92
	return 0.82
