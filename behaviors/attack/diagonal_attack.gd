extends FanAttack


func prepare(_fan: Fan) -> void:
	prepared_directions = [
		Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()
	]
