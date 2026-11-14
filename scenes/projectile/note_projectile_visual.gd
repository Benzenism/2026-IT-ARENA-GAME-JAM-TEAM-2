extends Node2D
## A team-colored musical note, drawn once and pulsed by the shared glow shader.

const PINK := Color("e845e0")
const BLUE := Color("0c56f6")
const NOTE_SHAPE := [
	Vector2(-8, 4), Vector2(-6, 1), Vector2(-2, 0), Vector2(1, 0),
	Vector2(1, -10), Vector2(10, -7), Vector2(10, -3), Vector2(4, -5),
	Vector2(4, 4), Vector2(3, 7), Vector2(-1, 9), Vector2(-6, 9),
	Vector2(-9, 7), Vector2(-8, 4)
]

var color := Color.WHITE


func _ready() -> void:
	var shot := get_parent() as FanProjectile
	color = BLUE if shot.team_id == 1 else PINK
	if shot.direction.y < 0.0:
		rotation = PI


func _draw() -> void:
	var light := color.lerp(Color.WHITE, 0.5)
	var outline := PackedVector2Array(NOTE_SHAPE)
	draw_circle(Vector2.ZERO, 17.0, Color(color, 0.04))
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.1))
	draw_colored_polygon(outline, color)
	draw_polyline(outline, Color("20132b"), 1.4, true)
	draw_line(Vector2(2, -8), Vector2(2, 3), Color(light, 0.9), 1.3, true)
	draw_line(Vector2(-5, 4), Vector2(-2, 3), Color(light, 0.9), 1.5, true)
