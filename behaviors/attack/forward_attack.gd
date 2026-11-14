extends FanAttack


func fire(fan: Fan) -> void:
	fan.shoot(fan.forward_dir())
