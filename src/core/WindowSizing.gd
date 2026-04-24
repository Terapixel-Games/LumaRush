extends RefCounted

static func compute_window_size_for_display(base_size: Vector2i, usable_rect: Rect2i) -> Vector2i:
	if base_size.x <= 0 or base_size.y <= 0:
		return Vector2i.ZERO
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return base_size
	var scale: float = float(usable_rect.size.y) / float(base_size.y)
	var width: int = int(round(float(base_size.x) * scale))
	var height: int = int(round(float(base_size.y) * scale))
	if width > usable_rect.size.x:
		scale = float(usable_rect.size.x) / float(base_size.x)
		width = int(round(float(base_size.x) * scale))
		height = int(round(float(base_size.y) * scale))
	return Vector2i(maxi(width, 1), maxi(height, 1))

static func compute_window_position(usable_rect: Rect2i, window_size: Vector2i) -> Vector2i:
	var offset_x: int = maxi(int(round(float(usable_rect.size.x - window_size.x) * 0.5)), 0)
	var offset_y: int = maxi(int(round(float(usable_rect.size.y - window_size.y) * 0.5)), 0)
	return usable_rect.position + Vector2i(offset_x, offset_y)
