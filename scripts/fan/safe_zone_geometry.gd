extends RefCounted
## Geometry of the circular stage safe zones, in world coordinates.


static func collision_shape(zone: Node2D) -> CollisionShape2D:
	if not is_instance_valid(zone) or not zone.is_inside_tree() or zone.is_queued_for_deletion():
		return null
	var collision := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.disabled or not collision.shape is CircleShape2D:
		return null
	return collision


static func radius(collision: CollisionShape2D) -> float:
	var circle := collision.shape as CircleShape2D
	var scale := collision.global_transform.get_scale()
	return circle.radius * maxf(absf(scale.x), absf(scale.y))


static func zones_in_world(context: Node2D) -> Array[CollisionShape2D]:
	var zones: Array[CollisionShape2D] = []
	if not is_instance_valid(context) or not context.is_inside_tree():
		return zones
	for node in context.get_tree().get_nodes_in_group("stage_safe_zones"):
		var zone := node as Node2D
		if zone == null or not zone.is_inside_tree() or zone.get_world_2d() != context.get_world_2d():
			continue
		var collision := collision_shape(zone)
		if collision != null:
			zones.append(collision)
	return zones


static func is_clear(point: Vector2, body_radius: float, margin: float,
		zones: Array[CollisionShape2D]) -> bool:
	for collision in zones:
		if not is_instance_valid(collision):
			continue
		var clearance := radius(collision) + body_radius + margin
		if point.distance_squared_to(collision.global_position) < clearance * clearance:
			return false
	return true
