class_name PrototypePlayer
extends CharacterBody2D
## A minimal dodge/respawn target for testing fan combat.

signal health_changed
signal respawned

@export var team_id: int = 1
@export var max_hp: int = 6
@export var move_speed: float = 245.0
var input_enabled: bool = true
var target_mode: bool = false
var arena_rect := Rect2(48, 230, 1344, 480)
var spawn_position: Vector2
var hp: int
var respawn_remaining: float = 0.0
var invulnerability: float = 0.0
var age: float = 0.0
var hit_flash: float = 0.0
var deaths: int = 0


func _ready() -> void:
	hp = max_hp
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_setup_inputs()
	queue_redraw()


func _physics_process(delta: float) -> void:
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta * 5)
	invulnerability = maxf(0.0, invulnerability - delta)
	if respawn_remaining > 0:
		respawn_remaining -= delta
		if respawn_remaining <= 0:
			respawn()
		queue_redraw()
		return
	if input_enabled:
		var prefix := "p1_" if team_id == 1 else "p2_"
		velocity = Input.get_vector(prefix + "left", prefix + "right",
			prefix + "up", prefix + "down") * move_speed
		move_and_slide()
		var safe_rect := arena_rect.grow(-18)
		global_position = global_position.clamp(safe_rect.position, safe_rect.end)
	queue_redraw()


func is_combat_active() -> bool:
	return respawn_remaining <= 0 and hp > 0


func take_damage(amount: int) -> void:
	if not is_combat_active() or invulnerability > 0 or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	hit_flash = 1.0
	invulnerability = 0.4
	if hp == 0:
		deaths += 1
		respawn_remaining = 0.9 if target_mode else 1.5
	health_changed.emit()
	queue_redraw()


func respawn() -> void:
	hp = max_hp
	respawn_remaining = 0
	invulnerability = 0.7 if target_mode else 1.2
	global_position = spawn_position
	respawned.emit()
	health_changed.emit()
	queue_redraw()


func _draw() -> void:
	var color := Color("7ddcff") if team_id == 1 else Color("ff92b9")
	if respawn_remaining > 0:
		draw_arc(Vector2.ZERO, 19, -PI / 2, -PI / 2 + TAU *
			(1.0 - respawn_remaining / (0.9 if target_mode else 1.5)), 32, color, 2, true)
		return
	var alpha := 0.45 if invulnerability > 0 and sin(age * 30) > 0 else 1.0
	color.a = alpha
	draw_circle(Vector2.ZERO, 28, Color(color, 0.06))
	draw_arc(Vector2.ZERO, 23, 0, TAU, 32, Color(color, 0.5), 1.4, true)
	var points := PackedVector2Array([Vector2(0, -17), Vector2(15, 0),
		Vector2(0, 17), Vector2(-15, 0)])
	draw_colored_polygon(points, color.lerp(Color.WHITE, hit_flash * 0.7))
	draw_circle(Vector2.ZERO, 5, Color("142137"))
	draw_circle(Vector2(-1, -1), 2, Color.WHITE)
	for i in range(max_hp):
		draw_circle(Vector2((i - (max_hp - 1) * 0.5) * 6, 33), 1.8,
			color if i < hp else Color("35415b"))
	if target_mode:
		draw_line(Vector2(-31, 0), Vector2(-25, 0), Color(color, 0.6), 1)
		draw_line(Vector2(25, 0), Vector2(31, 0), Color(color, 0.6), 1)
		draw_line(Vector2(0, -31), Vector2(0, -25), Color(color, 0.6), 1)


static func _setup_inputs() -> void:
	var bindings := {"p1_up": KEY_W, "p1_down": KEY_S, "p1_left": KEY_A,
		"p1_right": KEY_D, "p2_up": KEY_UP, "p2_down": KEY_DOWN,
		"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
