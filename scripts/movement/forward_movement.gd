extends FanMovement


func get_direction(fan: Fan) -> Vector2:
	return fan.forward_dir()
