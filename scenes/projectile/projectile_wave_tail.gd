extends Node2D
## Only the trail is redrawn; the projectile body remains cached.

const LENGTH := 56.0
const SEGMENTS := 12

var _shot: FanProjectile
var _points := PackedVector2Array()
var _glow_colors := PackedColorArray()
var _trail_colors := PackedColorArray()
var _core_colors := PackedColorArray()


func _ready() -> void:
	var visual := get_parent()
	_shot = visual.get_parent() as FanProjectile
	var color: Color = visual.color
	var light := color.lerp(Color.WHITE, 0.4)
	_points.resize(SEGMENTS + 1)
	for i in SEGMENTS + 1:
		var fade := 1.0 - float(i) / SEGMENTS
		_glow_colors.append(Color(color, 0.2 * fade * fade))
		_trail_colors.append(Color(light, 0.65 * fade))
		_core_colors.append(Color(light, 0.7 * fade))


func _physics_process(_delta: float) -> void:
	queue_redraw()


func _wave_tail_points() -> PackedVector2Array:
	if _shot.speed <= 0.0 or _shot.age <= 0.0:
		return PackedVector2Array()
	var world_scale := maxf(0.001, global_transform.x.length())
	var length := minf(LENGTH * world_scale, _shot.speed * _shot.age)
	var world_to_local := global_transform.affine_inverse()
	var angular_frequency := TAU * _shot.wave_frequency
	var phase := _shot.age * angular_frequency
	var amplitude := _shot.wave_amplitude
	var current_offset := sin(phase) * amplitude
	var distance_step := length / SEGMENTS
	var phase_step := distance_step * angular_frequency / _shot.speed
	var direction := _shot.direction
	var sideways := direction.orthogonal()
	var origin := world_to_local * _shot.global_position
	var local_forward := world_to_local.x * direction.x + world_to_local.y * direction.y
	var local_sideways := world_to_local.x * sideways.x + world_to_local.y * sideways.y
	for i in SEGMENTS + 1:
		var distance := distance_step * i
		var offset := sin(maxf(0.0, phase - phase_step * i)) * amplitude - current_offset
		_points[i] = origin - local_forward * distance + local_sideways * offset
	return _points


func _draw() -> void:
	var points := _wave_tail_points()
	if points.size() < 2 or points[0].distance_squared_to(points[-1]) < 0.01:
		return
	draw_polyline_colors(points, _glow_colors, 9.0, true)
	draw_polyline_colors(points, _trail_colors, 3.5, true)
	draw_polyline_colors(points, _core_colors, 1.0, true)
