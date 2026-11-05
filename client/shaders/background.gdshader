shader_type canvas_item;
// Yavaşça akan derin renk geçişli arka plan.

uniform vec4 color_a : source_color = vec4(0.09, 0.07, 0.26, 1.0);
uniform vec4 color_b : source_color = vec4(0.02, 0.30, 0.42, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.35, 0.95, 1.0);

void fragment() {
	float t = TIME * 0.12;
	vec2 uv = UV;
	float wave = sin((uv.x * 1.3 + uv.y) * 3.0 + t * 6.2831) * 0.5 + 0.5;
	vec3 c = mix(color_a.rgb, color_b.rgb, clamp(uv.y * 0.75 + wave * 0.25, 0.0, 1.0));
	vec2 p1 = vec2(0.5 + 0.35 * sin(t * 2.1), 0.3 + 0.15 * cos(t * 1.7));
	vec2 p2 = vec2(0.5 + 0.30 * cos(t * 1.3), 0.75 + 0.12 * sin(t * 2.3));
	c += glow.rgb * 0.18 * smoothstep(0.55, 0.0, distance(uv, p1));
	c += vec3(0.1, 0.6, 0.7) * 0.12 * smoothstep(0.5, 0.0, distance(uv, p2));
	// hafif vinyet
	c *= 1.0 - 0.35 * pow(distance(uv, vec2(0.5)), 2.0);
	COLOR = vec4(c, 1.0);
}
