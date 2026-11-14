class_name FanAttack
extends Node


## Each instance locks its own shot directions at the beginning of the warning.
var prepared_directions: Array[Vector2] = []


func prepare(_fan: Fan) -> void:
	prepared_directions.clear()


func fire(fan: Fan) -> void:
	for direction in prepared_directions:
		fan.shoot(direction)


## Attack components may draw additional warning and short-lived impact effects.
func draw_telegraph(_fan: Fan) -> void:
	pass


func draw_effect(_fan: Fan) -> void:
	pass
