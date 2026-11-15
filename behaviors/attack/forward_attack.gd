extends FanAttack

@export_range(0.0, 64.0, 1.0) var triangle_depth: float = 24.0
@export_range(0.0, 48.0, 1.0) var triangle_half_width: float = 16.0


func prepare(fan: Fan) -> void:
	prepared_directions = [fan.forward_dir()]


func _fire_volley(fan: Fan) -> void:
	for direction in _burst_directions:
		var aim := direction.normalized()
		var side := aim.orthogonal() * triangle_half_width
		fan.shoot(aim, aim * triangle_depth)
		fan.shoot(aim, side)
		fan.shoot(aim, -side)
	_muzzle_remaining = MUZZLE_DURATION
	fan.queue_redraw()
