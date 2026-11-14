extends FanMovement

@export var stopping_distance: float = 200.0
@export var resume_distance: float = 240.0
@export var max_chase_distance: float = 1000.0
@export var reacquire_distance: float = 900.0
@export var separation_radius: float = 112.0
@export var separation_strength: float = 1.5

var is_approaching := true
var target_in_range := true


func get_direction(fan: Fan) -> Vector2:
	var desired := fan.forward_dir()
	if fan.has_active_target():
		var offset := fan.enemy_player.global_position - fan.global_position
		var distance := offset.length()
		var chase_limit := maxf(0.0, max_chase_distance)
		if distance > chase_limit:
			target_in_range = false
		elif distance <= clampf(reacquire_distance, 0.0, chase_limit):
			target_in_range = true
		if not target_in_range or distance <= stopping_distance:
			is_approaching = false
		elif distance >= maxf(stopping_distance, resume_distance):
			is_approaching = true
		desired = offset.normalized() if is_approaching else Vector2.ZERO
	return (desired + _separation(fan) * maxf(0.0, separation_strength)).limit_length(1.0)


func _separation(fan: Fan) -> Vector2:
	if separation_radius <= 0.0:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for neighbor in get_tree().get_nodes_in_group("fans"):
		if not neighbor is Fan or neighbor == fan or not is_instance_valid(neighbor):
			continue
		if neighbor.is_despawning or neighbor.has_died or neighbor.club == null:
			continue
		if neighbor.get_world_2d() != fan.get_world_2d():
			continue
		# Variants with the same club_id also keep their distance, across both teams.
		if neighbor.club != fan.club and (fan.club.club_id == &"" or neighbor.club.club_id != fan.club.club_id):
			continue
		var away: Vector2 = fan.global_position - neighbor.global_position
		var distance := away.length()
		if distance >= separation_radius:
			continue
		if distance < 0.001:
			# Identical positions need opposite, deterministic directions to separate.
			away = Vector2.LEFT if fan.get_instance_id() < neighbor.get_instance_id() else Vector2.RIGHT
		else:
			away /= distance
		push += away * (1.0 - distance / separation_radius)
	push = push.limit_length(1.0)
	# Separation alone should not push a fan out of the arena at a spawn edge.
	var safe_bounds := fan.arena_rect.grow(-20.0)
	if (fan.global_position.x <= safe_bounds.position.x and push.x < 0.0) \
			or (fan.global_position.x >= safe_bounds.end.x and push.x > 0.0):
		push.x = 0.0
	if (fan.global_position.y <= safe_bounds.position.y and push.y < 0.0) \
			or (fan.global_position.y >= safe_bounds.end.y and push.y > 0.0):
		push.y = 0.0
	return push
