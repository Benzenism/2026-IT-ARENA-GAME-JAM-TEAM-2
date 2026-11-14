shader_type canvas_item;
// 멘탈 다운 상태 초상화용 흑백 처리

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(l), c.a);
}
