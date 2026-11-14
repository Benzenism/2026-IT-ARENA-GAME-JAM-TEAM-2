extends Node2D
## A small luminous shot with a short, tapered trail in the direction of travel.

const PINK := Color("e845e0")
const BLUE := Color("0c56f6")
const TAIL_LENGTH := 30.0

var color := Color.WHITE


func _ready() -> void:
	var shot := get_parent() as FanProjectile
	color = PINK if shot.team_id == 1 else BLUE
	rotation = shot.direction.angle()


func _draw() -> void:
	var light := color.lerp(Color.WHITE, 0.4)
	# The cached drawing is shared by each frame; the material handles the pulse.
	draw_circle(Vector2.ZERO, 18.0, Color(color, 0.035))
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.08))
	var outer_tail := PackedVector2Array([Vector2(-TAIL_LENGTH, 0), Vector2(-4, -5),
		Vector2(4, 0), Vector2(-4, 5)])
	draw_colored_polygon(outer_tail, Color(color, 0.28))
	var inner_tail := PackedVector2Array([Vector2(-TAIL_LENGTH * 0.7, 0), Vector2(-3, -2.4),
		Vector2(3, 0), Vector2(-3, 2.4)])
	draw_colored_polygon(inner_tail, Color(light, 0.7))
	var body := PackedVector2Array([Vector2(7, 0), Vector2(2, -4.5), Vector2(-4, -4),
		Vector2(-6, 0), Vector2(-4, 4), Vector2(2, 4.5), Vector2(7, 0)])
	draw_colored_polygon(body, color)
	draw_polyline(body, Color("20132b"), 1.4, true)
	draw_circle(Vector2(1, 0), 2.7, Color(1.0, 1.0, 1.0, 0.95))
	var sparkle := Vector2(-TAIL_LENGTH * 0.65, 0)
	draw_line(sparkle + Vector2(0, -3), sparkle + Vector2(0, 3), Color(light, 0.65), 1.0, true)
