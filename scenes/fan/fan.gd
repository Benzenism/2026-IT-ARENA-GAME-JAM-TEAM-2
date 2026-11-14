class_name Fan
extends CharacterBody2D

signal died
signal despawned(population_cost: int)
signal shoot_requested(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float, speed: float)

const HEART_POINTS := [Vector2(0, 8), Vector2(-8, 1), Vector2(-9, -3),
	Vector2(-7, -7), Vector2(-3, -8), Vector2(0, -5), Vector2(3, -8),
	Vector2(7, -7), Vector2(9, -3), Vector2(8, 1), Vector2(0, 8)]

@export var club: FanClubData
@export var team_id: int = 1
@export var show_trajectory_guides: bool = false
@export var ally_player: CharacterBody2D
var enemy_player: CharacterBody2D
var arena_rect := Rect2(0, 0, 1280, 720)
var hp: int
var movement: FanMovement
var attack: FanAttack
var is_despawning: bool = false
var has_died: bool = false
var is_charging: bool = false
var charge_base_color := Color.WHITE
var first_attack_offset: float = 0.0
var hit_flash_tween: Tween
var hit_flash_base_color := Color.WHITE

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
var charge_timer: Timer


func _ready() -> void:
	assert(club != null and club.movement_scene != null and club.attack_scene != null,
		"Assign a FanClubData with movement and attack scenes before add_child().")
	hp = club.max_hp
	var body_collision := $CollisionShape2D as CollisionShape2D
	var original_shape := body_collision.shape as CircleShape2D
	if original_shape != null and not is_equal_approx(original_shape.radius, club.hitbox_radius):
		var instance_shape := original_shape.duplicate() as CircleShape2D
		instance_shape.radius = maxf(1.0, club.hitbox_radius)
		body_collision.shape = instance_shape
	if club.sprite_texture != null:
		sprite.texture = club.sprite_texture
		sprite.scale = club.sprite_scale * 1.15
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("fans")
	if club.intercepts_projectiles:
		add_to_group("projectile_guards")
	movement = club.movement_scene.instantiate() as FanMovement
	attack = club.attack_scene.instantiate() as FanAttack
	assert(movement != null and attack != null, "Invalid fan behavior scene.")
	add_child(movement)
	add_child(attack)
	charge_timer = Timer.new()
	charge_timer.one_shot = true
	charge_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	charge_timer.wait_time = maxf(0.05, club.charge_duration)
	charge_timer.timeout.connect(_on_charge_finished)
	add_child(charge_timer)
	for ability_scene in club.ability_scenes:
		var ability := ability_scene.instantiate() as FanAbility
		assert(ability != null)
		add_child(ability)
		ability.setup(self)
	attack_timer.wait_time = maxf(0.05, club.attack_interval - charge_timer.wait_time)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timeout)
	if attack.is_enabled():
		attack_timer.start(attack_timer.wait_time + maxf(0.0, first_attack_offset))

func _process(_delta: float) -> void:
	if is_charging:
		var progress := 1.0 - (charge_timer.time_left / charge_timer.wait_time)
		# A warm flash remains visible even when the original sprite is white.
		var warning_color := Color(1.0, 0.68, 0.3, charge_base_color.a)
		sprite.modulate = charge_base_color.lerp(warning_color, 0.35 + 0.4 * progress)


func _physics_process(_delta: float) -> void:
	if is_despawning:
		return
	velocity = Vector2.ZERO if is_charging else movement.get_direction(self).limit_length(1.0) * club.move_speed
	move_and_slide()
	if not arena_rect.grow(24.0).has_point(global_position):
		exit_map()


func _draw() -> void:
	if is_charging:
		if show_trajectory_guides:
			var line_color := Color(1.0, 0.55, 0.55, 0.7) if team_id == 1 else Color(0.55, 0.7, 1.0, 0.7)
			for direction in attack.prepared_directions:
				var aim := direction.normalized()
				if aim.is_zero_approx():
					continue
				var origin := aim * 23.0
				var length := _telegraph_length(global_position + origin, aim)
				draw_line(origin, origin + aim * length, Color(line_color, 0.18), 8.0, true)
				draw_line(origin, origin + aim * length, line_color, 2.5, true)
		attack.draw_telegraph(self)
	attack.draw_effect(self)
	if is_despawning:
		return
	var health_color := Color("e845e0") if team_id == 1 else Color("0c56f6")
	for i in range(club.max_hp):
		var offset := Vector2((i - (club.max_hp - 1) * 0.5) * 21.0, 68.0)
		var points := PackedVector2Array()
		for point in HEART_POINTS:
			points.append(point + offset)
		draw_colored_polygon(points, health_color if i < hp else Color("717682"))
		draw_polyline(points, Color("1b2029"), 2.0, true)


func _telegraph_length(origin: Vector2, direction: Vector2) -> float:
	var bounds := arena_rect.grow(28.0)
	var length := club.projectile_speed * club.projectile_lifetime
	if direction.x > 0.001:
		length = minf(length, (bounds.end.x - origin.x) / direction.x)
	elif direction.x < -0.001:
		length = minf(length, (bounds.position.x - origin.x) / direction.x)
	if direction.y > 0.001:
		length = minf(length, (bounds.end.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		length = minf(length, (bounds.position.y - origin.y) / direction.y)
	return maxf(0.0, length)


func forward_dir() -> Vector2:
	return Vector2.RIGHT if team_id == 1 else Vector2.LEFT


func change_team(new_team_id: int, new_enemy_player: CharacterBody2D) -> void:
	team_id = new_team_id
	enemy_player = new_enemy_player
	queue_redraw()


func has_active_target() -> bool:
	return is_instance_valid(enemy_player) and enemy_player.is_inside_tree() \
		and (not enemy_player.has_method("is_combat_active") or enemy_player.is_combat_active())


func is_combat_active() -> bool:
	return not has_died and not is_despawning


func _on_attack_timeout() -> void:
	if not is_combat_active() or not attack.is_enabled():
		return
	attack.prepare(self)
	is_charging = true
	charge_base_color = sprite.modulate
	charge_timer.start()
	queue_redraw()


func _on_charge_finished() -> void:
	if not is_combat_active():
		return
	is_charging = false
	sprite.modulate = charge_base_color
	attack.fire(self)
	queue_redraw()
	attack_timer.start(maxf(0.05, club.attack_interval - charge_timer.wait_time))


func shoot(direction: Vector2) -> void:
	if is_despawning or direction.is_zero_approx() or club.projectile_scene == null:
		return
	var aim := direction.normalized()
	shoot_requested.emit(club.projectile_scene, global_position + aim * 23.0,
		aim, team_id, arena_rect, club.projectile_lifetime, club.projectile_speed)


func take_damage(amount: int) -> void:
	if not is_combat_active() or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	_show_hit_flash()
	queue_redraw()
	if hp == 0:
		die()


func _show_hit_flash() -> void:
	if club.hit_flash_duration <= 0.0:
		return
	if hit_flash_tween != null and hit_flash_tween.is_running():
		hit_flash_tween.kill()
	else:
		hit_flash_base_color = sprite.modulate
	sprite.modulate = Color(hit_flash_base_color.r, hit_flash_base_color.g * 0.15,
		hit_flash_base_color.b * 0.15, hit_flash_base_color.a)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(sprite, "modulate", hit_flash_base_color, club.hit_flash_duration)


func heal(amount: int) -> void:
	if is_combat_active() and amount > 0:
		hp = mini(club.max_hp, hp + amount)
		queue_redraw()


func die() -> void:
	if not is_combat_active():
		return
	has_died = true
	died.emit()
	despawn()


func exit_map() -> void:
	despawn()


func despawn() -> void:
	if is_despawning:
		return
	is_despawning = true
	attack_timer.stop()
	charge_timer.stop()
	despawned.emit(club.population_cost)
	if has_died and club.hit_flash_duration > 0.0:
		if hit_flash_tween != null and hit_flash_tween.is_running():
			hit_flash_tween.kill()
		set_deferred("collision_layer", 0)
		var faded_color := sprite.modulate
		faded_color.a = 0.0
		var death_tween := create_tween()
		death_tween.tween_property(sprite, "modulate", faded_color, club.hit_flash_duration)
		death_tween.tween_callback(queue_free)
	else:
		queue_free()
