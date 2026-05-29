shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 edge_color : source_color = vec4(0.10, 0.90, 1.0, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.12, 0.62, 1.0);
uniform float scanline_strength : hint_range(0.0, 0.35) = 0.10;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.42;
uniform float diagonal_strength : hint_range(0.0, 0.8) = 0.28;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.12;
uniform float corner_falloff : hint_range(0.0, 4.0) = 1.4;

void fragment() {
	vec4 base = COLOR;
	vec2 uv = UV;
	vec2 edge_uv = min(uv, 1.0 - uv);
	float edge_mask = 1.0 - smoothstep(0.0, 0.12, min(edge_uv.x, edge_uv.y));
	float corner = pow(1.0 - clamp(length(uv - vec2(0.5)) * 1.28, 0.0, 1.0), corner_falloff);
	float diag = smoothstep(0.74, 1.0, 1.0 - abs((uv.x - uv.y) * 0.74));
	float scan = sin((uv.y + TIME * 0.22) * 720.0) * 0.5 + 0.5;
	float pulse = sin(TIME * 4.0) * 0.5 + 0.5;
	vec3 glow = edge_color.rgb * edge_mask * edge_strength;
	glow += hot_color.rgb * diag * diagonal_strength;
	glow += hot_color.rgb * corner * pulse * pulse_strength;
	base.rgb += glow;
	base.rgb *= 1.0 - (scan * scanline_strength * 0.28);
	base.a *= COLOR.a;
	COLOR = base;
}
