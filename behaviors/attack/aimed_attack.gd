extends FanAttack
## Aim at the current target position; bullets do not home after firing.


func fire(fan: Fan) -> void:
	if fan.has_active_target():
		fan.shoot(fan.global_position.direction_to(fan.enemy_player.global_position))
	else:
		fan.shoot(fan.forward_dir())
