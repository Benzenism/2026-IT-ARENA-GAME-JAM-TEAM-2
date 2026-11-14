class_name ProjectileSpawner
extends Node2D
## The spawner owns bullets, so a fan's death cannot delete its shots.

@export var projectile_limit: int = 600


func request_shot(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2) -> void:
	# Damage signals may arrive while physics overlaps are being flushed.
	_spawn.call_deferred(scene, origin, direction, team_id, bounds)


func _spawn(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2) -> void:
	if not is_inside_tree() or get_child_count() >= projectile_limit or scene == null:
		return
	var projectile := scene.instantiate() as FanProjectile
	assert(projectile != null, "Projectile scene must extend FanProjectile.")
	projectile.team_id = team_id
	projectile.direction = direction
	projectile.arena_rect = bounds
	projectile.position = to_local(origin)
	add_child(projectile)
