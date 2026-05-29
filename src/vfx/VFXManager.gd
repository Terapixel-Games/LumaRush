extends Node

const EXPLOSION_SCENE := preload("res://src/vfx/PixelExplosion.tscn")
var _burst_texture: Texture2D
var _theme_palette: Array = []

func play_pixel_explosion(group: Array, tile_size: float, board_origin: Vector2, colors: Array) -> void:
	if group.is_empty():
		return
	var intensity: float = clamp(float(group.size()) / 3.0, 1.0, 2.6)
	var first: Vector2i = group[0]
	var min_x: int = first.x
	var max_x: int = first.x
	var min_y: int = first.y
	var max_y: int = first.y
	for p in group:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	var w: int = max_x - min_x + 1
	var h: int = max_y - min_y + 1
	var img := Image.create(int(w * tile_size), int(h * tile_size), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in group:
		var local_x := int((p.x - min_x) * tile_size)
		var local_y := int((p.y - min_y) * tile_size)
		var color_idx: int = int(colors[p.y][p.x]) if p.y < colors.size() and p.x < colors[p.y].size() else 0
		var c: Color = _color_from_index(color_idx)
		img.fill_rect(Rect2i(local_x, local_y, int(tile_size), int(tile_size)), c)
	var tex := ImageTexture.create_from_image(img)
	var explosion: Node2D = EXPLOSION_SCENE.instantiate()
	var parent := _resolve_vfx_parent()
	if parent == null:
		return
	parent.add_child(explosion)
	var pos := board_origin + Vector2(min_x * tile_size, min_y * tile_size)
	explosion.position = pos
	explosion.call("setup", tex, clamp(7.5 - intensity, 4.5, 6.5), float(randi() % 1000))
	var burst_center: Vector2 = board_origin + Vector2((min_x + max_x + 1) * tile_size * 0.5, (min_y + max_y + 1) * tile_size * 0.5)
	var tint := _color_from_index(int(colors[first.y][first.x]))
	_spawn_pop_burst(parent, burst_center, tint, intensity)
	_spawn_pop_burst(parent, burst_center + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)), Color(1.0, 1.0, 1.0, 0.94), intensity * 0.65)
	_spawn_shock_ring(parent, burst_center, tint, tile_size * (0.72 + intensity * 0.16))

func play_prism_clear(group: Array, tile_size: float, board_origin: Vector2, color_idx: int) -> void:
	if group.is_empty():
		return
	var parent := _resolve_vfx_parent()
	if parent == null:
		return
	var center: Vector2 = Vector2.ZERO
	for p in group:
		center += board_origin + Vector2((p.x + 0.5) * tile_size, (p.y + 0.5) * tile_size)
	center /= float(group.size())
	var tint: Color = _color_from_index(color_idx)
	_spawn_pop_burst(parent, center, tint, 1.65)
	_spawn_pop_burst(parent, center + Vector2(14, -10), Color(1.0, 1.0, 1.0, 0.9), 1.2)
	_spawn_pop_burst(parent, center + Vector2(-12, 10), tint.lightened(0.2), 1.35)
	_spawn_shock_ring(parent, center, tint, tile_size * 1.2)

func set_theme_palette(palette: Array) -> void:
	_theme_palette = palette.duplicate(true)

func _color_from_index(idx: int) -> Color:
	var palette := _theme_palette if _theme_palette.size() >= 3 else [
		Color(0.42, 0.8, 1.0, 0.9),
		Color(0.96, 0.62, 0.9, 0.9),
		Color(0.6, 0.95, 0.7, 0.9),
		Color(1.0, 0.85, 0.5, 0.9),
		Color(0.9, 0.6, 0.6, 0.9),
	]
	return palette[idx % palette.size()]

func _spawn_pop_burst(parent: Node, at: Vector2, tint: Color, intensity: float = 1.0) -> void:
	var burst := GPUParticles2D.new()
	if _burst_texture == null:
		_burst_texture = _build_burst_texture()
	burst.texture = _burst_texture
	burst.local_coords = false
	burst.top_level = true
	burst.one_shot = true
	burst.emitting = false
	burst.amount = int(round(180.0 * clamp(intensity, 0.75, 2.8)))
	burst.lifetime = 1.25 + (0.22 * clamp(intensity, 0.0, 2.0))
	burst.explosiveness = 1.0
	burst.global_position = at
	burst.modulate = Color(tint.r, tint.g, tint.b, 0.9)
	burst.z_index = 5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(1.0, 0.0, 0.0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 980.0 * clamp(intensity, 0.85, 2.2)
	pm.initial_velocity_max = 1480.0 * clamp(intensity, 0.85, 2.2)
	pm.linear_accel_min = 40.0
	pm.linear_accel_max = 80.0
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.06
	pm.scale_max = 0.16
	pm.radial_accel_min = 0.0
	pm.radial_accel_max = 0.0
	pm.color = Color(1, 1, 1, 1)
	burst.process_material = pm
	parent.add_child(burst)
	burst.emitting = true
	await get_tree().create_timer(1.9).timeout
	if is_instance_valid(burst):
		burst.queue_free()

func _spawn_shock_ring(parent: Node, at: Vector2, tint: Color, radius: float) -> void:
	var ring := Line2D.new()
	ring.name = "MatchShockRing"
	ring.top_level = true
	ring.global_position = at
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(tint.r, tint.g, tint.b, 0.88)
	ring.z_index = 6
	for i in range(48):
		var a: float = (TAU * float(i)) / 48.0
		ring.add_point(Vector2(cos(a), sin(a)) * radius)
	ring.scale = Vector2(0.16, 0.16)
	parent.add_child(ring)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.finished.connect(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _resolve_vfx_parent() -> Node:
	var parent := get_tree().current_scene
	if parent != null and parent.has_node("MidVFX"):
		parent = parent.get_node("MidVFX")
	if parent != null:
		return parent
	if get_tree() and get_tree().root:
		return get_tree().root
	return null

func _build_burst_texture() -> Texture2D:
	var size: int = 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius: float = size * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = center.distance_to(Vector2(x, y)) / radius
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)
