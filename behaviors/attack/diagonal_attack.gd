extends FanAttack


func fire(fan: Fan) -> void:
	for direction in [
		Vector2(1, 1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(-1, -1)
	]:
		fan.shoot(direction)
