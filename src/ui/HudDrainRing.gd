extends Control
class_name HudDrainRing

var _time_fraction: float = 0.0
var _warning_amount: float = 0.0
var _pulse: float = 0.0

var time_fraction: float:
	get:
		return _time_fraction
	set(value):
		_time_fraction = clamp(value, 0.0, 1.0)
		queue_redraw()

var warning_amount: float:
	get:
		return _warning_amount
	set(value):
		_warning_amount = clamp(value, 0.0, 1.0)
		queue_redraw()

var pulse: float:
	get:
		return _pulse
	set(value):
		_pulse = clamp(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if size.x <= 4.0 or size.y <= 4.0:
		return
	var inset: float = clamp(min(size.x, size.y) * 0.08, 6.0, 12.0)
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var color := _ring_color()
	var warning_alpha: float = 0.10 + (_warning_amount * (0.16 + (_pulse * 0.18)))
	var glow_rect := rect.grow(6.0 + (_warning_amount * 6.0))
	draw_rect(glow_rect, Color(color.r, color.g, color.b, warning_alpha), false, 9.0 + (_warning_amount * 6.0), true)
	draw_rect(rect, Color(0.10, 0.05, 0.18, 0.38), false, 3.0, true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.20 + (_warning_amount * 0.16)), false, 2.0, true)

	var points := _perimeter_points(rect, _time_fraction)
	if points.size() >= 2:
		var width: float = 3.4 + (_warning_amount * 2.2)
		draw_polyline(points, Color(color.r, color.g, color.b, 0.96), width, true)
		var endpoint: Vector2 = points[points.size() - 1]
		draw_circle(endpoint, width * (1.35 + (_pulse * 0.55)), Color(color.r, color.g, color.b, 0.55 + (_warning_amount * 0.35)))
		draw_circle(endpoint, width * 0.58, Color(1.0, 0.96, 0.72, 0.92))

func _ring_color() -> Color:
	var urgency: float = 1.0 - _time_fraction
	var gold := Color(1.0, 0.86, 0.26, 1.0)
	var amber := Color(1.0, 0.46, 0.10, 1.0)
	var danger := Color(1.0, 0.10, 0.36, 1.0)
	if urgency < 0.58:
		return gold.lerp(amber, urgency / 0.58)
	return amber.lerp(danger, (urgency - 0.58) / 0.42)

func _perimeter_points(rect: Rect2, fraction: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if fraction <= 0.0:
		return points
	var half_w: float = rect.size.x * 0.5
	var h: float = rect.size.y
	var w: float = rect.size.x
	var segments: Array[Dictionary] = [
		{"from": Vector2(rect.position.x + half_w, rect.position.y), "to": Vector2(rect.end.x, rect.position.y), "length": half_w},
		{"from": Vector2(rect.end.x, rect.position.y), "to": rect.end, "length": h},
		{"from": rect.end, "to": Vector2(rect.position.x, rect.end.y), "length": w},
		{"from": Vector2(rect.position.x, rect.end.y), "to": rect.position, "length": h},
		{"from": rect.position, "to": Vector2(rect.position.x + half_w, rect.position.y), "length": half_w},
	]
	var total: float = (w * 2.0) + (h * 2.0)
	var remaining: float = total * clamp(fraction, 0.0, 1.0)
	var current: Vector2 = segments[0]["from"]
	points.append(current)
	for segment in segments:
		var length: float = float(segment["length"])
		var start: Vector2 = segment["from"]
		var finish: Vector2 = segment["to"]
		if remaining >= length:
			points.append(finish)
			remaining -= length
		else:
			var t: float = 0.0 if length <= 0.0 else remaining / length
			points.append(start.lerp(finish, t))
			break
	return points
