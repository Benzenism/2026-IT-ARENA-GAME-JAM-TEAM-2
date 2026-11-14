extends FanMovement

## Wait ten seconds, then move toward a random nearby position.
@export var move_interval: float = 10.0
@export var move_radius: float = 180.0
@export var stopping_distance: float = 8.0

var target_position := Vector2.ZERO
var elapsed: float = 0.0


func _ready() -> void:
	var fan := get_parent() as Fan
	target_position = fan.global_position


func _physics_process(delta: float) -> void:
	var fan := get_parent() as Fan
	if not is_instance_valid(fan) or fan.is_despawning:
		return
	elapsed += delta
	if elapsed >= maxf(0.05, move_interval):
		_choose_target(fan)


func get_direction(fan: Fan) -> Vector2:
	if fan.global_position.distance_to(target_position) <= stopping_distance:
		return Vector2.ZERO
	return fan.global_position.direction_to(target_position)


func _choose_target(fan: Fan) -> void:
	var bounds := fan.arena_rect.grow(-32.0)
	var radius := maxf(0.0, move_radius)
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(radius * 0.5, radius)
	target_position = (fan.global_position + offset).clamp(bounds.position, bounds.end)
	elapsed = 0.0
