shader_type canvas_item;
// 둥근 알약 버튼 (Figma UI/Title Button 등): 3색 가로 그라디언트 + 테두리 + 바깥 글로우 + 아래 그림자.
// ColorRect 크기 = 버튼 크기 + pad*2 (글로우/그림자가 버튼 밖으로 그려질 공간).

uniform vec2 pill_size = vec2(460.0, 100.0);
uniform float pad = 40.0;
uniform vec4 color_a : source_color = vec4(0.298, 0.553, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.706, 0.549, 1.0, 1.0);
uniform vec4 color_c : source_color = vec4(1.0, 0.373, 0.659, 1.0);
uniform vec4 border_color : source_color = vec4(1.0);
uniform float border_width = 4.0;
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float glow_size = 0.0;
uniform vec4 drop_color : source_color = vec4(0.0);
uniform float drop_offset = 0.0;

float pill_sdf(vec2 p, vec2 half_size) {
	float r = half_size.y;
	vec2 q = abs(p) - (half_size - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	vec3 c = (top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	vec2 full = pill_size + vec2(pad * 2.0);
	vec2 p = UV * full - full * 0.5;
	vec2 half_size = pill_size * 0.5;
	float d = pill_sdf(p, half_size);
	float aa = 1.0;

	vec4 col = vec4(0.0);
	if (drop_color.a > 0.0) {
		float dd = pill_sdf(p - vec2(0.0, drop_offset), half_size);
		col = over(vec4(drop_color.rgb, drop_color.a * (1.0 - smoothstep(-aa, aa, dd))), col);
	}
	if (glow_color.a > 0.0 && glow_size > 0.0) {
		float g = 1.0 - smoothstep(0.0, glow_size, d);
		col = over(vec4(glow_color.rgb, glow_color.a * g * g), col);
	}
	float t = clamp(p.x / pill_size.x + 0.5, 0.0, 1.0);
	vec4 fill = t < 0.5 ? mix(color_a, color_b, t * 2.0) : mix(color_b, color_c, (t - 0.5) * 2.0);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float border = smoothstep(-border_width - aa, -border_width + aa, d);
	vec4 body = mix(fill, border_color, border_width > 0.0 ? border : 0.0);
	col = over(vec4(body.rgb, body.a * inside), col);
	COLOR = col;
}
