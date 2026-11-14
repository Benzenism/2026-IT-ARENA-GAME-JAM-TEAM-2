class_name IdolPlayer
extends CharacterBody2D
## 탑다운 2D 플레이어. input_prefix로 어떤 키 세트를 쓸지 정함.
## "p1" → WASD, "p2" → 방향키 (Project Settings > Input Map 참고)

@export var input_prefix: String = "p1"
@export var speed: float = 400.0
@export var collision_bounce_speed: float = 450.0
@export var collision_bounce_deceleration: float = 850.0
@export var player_texture: Texture2D
@export var team_id: int = 1
@export var max_hp: int = 3

const HIT_INVULNERABILITY := 1.0
const BOUNCE_COOLDOWN := 0.3
const BOUNCE_INPUT_LOCK := 0.12
const DIAGONAL_SPEED_MULTIPLIER := 1.1
const HEART_POINTS := [Vector2(0, 8), Vector2(-8, 1), Vector2(-9, -3),
	Vector2(-7, -7), Vector2(-3, -8), Vector2(0, -5), Vector2(3, -8),
	Vector2(7, -7), Vector2(9, -3), Vector2(8, 1), Vector2(0, 8)]

signal health_changed(current_hp: int, maximum_hp: int)
signal respawned
signal baton_dropped(player: IdolPlayer, club: FanClubData, position: Vector2)

var hp: int
var spawn_position: Vector2
var invulnerability: float = 0.0
var movement_locked: bool = false
var carried_club: FanClubData
var respawn_timer: Timer
var own_stage_center := Vector2.ZERO
var own_stage_radius := 220.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var movement_velocity := Vector2.ZERO
var bounce_velocity := Vector2.ZERO
var bounce_cooldown := 0.0
var bounce_input_lock := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _baton_sprite: Sprite2D = $BatonSprite


func _ready() -> void:
	add_to_group("idols")
	assert(player_texture != null, "Assign a player texture before adding an IdolPlayer.")
	_sprite.texture = player_texture
	hp = max_hp
	spawn_position = global_position
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = 2.0
	respawn_timer.timeout.connect(respawn)
	add_child(respawn_timer)


func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	bounce_cooldown = maxf(0.0, bounce_cooldown - delta)
	bounce_input_lock = maxf(0.0, bounce_input_lock - delta)
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining == 0.0:
			slow_multiplier = 1.0
	var display_color := Color.WHITE
	if invulnerability > 0.0 and int(invulnerability * 10.0) % 2 == 0:
		display_color.a *= 0.4
	_sprite.modulate = display_color
	if not is_combat_active():
		return
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# 대각선 이동 속도를 기본 속도의 1.1배까지 허용한다.
	var direction := Vector2(
		Input.get_axis(input_prefix + "_left", input_prefix + "_right"),
		Input.get_axis(input_prefix + "_up", input_prefix + "_down")
	).limit_length(DIAGONAL_SPEED_MULTIPLIER)
	var max_speed := maxf(0.0, speed * (0.8 if carried_club != null else 1.0) * slow_multiplier)
	movement_velocity = direction * max_speed if bounce_input_lock <= 0.0 else Vector2.ZERO
	bounce_velocity = bounce_velocity.move_toward(Vector2.ZERO, maxf(0.0, collision_bounce_deceleration) * delta)
	velocity = movement_velocity + bounce_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as IdolPlayer
		if other == null or not other.is_combat_active():
			continue
		if other.team_id != team_id:
			drop_carried_baton()
			other.drop_carried_baton()
		if bounce_cooldown <= 0.0 and other.bounce_cooldown <= 0.0:
			var away := collision.get_normal().normalized()
			if away.is_zero_approx():
				away = other.global_position.direction_to(global_position)
			if away.is_zero_approx():
				away = Vector2.LEFT if team_id == 1 else Vector2.RIGHT
			_start_bounce(away)
			other._start_bounce(-away)
		break


func _start_bounce(away: Vector2) -> void:
	bounce_cooldown = BOUNCE_COOLDOWN
	if movement_locked or not is_combat_active():
		return
	var into_collision := movement_velocity.dot(away)
	if into_collision < 0.0:
		movement_velocity -= away * into_collision
	bounce_velocity = away * maxf(0.0, collision_bounce_speed)
	bounce_input_lock = BOUNCE_INPUT_LOCK
	velocity = movement_velocity + bounce_velocity


func _process(_delta: float) -> void:
	if not is_combat_active():
		_sprite.visible = false
		return
	_sprite.visible = invulnerability <= 0.0 or fmod(invulnerability * 10.0, 2.0) > 1.0


func _draw() -> void:
	for i in range(max_hp):
		var offset := Vector2((i - (max_hp - 1) * 0.5) * 21.0, 83.0)
		var points := PackedVector2Array()
		for point in HEART_POINTS:
			points.append(point + offset)
		var heart_color := Color("4c8ded") if team_id == 1 else Color("ed4c9a")
		draw_colored_polygon(points, heart_color if i < hp else Color("414b57"))
		draw_polyline(points, Color("1b2029"), 1.5, true)


func is_combat_active() -> bool:
	return hp > 0


func is_damageable() -> bool:
	return global_position.distance_to(own_stage_center) > own_stage_radius


func set_own_stage(center: Vector2, radius: float) -> void:
	own_stage_center = center
	own_stage_radius = radius


func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		movement_velocity = Vector2.ZERO
		bounce_velocity = Vector2.ZERO
		bounce_input_lock = 0.0
		velocity = Vector2.ZERO


func start_carrying(club: FanClubData) -> void:
	carried_club = club
	_baton_sprite.texture = club.sprite_texture
	_baton_sprite.visible = true


func finish_carrying() -> FanClubData:
	var club := carried_club
	carried_club = null
	_baton_sprite.visible = false
	return club


func drop_carried_baton() -> void:
	if carried_club == null:
		return
	var club := finish_carrying()
	baton_dropped.emit(self, club, global_position)


func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0 or invulnerability > 0.0 or not is_combat_active():
		return
	# Repeated flashes refresh the duration instead of multiplying the slowdown.
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.0, 1.0))
	slow_remaining = maxf(slow_remaining, duration)


func take_damage(amount: int) -> void:
	if amount <= 0 or invulnerability > 0 or not is_combat_active():
		return
	drop_carried_baton()
	hp = maxi(0, hp - amount)
	invulnerability = HIT_INVULNERABILITY
	queue_redraw()
	health_changed.emit(hp, max_hp)
	if hp == 0:
		set_movement_locked(true)
		respawn_timer.start()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp = max_hp
	invulnerability = 0.5
	_sprite.visible = true
	set_movement_locked(false)
	slow_remaining = 0.0
	slow_multiplier = 1.0
	reset_physics_interpolation()
	queue_redraw()
	health_changed.emit(hp, max_hp)
	respawned.emit()
