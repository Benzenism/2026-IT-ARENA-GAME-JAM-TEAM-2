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
var _shot: FanProjectile


func _ready() -> void:
	_shot = get_parent() as FanProjectile
	color = BLUE if _shot.team_id == 1 else PINK
	if _shot.direction.y < 0.0:
		rotation = PI
	set_physics_process(_shot.speed > 0.0)


func _physics_process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var light := color.lerp(Color.WHITE, 0.5)
	var outline := PackedVector2Array(NOTE_SHAPE)
	draw_circle(Vector2.ZERO, 17.0, Color(color, 0.04))
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.1))
	_draw_echo(outline, 40.0, 0.45, Color(color, 0.1))
	_draw_echo(outline, 26.0, 0.65, Color(light, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 2.0)
	draw_colored_polygon(outline, color)
	draw_polyline(outline, Color("20132b"), 1.4, true)
	draw_line(Vector2(2, -8), Vector2(2, 3), Color(light, 0.9), 1.3, true)
	draw_line(Vector2(-5, 4), Vector2(-2, 3), Color(light, 0.9), 1.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_echo(outline: PackedVector2Array, distance: float, size: float, tint: Color) -> void:
	if _shot.speed <= 0.0:
		return
	var world_distance := distance * global_transform.y.length()
	var past_age := _shot.age - world_distance / _shot.speed
	if past_age < 0.0:
		return
	var frequency := TAU * _shot.wave_frequency
	var offset := (sin(past_age * frequency) - sin(_shot.age * frequency)) * _shot.wave_amplitude
	var past_position := _shot.global_position - _shot.direction * world_distance \
		+ _shot.direction.orthogonal() * offset
	draw_set_transform(to_local(past_position), 0.0, Vector2.ONE * size)
	draw_colored_polygon(outline, tint)
