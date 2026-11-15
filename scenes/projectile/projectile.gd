class_name FanProjectile
extends Area2D

const IMPACT_EFFECT = preload("res://scenes/projectile/projectile_impact.gd")

@export var speed: float = 260.0
@export var damage: int = 1
@export var lifetime: float = 4.8
@export_range(0.0, 24.0, 1.0) var wave_amplitude: float = 0.0
@export_range(0.1, 6.0, 0.1) var wave_frequency: float = 0.8

var team_id: int = 1
var direction := Vector2.RIGHT
var arena_rect := Rect2(0, 0, 1280, 720)
var consumed: bool = false
var age: float = 0.0
var spawn_sequence: int = 0
var _wave_offset: float = 0.0
var _safe_zone_query: PhysicsShapeQueryParameters2D


func _ready() -> void:
	add_to_group("projectiles")
	direction = direction.normalized()
	_safe_zone_query = PhysicsShapeQueryParameters2D.new()
	_safe_zone_query.shape = ($CollisionShape2D as CollisionShape2D).shape
	_safe_zone_query.collision_mask = 4
	_safe_zone_query.collide_with_bodies = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if consumed:
		return
	age += delta
	global_position += direction * speed * delta
	if wave_amplitude > 0.0:
		# Apply only the change in offset, keeping the original travel axis intact.
		var next_offset := sin(age * TAU * wave_frequency) * wave_amplitude
		global_position += direction.orthogonal() * (next_offset - _wave_offset)
		_wave_offset = next_offset
	if _inside_stage_safe_zone():
		consumed = true
		_show_impact()
		queue_free()
		return
	if age >= lifetime or not arena_rect.grow(28).has_point(global_position):
		consumed = true
		queue_free()


func _inside_stage_safe_zone() -> bool:
	var collision := $CollisionShape2D as CollisionShape2D
	_safe_zone_query.transform = collision.global_transform
	for result in get_world_2d().direct_space_state.intersect_shape(_safe_zone_query, 8):
		if result.collider.is_in_group("stage_safe_zones"):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if consumed:
		return
	if body.is_in_group("stage_safe_zones"):
		consumed = true
		_show_impact()
		queue_free()
		return
	if not body.has_method("take_damage") or body.get("team_id") == team_id:
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
	_show_impact()
	body.take_damage(damage)
	queue_free()


func _show_impact() -> void:
	var container := get_parent() as Node2D
	if not is_instance_valid(container):
		return
	var effect := IMPACT_EFFECT.new()
	effect.team_id = team_id
	effect.position = container.to_local(global_position)
	container.add_child.call_deferred(effect)


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
