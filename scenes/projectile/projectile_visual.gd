extends Node2D
## Luminous shots with tapered trails; sine shots trace their recent path.

const PINK := Color("e845e0")
const BLUE := Color("0c56f6")
const TAIL_LENGTH := 44.0
const WAVE_TAIL_LENGTH := 56.0
const WAVE_TAIL_SEGMENTS := 12

var color := Color.WHITE
var _shot: FanProjectile


func _ready() -> void:
	_shot = get_parent() as FanProjectile
	color = BLUE if _shot.team_id == 1 else PINK
	rotation = _shot.direction.angle()
	set_physics_process(_shot.wave_amplitude > 0.0)


func _physics_process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var light := color.lerp(Color.WHITE, 0.4)
	# Straight shots stay cached; only sine tails redraw at the physics rate.
	draw_circle(Vector2.ZERO, 18.0, Color(color, 0.035))
	draw_circle(Vector2.ZERO, 12.0, Color(color, 0.08))
	if _shot.wave_amplitude > 0.0:
		_draw_wave_tail(light)
	else:
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
	var body := PackedVector2Array([Vector2(7, 0), Vector2(2, -4.5), Vector2(-4, -4),
		Vector2(-6, 0), Vector2(-4, 4), Vector2(2, 4.5), Vector2(7, 0)])
	draw_colored_polygon(body, color)
	draw_polyline(body, Color("20132b"), 1.4, true)
	draw_circle(Vector2(1, 0), 2.7, Color(1.0, 1.0, 1.0, 0.95))
	draw_set_transform(Vector2.ZERO)
	if _shot.wave_amplitude <= 0.0:
		var sparkle := Vector2(-TAIL_LENGTH * 0.65, 0)
		draw_line(sparkle + Vector2(0, -3), sparkle + Vector2(0, 3), Color(light, 0.65), 1.0, true)
		draw_line(sparkle + Vector2(-3, 0), sparkle + Vector2(3, 0), Color(light, 0.65), 1.0, true)


func _wave_tail_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _shot.speed <= 0.0 or _shot.age <= 0.0:
		return points
	var world_scale := maxf(0.001, global_transform.x.length())
	var length := minf(WAVE_TAIL_LENGTH * world_scale, _shot.speed * _shot.age)
	var world_to_local := global_transform.affine_inverse()
	var angular_frequency := TAU * _shot.wave_frequency
	var current_offset := sin(_shot.age * angular_frequency) * _shot.wave_amplitude
	for i in WAVE_TAIL_SEGMENTS + 1:
		var distance := length * float(i) / WAVE_TAIL_SEGMENTS
		var past_age := maxf(0.0, _shot.age - distance / _shot.speed)
		var past_offset := sin(past_age * angular_frequency) * _shot.wave_amplitude
		var past_position := _shot.global_position - _shot.direction * distance \
			+ _shot.direction.orthogonal() * (past_offset - current_offset)
		points.append(world_to_local * past_position)
	return points


func _draw_wave_tail(light: Color) -> void:
	var points := _wave_tail_points()
	if points.size() < 2 or points[0].distance_squared_to(points[-1]) < 0.01:
		return
	var glow_colors := PackedColorArray()
	var trail_colors := PackedColorArray()
	var core_colors := PackedColorArray()
	for i in points.size():
		var fade := 1.0 - float(i) / (points.size() - 1)
		glow_colors.append(Color(color, 0.2 * fade * fade))
		trail_colors.append(Color(light, 0.65 * fade))
		core_colors.append(Color(light, 0.7 * fade))
	draw_polyline_colors(points, glow_colors, 9.0, true)
	draw_polyline_colors(points, trail_colors, 3.5, true)
	draw_polyline_colors(points, core_colors, 1.0, true)
