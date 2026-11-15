shader_type canvas_item;
// 글자에 그라디언트 색 (Mii 로고, VICTORY). 흰색으로 그려지는 글자 본체만 칠하고
// 그림자/외곽선(흰색이 아닌 색)은 그대로 둔다.

uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0);
uniform vec4 color_c : source_color = vec4(1.0);
uniform float mid = 0.5;
uniform bool vertical = false;
uniform vec2 box_size = vec2(100.0, 100.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * COLOR;
	float is_body = step(0.98, min(COLOR.r, min(COLOR.g, COLOR.b)));
	float t = clamp(vertical ? local_pos.y / box_size.y : local_pos.x / box_size.x, 0.0, 1.0);
	vec4 grad = t < mid ? mix(color_a, color_b, t / mid) : mix(color_b, color_c, (t - mid) / (1.0 - mid));
	COLOR = mix(base, vec4(grad.rgb, base.a), is_body);
}
