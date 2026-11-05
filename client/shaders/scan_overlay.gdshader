shader_type canvas_item;
// Kamera üzerine AR tarama efekti: hareketli çizgi, ızgara, köşe çerçeveleri.

uniform vec4 tint : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float scan_speed = 0.45;

void fragment() {
	float y = fract(TIME * scan_speed);
	float line = smoothstep(0.025, 0.0, abs(UV.y - y));
	float trail = smoothstep(0.25, 0.0, y - UV.y) * step(UV.y, y) * 0.18;
	vec2 g = abs(fract(UV * vec2(9.0, 14.0)) - 0.5);
	float grid = smoothstep(0.47, 0.5, max(g.x, g.y)) * 0.10;
	vec2 e = min(UV, 1.0 - UV);
	float corner_v = step(e.x, 0.018) * step(e.y, 0.11);
	float corner_h = step(e.y, 0.011) * step(e.x, 0.16);
	float corner = clamp(corner_v + corner_h, 0.0, 1.0);
	float a = (line * 0.85 + trail + grid) * intensity + corner * 0.95;
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 1.0));
}
