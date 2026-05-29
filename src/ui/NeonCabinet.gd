extends Control
class_name NeonCabinet

@export_enum("game", "menu", "results") var mode: String = "game"

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var cyan := Color(0.08, 0.88, 1.0, 0.86)
	var magenta := Color(1.0, 0.16, 0.86, 0.76)
	var amber := Color(1.0, 0.64, 0.08, 0.74)
	var shell := Color(0.004, 0.008, 0.026, 0.88)
	var panel := Color(0.012, 0.026, 0.078, 0.62)
	var pulse: float = 0.72 + (sin(_t * 2.2) * 0.08)

	draw_rect(r, Color(0.0, 0.004, 0.016, 0.30), true)
	_draw_rails(r, shell, cyan * Color(1, 1, 1, pulse), magenta)
	_draw_corner_blocks(r, cyan, magenta, amber)
	_draw_scanlines(r, cyan)
	if mode == "menu":
		_draw_horizon(r, cyan, magenta)
	elif mode == "results":
		_draw_shards(r, cyan, magenta, amber)
	else:
		_draw_playfield_well(r, panel, cyan, magenta)

func _draw_rails(r: Rect2, shell: Color, cyan: Color, magenta: Color) -> void:
	var rail_w: float = clamp(r.size.x * 0.035, 16.0, 48.0)
	var rail_top: float = clamp(r.size.y * 0.018, 10.0, 30.0)
	var left := Rect2(Vector2(0, 0), Vector2(rail_w, r.size.y))
	var right := Rect2(Vector2(r.size.x - rail_w, 0), Vector2(rail_w, r.size.y))
	var top := Rect2(Vector2(0, 0), Vector2(r.size.x, rail_top))
	var bottom := Rect2(Vector2(0, r.size.y - rail_top), Vector2(r.size.x, rail_top))
	for rect in [left, right, top, bottom]:
		draw_rect(rect, shell, true)
	draw_line(Vector2(rail_w * 0.55, rail_top), Vector2(rail_w * 0.55, r.size.y - rail_top), cyan, 3.0, true)
	draw_line(Vector2(r.size.x - rail_w * 0.55, rail_top), Vector2(r.size.x - rail_w * 0.55, r.size.y - rail_top), cyan, 3.0, true)
	draw_line(Vector2(rail_w, rail_top * 0.55), Vector2(r.size.x - rail_w, rail_top * 0.55), magenta, 2.0, true)
	draw_line(Vector2(rail_w, r.size.y - rail_top * 0.55), Vector2(r.size.x - rail_w, r.size.y - rail_top * 0.55), magenta, 2.0, true)

func _draw_corner_blocks(r: Rect2, cyan: Color, magenta: Color, amber: Color) -> void:
	var s: float = clamp(min(r.size.x, r.size.y) * 0.085, 54.0, 118.0)
	var pad: float = clamp(s * 0.18, 10.0, 18.0)
	var corners := [
		Vector2(pad, pad),
		Vector2(r.size.x - s - pad, pad),
		Vector2(pad, r.size.y - s - pad),
		Vector2(r.size.x - s - pad, r.size.y - s - pad),
	]
	for i in range(corners.size()):
		var p: Vector2 = corners[i]
		var c: Color = cyan if i % 2 == 0 else magenta
		var block := Rect2(p, Vector2(s, s * 0.58))
		if i >= 2:
			block.position.y = p.y + s * 0.42
		draw_rect(block, Color(0.018, 0.032, 0.095, 0.78), true)
		draw_rect(block, c, false, 3.0, true)
		draw_line(block.position + Vector2(8, block.size.y * 0.5), block.end - Vector2(8, block.size.y * 0.5), amber if i >= 2 else c, 2.0, true)

func _draw_scanlines(r: Rect2, cyan: Color) -> void:
	var count: int = 9
	for i in range(count):
		var p: float = fmod((_t * 0.05) + (float(i) / float(count)), 1.0)
		var y: float = lerp(r.size.y * 0.08, r.size.y * 0.94, p)
		draw_line(Vector2(r.size.x * 0.08, y), Vector2(r.size.x * 0.92, y + 18.0), Color(cyan.r, cyan.g, cyan.b, 0.05), 1.0, true)

func _draw_horizon(r: Rect2, cyan: Color, magenta: Color) -> void:
	var c := r.size * 0.5
	var horizon_y: float = r.size.y * 0.43
	draw_circle(c + Vector2(0, -r.size.y * 0.06), min(r.size.x, r.size.y) * 0.24, Color(0.9, 0.1, 1.0, 0.10))
	for i in range(8):
		var u: float = float(i) / 7.0
		var x: float = lerp(r.size.x * 0.12, r.size.x * 0.88, u)
		draw_line(Vector2(x, horizon_y), Vector2(lerp(c.x - r.size.x * 0.38, c.x + r.size.x * 0.38, u), r.size.y), cyan if i % 2 == 0 else magenta, 1.4, true)

func _draw_playfield_well(r: Rect2, panel: Color, cyan: Color, magenta: Color) -> void:
	var well := Rect2(Vector2(r.size.x * 0.12, r.size.y * 0.18), Vector2(r.size.x * 0.76, r.size.y * 0.64))
	draw_rect(well.grow(18.0), Color(0.0, 0.0, 0.0, 0.30), true)
	draw_rect(well.grow(12.0), panel, true)
	draw_rect(well.grow(12.0), Color(cyan.r, cyan.g, cyan.b, 0.24), false, 3.0, true)
	draw_rect(well.grow(24.0), Color(magenta.r, magenta.g, magenta.b, 0.10), false, 2.0, true)

func _draw_shards(r: Rect2, cyan: Color, magenta: Color, amber: Color) -> void:
	var colors := [cyan, magenta, amber]
	for i in range(18):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var y: float = fmod(_t * 24.0 + float(i) * 71.0, r.size.y)
		var x: float = r.size.x * (0.08 if side < 0.0 else 0.92) + sin(float(i) * 1.7) * 34.0
		var s: float = 8.0 + float(i % 5) * 3.0
		var c: Color = colors[i % colors.size()]
		c.a = 0.34
		draw_colored_polygon([Vector2(x, y - s), Vector2(x + side * s, y + s), Vector2(x - side * s * 0.7, y + s * 0.5)], c)
