class_name Fan
extends CharacterBody2D

signal died
signal despawned(population_cost: int)
signal shoot_requested(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2)

var club: FanClubData
var team_id: int = 1
var enemy_player: CharacterBody2D
var arena_rect := Rect2(48, 230, 1344, 480)
var speed_multiplier: float = 1.0
var hp: int
var movement: FanMovement
var attack: FanAttack
var is_despawning: bool = false
var has_died: bool = false
var age: float = 0.0
var hit_flash: float = 0.0
var shot_flash: float = 0.0

@onready var attack_timer: Timer = $AttackTimer


func _ready() -> void:
	assert(club != null and club.movement_scene != null and club.attack_scene != null,
		"Assign a FanClubData with movement and attack scenes before add_child().")
	hp = club.max_hp
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("fans")
	movement = club.movement_scene.instantiate() as FanMovement
	attack = club.attack_scene.instantiate() as FanAttack
	assert(movement != null and attack != null, "Invalid fan behavior scene.")
	add_child(movement)
	add_child(attack)
	for ability_scene in club.ability_scenes:
		var ability := ability_scene.instantiate() as FanAbility
		assert(ability != null)
		add_child(ability)
		ability.setup(self)
	attack_timer.wait_time = maxf(0.05, club.attack_interval)
	attack_timer.timeout.connect(_on_attack_timeout)
	attack_timer.start()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_despawning:
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta * 5.0)
	shot_flash = maxf(0.0, shot_flash - delta * 5.0)
	velocity = movement.get_direction(self).normalized() * club.move_speed * speed_multiplier
	move_and_slide()
	if not arena_rect.grow(24.0).has_point(global_position):
		exit_map()
	queue_redraw()


func forward_dir() -> Vector2:
	return Vector2.RIGHT if team_id == 1 else Vector2.LEFT


func has_active_target() -> bool:
	return is_instance_valid(enemy_player) and enemy_player.is_inside_tree() \
		and (not enemy_player.has_method("is_combat_active") or enemy_player.is_combat_active())


func is_combat_active() -> bool:
	return not has_died and not is_despawning


func _on_attack_timeout() -> void:
	if is_combat_active():
		attack.fire(self)


func shoot(direction: Vector2) -> void:
	if is_despawning or direction.is_zero_approx() or club.projectile_scene == null:
		return
	shot_flash = 1.0
	var aim := direction.normalized()
	shoot_requested.emit(club.projectile_scene, global_position + aim * 23.0,
		aim, team_id, arena_rect)


func take_damage(amount: int) -> void:
	if not is_combat_active() or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hit_flash = 1.0
	if hp == 0:
		die()
	queue_redraw()


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
	despawned.emit(club.population_cost)
	queue_free()


func _draw() -> void:
	if club == null:
		return
	var bob := sin(age * 7.0) * 1.8
	var center := Vector2(0, bob)
	var color := club.accent.lerp(Color.WHITE, hit_flash * 0.8)
	var team_color := Color("7ddcff") if team_id == 1 else Color("ff92b9")
	draw_ellipse_shadow()
	draw_arc(Vector2.ZERO, 24, 0, TAU, 32, Color(team_color, 0.38), 1.5, true)
	draw_circle(center, 19.0, Color(color, 0.08))
	draw_circle(center, 15.5, Color("131e30"))
	draw_circle(center, 13.5, color)
	var crown := PackedVector2Array()
	for i in range(club.crest_points * 2 + 1):
		var x := -14.0 + 28.0 * float(i) / (club.crest_points * 2)
		crown.append(Vector2(x, -12.0 - (7.0 if i % 2 == 1 else 0.0)) + center)
	crown.append(Vector2(14, -7) + center)
	crown.append(Vector2(-14, -7) + center)
	draw_colored_polygon(crown, color.lightened(0.25))
	var slant := club.eye_slant * 3.0
	draw_line(center + Vector2(-7, -3 - slant), center + Vector2(-3, -3 + slant),
		Color("172237"), 2.5, true)
	draw_line(center + Vector2(3, -3 + slant), center + Vector2(7, -3 - slant),
		Color("172237"), 2.5, true)
	draw_arc(center + Vector2(0, 2), 4, 0.2, PI - 0.2, 10, Color("172237"), 1.5, true)
	draw_line(center + Vector2(-9, 13), center + Vector2(-10, 18), color, 3, true)
	draw_line(center + Vector2(9, 13), center + Vector2(10, 18), color, 3, true)
	var wand := center + Vector2(forward_dir().x * 22, -2)
	draw_line(wand, wand + Vector2(0, 13), Color("8b9cbb"), 3, true)
	draw_line(wand, wand + Vector2(0, -8), Color.WHITE.lerp(color, 0.4), 4, true)
	if shot_flash > 0:
		draw_circle(wand, 9 * shot_flash, Color(color, shot_flash * 0.3))
	for i in range(club.max_hp):
		var dot := Vector2((i - (club.max_hp - 1) * 0.5) * 6.0, -30)
		draw_circle(dot, 1.8, color if i < hp else Color("35415b"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 19), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
