shader_type canvas_item;
// Bazı mobil kameralar görüntüyü ayrı Y ve CbCr düzlemleri olarak verir (BT.601).

uniform sampler2D y_tex;
uniform sampler2D cbcr_tex;

void fragment() {
	float y = texture(y_tex, UV).r;
	vec2 cbcr = texture(cbcr_tex, UV).rg - vec2(0.5);
	vec3 rgb = vec3(
		y + 1.402 * cbcr.y,
		y - 0.344 * cbcr.x - 0.714 * cbcr.y,
		y + 1.772 * cbcr.x);
	COLOR = vec4(rgb, 1.0);
}
