@tool
class_name Field
extends Node2D
## 큰 필드. 원점(0,0)을 중심으로 size 크기의 영역을 차지함.
## 배경과 격자를 그리고, 실행 시 가장자리에 보이지 않는 벽을 만들어 캐릭터가 밖으로 못 나가게 함.

const WALL_THICKNESS := 200.0

@export var size: Vector2 = Vector2(4000, 2400):
	set(value):
		size = value
		queue_redraw()
@export var cell_size: float = 200.0:
	set(value):
		cell_size = maxf(value, 8.0)
		queue_redraw()
@export var background_color: Color = Color(0.16, 0.2, 0.18)
@export var grid_color: Color = Color(1, 1, 1, 0.08)
@export var border_color: Color = Color(1, 1, 1, 0.6)


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_walls()


## 필드 영역 (전역 좌표). 카메라 limit 계산에 사용.
func get_field_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, background_color)

	var x := rect.position.x + cell_size
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), grid_color, 2.0)
		x += cell_size
	var y := rect.position.y + cell_size
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), grid_color, 2.0)
		y += cell_size

	draw_rect(rect, border_color, false, 8.0)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	var half := size / 2.0
	var t := WALL_THICKNESS
	# [중심 위치, 크기] — 필드 바깥쪽에 붙는 상/하/좌/우 벽
	var walls := [
		[Vector2(0, -half.y - t / 2), Vector2(size.x + t * 2, t)],
		[Vector2(0, half.y + t / 2), Vector2(size.x + t * 2, t)],
		[Vector2(-half.x - t / 2, 0), Vector2(t, size.y)],
		[Vector2(half.x + t / 2, 0), Vector2(t, size.y)],
	]
	for w in walls:
		var shape := RectangleShape2D.new()
		shape.size = w[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = w[0]
		body.add_child(col)
	add_child(body)
