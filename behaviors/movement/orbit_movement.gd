extends FanMovement
## Orbit the owning player while following their movement without teleporting.

@export var orbit_radius: float = 140.0
@export var angular_speed: float = 0.65
@export var follow_gain: float = 8.0

var angle: float = 0.0


func _ready() -> void:
	var fan := get_parent() as Fan
	# Different initial phases help multiple guards cover different sides.
	angle = TAU * float(fan.get_instance_id() % 32) / 32.0


func _physics_process(delta: float) -> void:
	var fan := get_parent() as Fan
	if not is_instance_valid(fan) or fan.is_despawning or not _has_ally(fan):
		return
	angle = fposmod(angle + angular_speed * delta, TAU)


func get_direction(fan: Fan) -> Vector2:
	if not _has_ally(fan) or fan.club.move_speed <= 0.0:
		return Vector2.ZERO
	var radial := Vector2.from_angle(angle)
	var raw_position := fan.ally_player.global_position + radial * orbit_radius
	# Keep guards in the arena when the ideal orbit crosses an edge.
	var margin := Vector2.ONE * 30.0
	var desired_position := raw_position.clamp(fan.arena_rect.position + margin, fan.arena_rect.end - margin)
	var tangent_velocity := radial.orthogonal() * orbit_radius * angular_speed
	var feed_forward := fan.ally_player.velocity + tangent_velocity
	if not is_equal_approx(raw_position.x, desired_position.x):
		feed_forward.x = 0.0
	if not is_equal_approx(raw_position.y, desired_position.y):
		feed_forward.y = 0.0
	var correction := (desired_position - fan.global_position) * follow_gain
	var desired_velocity := feed_forward + correction
	return (desired_velocity / fan.club.move_speed).limit_length(1.0)


func _has_ally(fan: Fan) -> bool:
	return is_instance_valid(fan.ally_player) and fan.ally_player.is_inside_tree() \
		and (not fan.ally_player.has_method("is_combat_active") or fan.ally_player.is_combat_active())
