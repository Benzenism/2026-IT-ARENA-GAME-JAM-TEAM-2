extends Node2D
## Luminous shots with tapered trails; sine shots trace their recent path.

const PINK := Color("e845e0")
const BLUE := Color("0c56f6")
const TAIL_LENGTH := 44.0
const WAVE_TAIL = preload("res://scenes/projectile/projectile_wave_tail.gd")

var color := Color.WHITE
var _shot: FanProjectile
var _body := PackedVector2Array([Vector2(7, 0), Vector2(2, -4.5), Vector2(-4, -4),
	Vector2(-6, 0), Vector2(-4, 4), Vector2(2, 4.5), Vector2(7, 0)])


func _ready() -> void:
	_shot = get_parent() as FanProjectile
	color = BLUE if _shot.team_id == 1 else PINK
	rotation = _shot.direction.angle()
	if _shot.wave_amplitude > 0.0:
		var tail := WAVE_TAIL.new()
		tail.name = "WaveTail"
		tail.show_behind_parent = true
		tail.use_parent_material = true
		add_child(tail)


func _draw() -> void:
	var light := color.lerp(Color.WHITE, 0.4)
	# The body stays cached; the separate sine tail updates at the physics rate.
	draw_circle(Vector2.ZERO, 18.0, Color(color, 0.035))
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.08))
	if _shot.wave_amplitude <= 0.0:
		var outer_tail := PackedVector2Array([Vector2(-TAIL_LENGTH, 0), Vector2(-10, -5),
			Vector2(4, 0), Vector2(-10, 5)])
		draw_colored_polygon(outer_tail, Color(color, 0.28))
		var inner_tail := PackedVector2Array([Vector2(-TAIL_LENGTH * 0.7, 0), Vector2(-3, -2.4),
			Vector2(3, 0), Vector2(-3, 2.4)])
		draw_colored_polygon(inner_tail, Color(light, 0.7))
		for side in [-1.0, 1.0]:
			draw_line(Vector2(-24, side * 5), Vector2(-10, side * 3),
				Color(light, 0.35), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 2.0)
	draw_colored_polygon(_body, color)
	draw_polyline(_body, Color("20132b"), 1.4, true)
	draw_circle(Vector2(1, 0), 2.7, Color(1.0, 1.0, 1.0, 0.95))
	draw_set_transform(Vector2.ZERO)
	if _shot.wave_amplitude <= 0.0:
		var sparkle := Vector2(-TAIL_LENGTH * 0.65, 0)
		draw_line(sparkle + Vector2(0, -3), sparkle + Vector2(0, 3), Color(light, 0.65), 1.0, true)
		draw_line(sparkle + Vector2(-3, 0), sparkle + Vector2(3, 0), Color(light, 0.65), 1.0, true)
