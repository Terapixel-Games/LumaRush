extends Control
class_name NeonTrackGate

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var center := rect.size * 0.5
	var min_axis: float = min(rect.size.x, rect.size.y)
	var gate_w: float = clamp(rect.size.x * 0.58, 460.0, 1180.0)
	var gate_h: float = clamp(rect.size.y * 0.40, 280.0, 540.0)
	var gate := Rect2(center - Vector2(gate_w, gate_h) * 0.5, Vector2(gate_w, gate_h))
	var glow_color := Color(0.08, 0.86, 1.0, 0.34)
	var magenta := Color(0.88, 0.18, 1.0, 0.30)
	var orange := Color(1.0, 0.42, 0.05, 0.34)
	var dark_fill := Color(0.015, 0.026, 0.075, 0.50)

	draw_circle(center, min_axis * 0.52, Color(0.03, 0.08, 0.18, 0.20))
	draw_circle(center + Vector2(0.0, gate_h * 0.12), min_axis * 0.34, Color(0.38, 0.05, 0.55, 0.13))

	var horizon_y: float = gate.position.y + gate_h * 0.44
	var gate_left := Vector2(gate.position.x, horizon_y)
	var gate_right := Vector2(gate.end.x, horizon_y)
	var lane_left_bottom := Vector2(center.x - gate_w * 0.44, rect.size.y + 80.0)
	var lane_right_bottom := Vector2(center.x + gate_w * 0.44, rect.size.y + 80.0)
	draw_colored_polygon(
		[gate_left, gate_right, lane_right_bottom, lane_left_bottom],
		Color(0.02, 0.04, 0.12, 0.42)
	)
	for i in range(6):
		var u: float = float(i) / 5.0
		var x_top: float = lerp(gate_left.x, gate_right.x, u)
		var x_bottom: float = lerp(lane_left_bottom.x, lane_right_bottom.x, u)
		var lane_color := Color(0.08, 0.82, 1.0, 0.18 if i == 0 or i == 5 else 0.12)
		draw_line(Vector2(x_top, horizon_y), Vector2(x_bottom, rect.size.y), lane_color, 2.0, true)
	for i in range(7):
		var p: float = fmod(_t * 0.25 + float(i) / 7.0, 1.0)
		var y: float = lerp(horizon_y, rect.size.y + 40.0, p * p)
		var half_w: float = lerp(gate_w * 0.10, gate_w * 0.46, p)
		var alpha: float = lerp(0.42, 0.02, p)
		draw_line(Vector2(center.x - half_w, y), Vector2(center.x + half_w, y), Color(0.95, 0.98, 1.0, alpha), 2.0, true)

	for i in range(5):
		var inset: float = float(i) * 22.0
		var r := gate.grow(-inset)
		var color := glow_color.lerp(magenta, float(i) / 5.0)
		color.a = 0.36 - float(i) * 0.045
		draw_arc(r.get_center(), max(4.0, r.size.x * 0.5), PI, TAU, 64, color, 3.0, true)
		draw_arc(r.get_center(), max(4.0, r.size.y * 0.5), 0.0, PI, 64, Color(color.r, color.g, color.b, color.a * 0.35), 2.0, true)

	var gate_body := gate.grow(12.0)
	draw_rect(gate_body, dark_fill, true)
	draw_rect(gate_body, Color(0.07, 0.92, 1.0, 0.46), false, 3.0)
	draw_rect(gate_body.grow(-10.0), Color(0.95, 0.20, 1.0, 0.22), false, 2.0)

	var start_bar := Rect2(
		Vector2(gate.position.x + gate_w * 0.17, gate.position.y + gate_h * 0.61),
		Vector2(gate_w * 0.66, max(8.0, gate_h * 0.035))
	)
	draw_rect(start_bar.grow(4.0), orange, true)
	draw_rect(start_bar, Color(1.0, 0.88, 0.42, 0.78), true)

	for side in [-1.0, 1.0]:
		var pillar_x: float = center.x + side * gate_w * 0.42
		var top := Vector2(pillar_x, gate.position.y - gate_h * 0.04)
		var bottom := Vector2(pillar_x + side * gate_w * 0.06, gate.end.y + gate_h * 0.08)
		draw_line(top, bottom, Color(0.12, 0.9, 1.0, 0.62), 6.0, true)
		draw_line(top + Vector2(side * 10.0, 0.0), bottom + Vector2(side * 18.0, 0.0), magenta, 3.0, true)
