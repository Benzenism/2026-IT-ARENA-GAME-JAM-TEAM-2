class_name ProjectileSpawner
extends Node2D
## The spawner owns bullets, so a fan's death cannot delete its shots.

const MAX_PROJECTILES := 80
@export_range(1, 80) var projectile_limit: int = MAX_PROJECTILES

static var next_spawn_sequence: int = 0
var active_projectiles: Array[FanProjectile] = []


func request_shot(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float, speed: float) -> void:
	# Damage signals may arrive while physics overlaps are being flushed.
	_spawn.call_deferred(scene, origin, direction, team_id, bounds, lifetime, speed)


func _spawn(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float, speed: float) -> void:
	if not is_inside_tree() or scene == null or _is_near_idol(origin):
		return
	var limit := clampi(projectile_limit, 0, MAX_PROJECTILES)
	if limit == 0:
		return
	var world_projectiles: Array[FanProjectile] = []
	for candidate in get_tree().get_nodes_in_group("projectiles"):
		if candidate is FanProjectile and is_instance_valid(candidate) \
				and not candidate.consumed and not candidate.is_queued_for_deletion() \
				and candidate.get_world_2d() == get_world_2d():
			world_projectiles.append(candidate)
	while world_projectiles.size() >= limit:
		var oldest := world_projectiles[0]
		for candidate in world_projectiles:
			if candidate.spawn_sequence < oldest.spawn_sequence:
				oldest = candidate
		world_projectiles.erase(oldest)
		# A queued projectile must not damage anything before the frame ends.
		oldest.consumed = true
		oldest.queue_free()
	var projectile := scene.instantiate() as FanProjectile
	assert(projectile != null, "Projectile scene must extend FanProjectile.")
	projectile.team_id = team_id
	projectile.direction = direction
	projectile.arena_rect = bounds
	projectile.lifetime = lifetime
	projectile.speed = speed
	next_spawn_sequence += 1
	projectile.spawn_sequence = next_spawn_sequence
	projectile.position = to_local(origin)
	projectile.tree_exited.connect(_on_projectile_tree_exited.bind(projectile))
	add_child(projectile)
	active_projectiles.append(projectile)


func _is_near_idol(origin: Vector2) -> bool:
	for idol: Node2D in get_tree().get_nodes_in_group("idols"):
		if is_instance_valid(idol) and idol.get_world_2d() == get_world_2d() \
				and origin.distance_to(idol.global_position) < 80.0:
			return true
	return false


func _on_projectile_tree_exited(projectile: FanProjectile) -> void:
	active_projectiles.erase(projectile)
