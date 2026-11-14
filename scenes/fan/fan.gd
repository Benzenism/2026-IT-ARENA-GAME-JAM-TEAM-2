class_name Fan
extends CharacterBody2D

signal died
signal despawned(population_cost: int)
signal shoot_requested(scene: PackedScene, origin: Vector2, direction: Vector2,
		team_id: int, bounds: Rect2, lifetime: float)

const CHARGE_DURATION := 0.5

@export var club: FanClubData
@export var team_id: int = 1
var enemy_player: CharacterBody2D
var arena_rect := Rect2(0, 0, 1280, 720)
var hp: int
var movement: FanMovement
var attack: FanAttack
var is_despawning: bool = false
var has_died: bool = false
var is_charging: bool = false
var charge_base_color := Color.WHITE

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
	charge_timer.wait_time = CHARGE_DURATION
	charge_timer.timeout.connect(_on_charge_finished)
	add_child(charge_timer)
	for ability_scene in club.ability_scenes:
		var ability := ability_scene.instantiate() as FanAbility
		assert(ability != null)
		add_child(ability)
		ability.setup(self)
	attack_timer.wait_time = maxf(0.05, club.attack_interval - CHARGE_DURATION)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timeout)
	attack_timer.start()

func _process(_delta: float) -> void:
	if is_charging:
		var progress := 1.0 - (charge_timer.time_left / CHARGE_DURATION)
		sprite.modulate = charge_base_color.lerp(Color.WHITE, progress)


func _physics_process(_delta: float) -> void:
	if is_despawning:
		return
	velocity = movement.get_direction(self).normalized() * club.move_speed
	move_and_slide()
	if not arena_rect.grow(24.0).has_point(global_position):
		exit_map()


func _draw() -> void:
	var health_color := Color("f16f8a") if team_id == 1 else Color("69a9ff")
	for i in range(club.max_hp):
		var offset := (i - (club.max_hp - 1) * 0.5) * 6.0
		draw_circle(Vector2(offset, 30), 1.8,
			health_color if i < hp else Color("35415b"))


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
	if not is_combat_active():
		return
	is_charging = true
	charge_base_color = sprite.modulate
	charge_timer.start()


func _on_charge_finished() -> void:
	if not is_combat_active():
		return
	is_charging = false
	sprite.modulate = charge_base_color
	attack.fire(self)
	attack_timer.start()


func shoot(direction: Vector2) -> void:
	if is_despawning or direction.is_zero_approx() or club.projectile_scene == null:
		return
	var aim := direction.normalized()
	shoot_requested.emit(club.projectile_scene, global_position + aim * 23.0,
		aim, team_id, arena_rect, club.projectile_lifetime)


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
