class_name FanAbility
extends Node
## Optional extension point. Neither of the two initial clubs has an ability.

var fan: Fan


func setup(owner_fan: Fan) -> void:
	fan = owner_fan
