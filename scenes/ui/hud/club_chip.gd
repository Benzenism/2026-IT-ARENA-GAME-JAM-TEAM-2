@tool
class_name ClubChip
extends Control
## Figma "HUD/Club Chip". 팬클럽 스프라이트가 있으면 팀 색 테두리 + 글로우,
## 없으면 점선 빈 슬롯(상대가 보유 중인 슬롯)으로 그린다.

const BG_COLOR := Color("2a1b45")
const EMPTY_FILL := Color(1, 1, 1, 0.04)
const EMPTY_LINE := Color(1, 1, 1, 0.35)

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var accent: Color = Color("4c8dff"):
	set(value):
		accent = value
		queue_redraw()
@export var corner_radius: int = 12
@export var border_width: int = 3
@export var glow_size: int = 8
@export var glow_alpha: float = 0.55


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if texture == null:
		var fill := StyleBoxFlat.new()
		fill.bg_color = EMPTY_FILL
		fill.set_corner_radius_all(corner_radius)
		draw_style_box(fill, rect)
		_draw_dashed_round_rect(rect.grow(-0.75), corner_radius, EMPTY_LINE, 1.5, 5.0, 4.0)
		return

	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = accent
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner_radius)
	box.shadow_color = Color(accent, glow_alpha)
	box.shadow_size = glow_size
	draw_style_box(box, rect)

	# 스프라이트는 테두리 안쪽에 비율 유지로 맞춤
	var inner := rect.grow(-(border_width + 2))
	var tex_size := texture.get_size()
	var fit := minf(inner.size.x / tex_size.x, inner.size.y / tex_size.y)
	var draw_size := tex_size * fit
	draw_texture_rect(texture, Rect2(inner.get_center() - draw_size / 2.0, draw_size), false)


func _draw_dashed_round_rect(rect: Rect2, radius: float, color: Color, width: float,
		dash: float, gap: float) -> void:
	var points := _round_rect_points(rect, minf(radius, minf(rect.size.x, rect.size.y) / 2.0))
	var on := true
	var remaining := dash
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var seg_len := a.distance_to(b)
		var t := 0.0
		while t < seg_len:
			var step := minf(remaining, seg_len - t)
			if on:
				draw_line(a.lerp(b, t / seg_len), a.lerp(b, (t + step) / seg_len), color, width, true)
			t += step
			remaining -= step
			if remaining <= 0.0:
				on = not on
				remaining = dash if on else gap


func _round_rect_points(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI / 2.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI / 2.0],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for c in corners:
		for s in range(7):
			var angle: float = c[1] + (PI / 2.0) * s / 6.0
			pts.append(c[0] + Vector2(cos(angle), sin(angle)) * r)
	return pts
