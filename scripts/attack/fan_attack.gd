class_name FanAttack
extends Node

@export_range(1, 4) var burst_count: int = 1
@export_range(0.05, 0.5, 0.01) var burst_interval: float = 0.12

const MUZZLE_DURATION := 0.16

## Each instance locks its own shot directions at the beginning of the warning.
var prepared_directions: Array[Vector2] = []
var _burst_directions: Array[Vector2] = []
var _bursts_remaining := 0
var _burst_team_id := 0
var _burst_timer: Timer
var _muzzle_remaining := 0.0


func _ready() -> void:
	_burst_timer = Timer.new()
	_burst_timer.one_shot = true
	_burst_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_burst_timer.timeout.connect(_on_burst_timeout)
	add_child(_burst_timer)


func _process(delta: float) -> void:
	if _muzzle_remaining > 0.0:
		_muzzle_remaining = maxf(0.0, _muzzle_remaining - delta)
		(get_parent() as Fan).queue_redraw()


func is_enabled() -> bool:
	return true


func prepare(_fan: Fan) -> void:
	prepared_directions.clear()


func fire(fan: Fan) -> void:
	cancel_burst()
	if not fan.is_combat_active():
		return
	_burst_directions = prepared_directions.duplicate()
	_burst_team_id = fan.team_id
	_bursts_remaining = maxi(1, burst_count) - 1
	_fire_volley(fan)
	if _bursts_remaining > 0:
		_burst_timer.start(maxf(0.05, burst_interval))


func is_bursting() -> bool:
	return _bursts_remaining > 0


func cancel_burst() -> void:
	_bursts_remaining = 0
	_muzzle_remaining = 0.0
	if _burst_timer != null:
		_burst_timer.stop()


func _on_burst_timeout() -> void:
	var fan := get_parent() as Fan
	if not fan.is_combat_active() or fan.team_id != _burst_team_id or fan.is_charging:
		cancel_burst()
		return
	_bursts_remaining -= 1
	_fire_volley(fan)
	if _bursts_remaining > 0:
		_burst_timer.start(maxf(0.05, burst_interval))


func _fire_volley(fan: Fan) -> void:
	for direction in _burst_directions:
		fan.shoot(direction)
	_muzzle_remaining = MUZZLE_DURATION
	fan.queue_redraw()


## Attack components may draw additional warning and short-lived impact effects.
func draw_telegraph(_fan: Fan) -> void:
	pass


func draw_effect(fan: Fan) -> void:
	if _muzzle_remaining <= 0.0:
		return
	var progress := 1.0 - _muzzle_remaining / MUZZLE_DURATION
	var color := Color("0c56f6") if fan.team_id == 1 else Color("e845e0")
	for direction in _burst_directions:
		var origin := direction.normalized() * 23.0
		fan.draw_circle(origin, 10.0, Color(color, 0.2 * (1.0 - progress)))
		fan.draw_arc(origin, 4.0 + progress * 12.0, 0.0, TAU, 12,
			Color(color.lerp(Color.WHITE, 0.65), 1.0 - progress), 1.8, true)
