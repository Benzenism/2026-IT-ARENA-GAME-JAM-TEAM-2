extends FanAttack
## Lock the target position when the warning starts; shots never home.


func prepare(fan: Fan) -> void:
	if fan.has_active_target():
		var direction := fan.global_position.direction_to(fan.enemy_player.global_position)
		prepared_directions = [fan.forward_dir() if direction.is_zero_approx() else direction]
	else:
		prepared_directions = [fan.forward_dir()]
