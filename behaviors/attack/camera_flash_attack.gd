extends FanAttack
## A warned circular flash that damages and slows opposing idols.

@export var radius: float = 200.0
@export_range(0, 100) var damage: int = 1
@export_range(0.0, 1.0) var slow_multiplier: float = 0.5
@export var slow_duration: float = 1.0
@export_flags_2d_physics var target_mask: int = 1

const FLASH_DURATION := 0.2
const SAFE_ZONE = preload("res://scripts/fan/safe_zone_geometry.gd")
var flash_remaining: float = 0.0


func fire(fan: Fan) -> void:
	fan.play_shoot_sound()
	flash_remaining = FLASH_DURATION
	fan.queue_redraw()
	var circle := CircleShape2D.new()
	circle.radius = maxf(0.01, radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, fan.global_position)
	query.collision_mask = target_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var safe_zones: Array[CollisionShape2D] = SAFE_ZONE.zones_in_world(fan)
	for hit in fan.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var target := hit.collider as Node2D
		if not is_instance_valid(target) or not target.is_in_group("idols"):
			continue
		if target.get("team_id") == fan.team_id or not target.has_method("apply_slow"):
			continue
		target.apply_slow(slow_multiplier, slow_duration)
		if SAFE_ZONE.is_clear(target.global_position, 0.0, 0.0, safe_zones) \
				and target.has_method("take_damage") \
				and (not target.has_method("is_damageable") or target.is_damageable()):
			target.take_damage(damage)


func _process(delta: float) -> void:
	if flash_remaining <= 0.0:
		return
	flash_remaining = maxf(0.0, flash_remaining - delta)
	var fan := get_parent() as Fan
	if is_instance_valid(fan):
		fan.queue_redraw()


func draw_telegraph(fan: Fan) -> void:
	var tint := fan.get_warning_color()
	fan.draw_circle(Vector2.ZERO, radius, Color(tint, 0.2))
	fan.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(tint, 0.95), 3.0, true)


func draw_effect(fan: Fan) -> void:
	if flash_remaining <= 0.0:
		return
	var alpha := flash_remaining / FLASH_DURATION
	var flash_color := fan.get_warning_color().lightened(0.75)
	fan.draw_circle(Vector2.ZERO, radius, Color(flash_color, 0.45 * alpha))
	fan.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(Color.WHITE, alpha), 5.0, true)
