class_name ProjectileSpawner
extends Node2D
## The spawner owns bullets, so a fan's death cannot delete its shots.

@export var projectile_limit: int = 200

var active_projectiles: Array[FanProjectile] = []


func request_shot(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float) -> void:
	# Damage signals may arrive while physics overlaps are being flushed.
	_spawn.call_deferred(scene, origin, direction, team_id, bounds, lifetime)


func _spawn(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float) -> void:
	if not is_inside_tree() or scene == null or _is_near_idol(origin):
		return
	while active_projectiles.size() >= projectile_limit:
		var oldest: FanProjectile = active_projectiles.pop_front() as FanProjectile
		if is_instance_valid(oldest):
			oldest.queue_free()
	var projectile := scene.instantiate() as FanProjectile
	assert(projectile != null, "Projectile scene must extend FanProjectile.")
	projectile.team_id = team_id
	projectile.direction = direction
	projectile.arena_rect = bounds
	projectile.lifetime = lifetime
	projectile.position = to_local(origin)
	projectile.tree_exited.connect(_on_projectile_tree_exited.bind(projectile))
	add_child(projectile)
	active_projectiles.append(projectile)


func _is_near_idol(origin: Vector2) -> bool:
	for idol: Node2D in get_tree().get_nodes_in_group("idols"):
		if is_instance_valid(idol) and origin.distance_to(idol.global_position) < 80.0:
			return true
	return false


func _on_projectile_tree_exited(projectile: FanProjectile) -> void:
	active_projectiles.erase(projectile)
