shader_type canvas_item;
// HP 0(리스폰 대기) 동안 초상화를 흑백으로

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(l), c.a);
}
