extends Node2D
## Test-only setup in the same World2D viewed by both player cameras.

const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const CAMERA: FanClubData = preload("res://data/fanclubs/camera_fan.tres")
const PLACEHOLDER: Texture2D = preload("res://icon.svg")

var teams: Array[TeamController] = []
var fans: Node2D
var projectiles: ProjectileSpawner


func _enter_tree() -> void:
	# Field builds its collision walls in _ready(), so set its size first.
	(get_parent().get_node("Field") as Field).size = Vector2(2200, 1200)


func _ready() -> void:
	var world := get_parent()
	var field := world.get_node("Field") as Field
	var players: Array[CharacterBody2D] = [world.get_node("Player1"), world.get_node("Player2")]
	var bounds := field.get_field_rect()
	fans = Node2D.new()
	fans.name = "Fans"
	add_child(fans)
	projectiles = ProjectileSpawner.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	for i in range(2):
		var team := TeamController.new()
		team.name = "Team%d" % (i + 1)
		team.team_id = i + 1
		team.owned_clubs = [NORMAL, ANTI, CAMERA]
		team.enemy_player = players[1 - i]
		team.fan_container = fans
		team.projectile_spawner = projectiles
		team.arena_rect = bounds
		team.fan_spawned.connect(_on_fan_spawned)
		add_child(team)
		teams.append(team)
		team.try_spawn()
		team.try_spawn()


func _on_fan_spawned(fan: Fan) -> void:
	# Use the existing project icon only when the club has no sprite configured.
	if fan.sprite.texture == null:
		fan.sprite.texture = PLACEHOLDER
		fan.sprite.scale = Vector2(0.36, 0.36)
		fan.sprite.modulate = Color(1, 0.55, 0.55) if fan.team_id == 1 else Color(0.55, 0.7, 1)


func _process(_delta: float) -> void:
	# Give otherwise invisible bullets a temporary marker in this test scene only.
	for bullet: FanProjectile in projectiles.get_children():
		var sprite := bullet.get_node("Sprite2D") as Sprite2D
		if sprite.texture == null:
			sprite.texture = PLACEHOLDER
			sprite.scale = Vector2(0.3, 0.3)
			sprite.modulate = Color(1, 0.55, 0.55) if bullet.team_id == 1 else Color(0.55, 0.7, 1)
