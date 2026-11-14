extends FanAttack
## Passive fans never start an attack or warning timer.


func is_enabled() -> bool:
	return false
