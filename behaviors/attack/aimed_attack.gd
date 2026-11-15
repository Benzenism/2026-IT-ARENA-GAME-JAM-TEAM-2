extends FanAttack
## Lock the target position when the warning starts; shots never home.

@export_range(0.0, 10.0, 0.5) var spread_degrees: float = 4.0


func prepare(fan: Fan) -> void:
	var aim := fan.forward_dir()
	if fan.has_active_target():
		var direction := fan.global_position.direction_to(fan.enemy_player.global_position)
		if not direction.is_zero_approx():
			aim = direction
	var spread := deg_to_rad(spread_degrees)
	prepared_directions = [aim.rotated(-spread), aim, aim.rotated(spread)]
