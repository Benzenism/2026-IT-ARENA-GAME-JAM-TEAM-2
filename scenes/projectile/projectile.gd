class_name FanProjectile
extends Area2D

@export var speed: float = 260.0
@export var damage: int = 1
@export var lifetime: float = 4.8

var team_id: int = 1
var direction := Vector2.RIGHT
var arena_rect := Rect2(0, 0, 1280, 720)
var consumed: bool = false
var age: float = 0.0
var spawn_sequence: int = 0


func _ready() -> void:
	add_to_group("projectiles")
	direction = direction.normalized()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if consumed:
		return
	age += delta
	global_position += direction * speed * delta
	if age >= lifetime or not arena_rect.grow(28).has_point(global_position):
		consumed = true
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if consumed or not body.has_method("take_damage") or body.get("team_id") == team_id:
		return
	if body.has_method("is_combat_active") and not body.is_combat_active():
		return
	if body.has_method("is_damageable") and not body.is_damageable():
		return
	# If both shapes touch the same bullet, the defending fan gets the hit.
	if body.is_in_group("idols"):
		var guard := _overlapping_guard(body)
		if guard != null:
			body = guard
	consumed = true
	body.take_damage(damage)
	queue_free()


func _overlapping_guard(idol: Node2D) -> Fan:
	var collision := $CollisionShape2D as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 2
	var nearest: Fan
	var nearest_distance := INF
	for result in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var guard := result.collider as Fan
		if guard == null or not guard.is_in_group("projectile_guards") \
				or guard.team_id != idol.get("team_id") or not guard.is_combat_active():
			continue
		var distance := global_position.distance_squared_to(guard.global_position)
		if distance < nearest_distance:
			nearest = guard
			nearest_distance = distance
	return nearest
