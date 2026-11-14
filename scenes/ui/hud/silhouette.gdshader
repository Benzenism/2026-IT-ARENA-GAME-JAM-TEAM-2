shader_type canvas_item;
// 일러스트 모양 그대로 단색으로 칠함 (컷인 캐릭터 뒤의 팀 색 그림자)

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a * COLOR.a);
}
