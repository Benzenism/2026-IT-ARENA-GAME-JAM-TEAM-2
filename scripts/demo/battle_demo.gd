class_name BattleDemo
extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const ARENA := Rect2(48, 240, 1344, 460)

var players: Array[PrototypePlayer] = []
var teams: Array[TeamController] = []
var projectiles: ProjectileSpawner
var fans: Node2D


func _ready() -> void:
	projectiles = ProjectileSpawner.new()
	add_child(projectiles)
	fans = Node2D.new()
	add_child(fans)
	for i in range(2):
		var player := PLAYER_SCENE.instantiate() as PrototypePlayer
		player.team_id = i + 1
		player.arena_rect = ARENA
		player.spawn_position = Vector2(145 if i == 0 else 1295, ARENA.get_center().y)
		player.position = player.spawn_position
		add_child(player)
		players.append(player)
	for i in range(2):
		var team := TeamController.new()
		team.team_id = i + 1
		team.owned_clubs = [NORMAL, ANTI]
		team.enemy_player = players[1 - i]
		team.fan_container = fans
		team.projectile_spawner = projectiles
		team.arena_rect = ARENA
		add_child(team)
		teams.append(team)
		team.try_spawn()


func _draw() -> void:
	draw_style_box(LabUI.panel(Color("0b1424"), Color("263751"), 16), ARENA)
	draw_rect(Rect2(ARENA.position, Vector2(110, ARENA.size.y)), Color("102137"))
	draw_rect(Rect2(ARENA.end - Vector2(110, ARENA.size.y), Vector2(110, ARENA.size.y)),
		Color("291c32"))
	for x in range(78, 1380, 30):
		for y in range(260, 690, 30):
			draw_circle(Vector2(x, y), 0.7, Color("24324a"))
	draw_dashed_line(Vector2(720, 258), Vector2(720, 684), Color("3a4c66"), 1, 8)
	draw_arc(ARENA.get_center(), 90, 0, TAU, 64, Color("203049"), 1, true)
	draw_arc(ARENA.get_center(), 96, 0, TAU, 64, Color("18283d"), 1, true)
