extends FanMovement

@export var stopping_distance: float = 48.0


func get_direction(fan: Fan) -> Vector2:
	if not fan.has_active_target():
		return fan.forward_dir()
	var offset := fan.enemy_player.global_position - fan.global_position
	if offset.length_squared() <= stopping_distance * stopping_distance:
		return Vector2.ZERO
	return offset.normalized()
