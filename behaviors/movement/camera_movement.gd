extends FanMovement

const SAFE_ZONE = preload("res://scripts/fan/safe_zone_geometry.gd")

## Wait ten seconds, then move toward a random nearby position.
@export var move_interval: float = 10.0
@export var move_radius: float = 180.0
@export var stopping_distance: float = 8.0
@export var minimum_spacing: float = 120.0
@export_range(0.0, 1.0, 0.05) var forward_move_chance: float = 1.0
@export_range(0.0, 1.0, 0.05) var enemy_side_forward_move_chance: float = 0.3

const TARGET_ATTEMPTS := 64
const RETRY_INTERVAL := 1.0

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
	var neighbors := _other_camera_fans(fan)
	var zones: Array[CollisionShape2D] = SAFE_ZONE.zones_in_world(fan)
	var forward_chance := _forward_chance(fan)
	for _attempt in TARGET_ATTEMPTS:
		var angle := randf_range(-PI * 0.5, PI * 0.5)
		var offset := Vector2.from_angle(angle) * randf_range(radius * 0.5, radius)
		var direction := 1.0 if randf() < forward_chance else -1.0
		offset.x *= fan.forward_dir().x * direction
		var candidate := (fan.global_position + offset).clamp(bounds.position, bounds.end)
		if _is_target_clear(candidate, neighbors) \
				and SAFE_ZONE.is_clear(candidate, maxf(1.0, fan.club.hitbox_radius), 8.0, zones) \
				and SAFE_ZONE.path_is_clear(fan.global_position, candidate,
					maxf(1.0, fan.club.hitbox_radius), 8.0, zones):
			target_position = candidate
			elapsed = 0.0
			return
	# Do not select an overlapping destination when the neighborhood is crowded.
	target_position = fan.global_position
	elapsed = maxf(0.0, move_interval - RETRY_INTERVAL)


func _forward_chance(fan: Fan) -> float:
	var progress := clampf((fan.global_position.x - fan.arena_rect.position.x) \
		/ maxf(0.001, fan.arena_rect.size.x), 0.0, 1.0)
	if fan.forward_dir().x < 0.0:
		progress = 1.0 - progress
	return lerpf(clampf(forward_move_chance, 0.0, 1.0),
		clampf(enemy_side_forward_move_chance, 0.0, 1.0), progress)


func _other_camera_fans(fan: Fan) -> Array[Fan]:
	var neighbors: Array[Fan] = []
	for node in get_tree().get_nodes_in_group("fans"):
		var other := node as Fan
		if other == null or other == fan or not other.is_combat_active() or other.club == null:
			continue
		if other.get_world_2d() != fan.get_world_2d():
			continue
		if other.club != fan.club and (fan.club.club_id == &"" or other.club.club_id != fan.club.club_id):
			continue
		neighbors.append(other)
	return neighbors


func _is_target_clear(candidate: Vector2, neighbors: Array[Fan]) -> bool:
	var spacing := maxf(0.0, minimum_spacing)
	var stop_margin := maxf(0.0, stopping_distance)
	for other in neighbors:
		if candidate.distance_to(other.global_position) < spacing + stop_margin:
			return false
		if is_instance_valid(other.movement) and other.movement.get_script() == get_script():
			var other_target: Vector2 = other.movement.get("target_position")
			var other_stop := maxf(0.0, float(other.movement.get("stopping_distance")))
			if candidate.distance_to(other_target) < spacing + stop_margin + other_stop:
				return false
	return true
