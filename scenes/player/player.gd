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

const PLAYER1_AURA: Texture2D = preload("res://sprites/player1_aura.png")
const PLAYER2_AURA: Texture2D = preload("res://sprites/player2_aura.png")
const HIT_INVULNERABILITY := 1.0
const BOUNCE_COOLDOWN := 0.3
const BOUNCE_INPUT_LOCK := 0.12
const DIAGONAL_SPEED_MULTIPLIER := 1.2
const BURST_RADIUS := 300.0
const BURST_VISUAL_DURATION := 0.2
const BURST_PLAYER_KNOCKBACK_DISTANCE := 350.0
const BURST_FAN_KNOCKBACK_DISTANCE := 350.0
const BURST_COOLDOWN_WITH_PLAYER := 10.0
const BURST_COOLDOWN_WITHOUT_PLAYER := 5.0
const BURST_KNOCKBACK_DECELERATION := 850.0
const BURST_RING_RADIUS := 50.0
const BURST_RING_CENTER := Vector2(0.0, 16.0)
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
var burst_cooldown_remaining := 0.0
var burst_cooldown_duration := BURST_COOLDOWN_WITH_PLAYER
var burst_visual_remaining := 0.0
var burst_ready_flash_remaining := 0.0
var facing_direction := Vector2.RIGHT

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _baton_sprite: Sprite2D = $BatonSprite
@onready var _aura_sprite: Sprite2D = $AuraSprite


func _ready() -> void:
	add_to_group("idols")
	assert(player_texture != null, "Assign a player texture before adding an IdolPlayer.")
	_sprite.texture = player_texture
	_aura_sprite.texture = PLAYER1_AURA if team_id == 1 else PLAYER2_AURA
	hp = max_hp
	facing_direction = Vector2.RIGHT if team_id == 1 else Vector2.LEFT
	_sprite.flip_h = team_id == 1
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
	var was_cooling_down := burst_cooldown_remaining > 0.0
	burst_cooldown_remaining = maxf(0.0, burst_cooldown_remaining - delta)
	if was_cooling_down and is_zero_approx(burst_cooldown_remaining):
		burst_ready_flash_remaining = 0.35
	burst_visual_remaining = maxf(0.0, burst_visual_remaining - delta)
	burst_ready_flash_remaining = maxf(0.0, burst_ready_flash_remaining - delta)
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
	# 대각선 이동 속도를 기본 속도의 1.2배까지 허용한다.
	var direction := Vector2(
		Input.get_axis(input_prefix + "_left", input_prefix + "_right"),
		Input.get_axis(input_prefix + "_up", input_prefix + "_down")
	).limit_length(DIAGONAL_SPEED_MULTIPLIER)
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
	if not is_zero_approx(direction.x):
		_sprite.flip_h = direction.x > 0.0
	var max_speed := maxf(0.0, speed * (0.8 if carried_club != null else 1.0) * slow_multiplier)
	movement_velocity = direction * max_speed if bounce_input_lock <= 0.0 else Vector2.ZERO
	bounce_velocity = bounce_velocity.move_toward(Vector2.ZERO, maxf(0.0, collision_bounce_deceleration) * delta)
	velocity = movement_velocity + bounce_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider() as IdolPlayer
		var obstacle := collision.get_collider() as ArenaObstacle
		if obstacle != null:
			var away := collision.get_normal().normalized()
			if away.is_zero_approx():
				away = obstacle.global_position.direction_to(global_position)
			_start_bounce(away)
			obstacle.apply_push(-away, collision_bounce_speed)
			break
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
		_aura_sprite.visible = false
		return
	_sprite.visible = invulnerability <= 0.0 or fmod(invulnerability * 10.0, 2.0) > 1.0
	if burst_visual_remaining > 0.0:
		var progress := 1.0 - burst_visual_remaining / BURST_VISUAL_DURATION
		var aura_scale := 0.75 + progress * 0.25
		_aura_sprite.visible = true
		_aura_sprite.scale = Vector2.ONE * aura_scale
		_aura_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)
	else:
		_aura_sprite.visible = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_SHIFT and key_event.physical_keycode != KEY_SHIFT:
		return
	var expected_location := KEY_LOCATION_LEFT if team_id == 1 else KEY_LOCATION_RIGHT
	if key_event.location == expected_location:
		_try_idol_burst()


func _draw() -> void:
	_draw_burst_ring()
	for i in range(max_hp):
		var offset := Vector2((i - (max_hp - 1) * 0.5) * 21.0, 83.0)
		var points := PackedVector2Array()
		for point in HEART_POINTS:
			points.append(point + offset)
		var heart_color := Color("4c8ded") if team_id == 1 else Color("ed4c9a")
		draw_colored_polygon(points, heart_color if i < hp else Color("414b57"))
		draw_polyline(points, Color("1b2029"), 1.5, true)


func _draw_burst_ring() -> void:
	var ring_color := Color("478dff") if team_id == 1 else Color("ed4c9a")
	var ring_alpha := 1.0
	if burst_cooldown_remaining > 0.0:
		ring_alpha = 0.75
	elif burst_ready_flash_remaining > 0.0:
		ring_alpha = 1.0 + 0.35 * sin(burst_ready_flash_remaining * 24.0)
	var ring := Color(ring_color, ring_alpha)
	draw_arc(BURST_RING_CENTER, BURST_RING_RADIUS, 0.0, TAU, 64, Color(ring, 0.25), 3.0, true)
	if burst_cooldown_remaining > 0.0:
		var progress := 1.0 - burst_cooldown_remaining / burst_cooldown_duration
		draw_arc(BURST_RING_CENTER, BURST_RING_RADIUS, -PI / 2.0,
			-PI / 2.0 + TAU * progress, 64, ring, 3.0, true)
	else:
		draw_arc(BURST_RING_CENTER, BURST_RING_RADIUS, 0.0, TAU, 64, ring, 3.0, true)


func _try_idol_burst() -> void:
	if not is_combat_active() or burst_cooldown_remaining > 0.0:
		return
	burst_visual_remaining = BURST_VISUAL_DURATION
	var hit_player := false
	for idol: IdolPlayer in get_tree().get_nodes_in_group("idols"):
		if idol == self or idol.team_id == team_id or not idol.is_combat_active():
			continue
		if global_position.distance_to(idol.global_position) > BURST_RADIUS:
			continue
		hit_player = true
		idol.apply_burst_knockback(_burst_direction_to(idol.global_position),
				BURST_PLAYER_KNOCKBACK_DISTANCE)
	for projectile: FanProjectile in get_tree().get_nodes_in_group("projectiles"):
		if global_position.distance_to(projectile.global_position) > BURST_RADIUS:
			continue
		projectile.consumed = true
		projectile.queue_free()
	for fan: Fan in get_tree().get_nodes_in_group("fans"):
		if fan.team_id == team_id or not fan.is_combat_active():
			continue
		if global_position.distance_to(fan.global_position) > BURST_RADIUS:
			continue
		fan.apply_knockback(_burst_direction_to(fan.global_position),
				BURST_FAN_KNOCKBACK_DISTANCE)
	burst_cooldown_duration = BURST_COOLDOWN_WITH_PLAYER \
			if hit_player else BURST_COOLDOWN_WITHOUT_PLAYER
	burst_cooldown_remaining = burst_cooldown_duration
	queue_redraw()


func _burst_direction_to(target_position: Vector2) -> Vector2:
	var direction := global_position.direction_to(target_position)
	return -facing_direction if direction.is_zero_approx() else direction


func apply_burst_knockback(direction: Vector2, distance: float) -> void:
	if not is_combat_active() or direction.is_zero_approx() or distance <= 0.0:
		return
	var speed := sqrt(2.0 * BURST_KNOCKBACK_DECELERATION * distance)
	bounce_velocity += direction.normalized() * speed
	bounce_input_lock = maxf(bounce_input_lock, BOUNCE_INPUT_LOCK)


func is_combat_active() -> bool:
	return hp > 0


func is_damageable() -> bool:
	return global_position.distance_to(own_stage_center) > own_stage_radius


func set_own_stage(center: Vector2, radius: float) -> void:
	own_stage_center = center
	own_stage_radius = radius
	spawn_position = center


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
	if amount <= 0 or invulnerability > 0 or not is_combat_active() \
			or not is_damageable():
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
