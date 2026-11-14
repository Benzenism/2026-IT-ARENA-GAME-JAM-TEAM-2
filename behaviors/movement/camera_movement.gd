extends FanMovement

@export var move_interval: float = 10.0
@export var move_radius: float = 180.0
@export var stopping_distance: float = 8.0

var target_position := Vector2.ZERO
var elapsed: float = 10.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= move_interval:
		var fan := get_parent() as Fan
		if is_instance_valid(fan):
			_choose_target(fan)


func get_direction(fan: Fan) -> Vector2:
	if target_position == Vector2.ZERO:
		_choose_target(fan)
	if fan.global_position.distance_to(target_position) <= stopping_distance:
		return Vector2.ZERO
	return fan.global_position.direction_to(target_position)


func _choose_target(fan: Fan) -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(move_radius * 0.5, move_radius)
	var bounds := fan.arena_rect.grow(-32.0)
	target_position = Vector2(
		clampf(fan.global_position.x + offset.x, bounds.position.x, bounds.end.x),
		clampf(fan.global_position.y + offset.y, bounds.position.y, bounds.end.y)
	)
	elapsed = 0.0
