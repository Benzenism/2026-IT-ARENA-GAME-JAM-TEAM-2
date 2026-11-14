class_name FanExample
extends Node2D

const FAN_SCENE: PackedScene = preload("res://scenes/fan/fan.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var club: FanClubData
var bounds: Rect2
var fan: Fan
var target: PrototypePlayer
var projectiles: ProjectileSpawner
var move_target: bool = true
var show_aim_line: bool = false
var elapsed: float = 0.0
var fan_elapsed: float = 0.0
var spawn_delay: float = 0.0
var shots_fired: int = 0
var stage_style := LabUI.panel(Color("0b1424"), Color("24314b"), 10)


func _ready() -> void:
	projectiles = ProjectileSpawner.new()
	add_child(projectiles)
	target = PLAYER_SCENE.instantiate() as PrototypePlayer
	target.team_id = 2
	target.input_enabled = false
	target.target_mode = true
	target.max_hp = 5
	target.arena_rect = bounds
	target.spawn_position = bounds.position + Vector2(bounds.size.x * 0.79, bounds.size.y * 0.5)
	target.position = target.spawn_position
	add_child(target)
	_spawn_fan()


func _physics_process(delta: float) -> void:
	elapsed += delta
	fan_elapsed += delta
	if move_target and target.is_combat_active():
		target.global_position = target.spawn_position + Vector2(
			sin(elapsed * 0.55) * 24, sin(elapsed * 0.9) * 60)
	if not is_instance_valid(fan):
		spawn_delay -= delta
		if spawn_delay <= 0:
			_spawn_fan()
	elif fan_elapsed > 11.0:
		# Replay the approach periodically; this is map removal, not death.
		fan.exit_map()
		spawn_delay = 0.7
	queue_redraw()


func _spawn_fan() -> void:
	fan = FAN_SCENE.instantiate() as Fan
	fan.club = club
	fan.team_id = 1
	fan.enemy_player = target
	fan.arena_rect = bounds
	fan.position = bounds.position + Vector2(68, bounds.size.y * 0.5)
	fan.shoot_requested.connect(projectiles.request_shot)
	fan.shoot_requested.connect(_on_shot)
	add_child(fan)
	fan_elapsed = 0
	spawn_delay = 0.8


func _on_shot(_scene: PackedScene, _origin: Vector2, _direction: Vector2,
		_team: int, _bounds: Rect2) -> void:
	shots_fired += 1


func restart() -> void:
	if is_instance_valid(fan):
		fan.exit_map()
	for projectile in projectiles.get_children():
		projectile.queue_free()
	target.respawn()
	elapsed = 0
	fan_elapsed = 0
	spawn_delay = 0.15
	shots_fired = 0


func _draw() -> void:
	draw_style_box(stage_style, bounds)
	for x in range(int(bounds.position.x) + 20, int(bounds.end.x), 28):
		for y in range(int(bounds.position.y) + 20, int(bounds.end.y), 28):
			draw_circle(Vector2(x, y), 0.7, Color("26344d"))
	var mid_y := bounds.get_center().y
	draw_dashed_line(Vector2(bounds.position.x + 28, mid_y),
		Vector2(bounds.end.x - 28, mid_y), Color("263950"), 1, 7)
	if is_instance_valid(fan) and show_aim_line \
			and target.is_combat_active():
		draw_dashed_line(fan.global_position, target.global_position,
			Color(club.accent, 0.2), 1, 5)
