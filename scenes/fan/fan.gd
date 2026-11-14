class_name Fan
extends CharacterBody2D

signal died
signal despawned(population_cost: int)
signal shoot_requested(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float, speed: float)

@export var club: FanClubData
@export var team_id: int = 1
@export var show_trajectory_guides: bool = false
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

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
var charge_timer: Timer


func _ready() -> void:
	assert(club != null and club.movement_scene != null and club.attack_scene != null,
		"Assign a FanClubData with movement and attack scenes before add_child().")
	hp = club.max_hp
	if club.sprite_texture != null:
		sprite.texture = club.sprite_texture
		sprite.scale = club.sprite_scale * 1.15
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("fans")
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
	var health_color := Color("f16f8a") if team_id == 1 else Color("69a9ff")
	for i in range(club.max_hp):
		var offset := (i - (club.max_hp - 1) * 0.5) * 6.0
		draw_circle(Vector2(offset, 30), 1.8,
			health_color if i < hp else Color("35415b"))


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


func has_active_target() -> bool:
	return is_instance_valid(enemy_player) and enemy_player.is_inside_tree() \
		and (not enemy_player.has_method("is_combat_active") or enemy_player.is_combat_active())


func is_combat_active() -> bool:
	return not has_died and not is_despawning


func _on_attack_timeout() -> void:
	if not is_combat_active():
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
	queue_redraw()
	if hp == 0:
		die()


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
	queue_free()
