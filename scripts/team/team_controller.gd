class_name TeamController
extends Node

signal population_changed
signal fan_spawned(fan: Fan)

const FAN_SCENE: PackedScene = preload("res://scenes/fan/fan.tscn")

@export var team_id: int = 1
@export var population_limit: int = 16
@export var owned_clubs: Array[FanClubData] = []
@export var spawn_interval: float = 1.5

var used_population: int = 0
var club_population: Dictionary = {}
var next_spawn_index: int = 0
var spawn_count: int = 0
var ally_player: CharacterBody2D
var enemy_player: CharacterBody2D
var fan_container: Node2D
var projectile_spawner: ProjectileSpawner
var arena_rect := Rect2(0, 0, 1280, 720)
var spawn_timer: Timer
var respawn_cooldowns: Dictionary = {}


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = maxf(0.05, spawn_interval)
	spawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	spawn_timer.timeout.connect(try_spawn)
	add_child(spawn_timer)
	spawn_timer.start()


func _physics_process(delta: float) -> void:
	for club in respawn_cooldowns.keys():
		var remaining: float = respawn_cooldowns[club] - delta
		if remaining <= 0.0:
			respawn_cooldowns.erase(club)
		else:
			respawn_cooldowns[club] = remaining


func try_spawn() -> Fan:
	_sync_population()
	var count := owned_clubs.size()
	if count == 0:
		return null
	var selected_index := -1
	var selected_population := INF
	for offset in range(count):
		var index := (next_spawn_index + offset) % count
		var club := owned_clubs[index]
		if club == null:
			continue
		if respawn_cooldowns.has(club):
			continue
		if club.requires_ally_player and not _has_ally_player():
			continue
		if used_population + club.population_cost > population_limit:
			continue
		var current_population: int = club_population.get(club, 0)
		if current_population < selected_population:
			selected_index = index
			selected_population = current_population
	if selected_index < 0:
		return null
	var fan := spawn_fan(owned_clubs[selected_index])
	if fan != null:
		next_spawn_index = (selected_index + 1) % count
	return fan


func _sync_population() -> void:
	used_population = 0
	club_population.clear()
	for fan: Fan in get_tree().get_nodes_in_group("fans"):
		if is_instance_valid(fan) and fan.team_id == team_id and fan.is_combat_active():
			used_population += fan.club.population_cost
			club_population[fan.club] = \
				club_population.get(fan.club, 0) + fan.club.population_cost


func spawn_fan(club: FanClubData) -> Fan:
	if club == null or not is_instance_valid(fan_container) \
			or not is_instance_valid(projectile_spawner):
		return null
	if used_population + club.population_cost > population_limit:
		return null
	if respawn_cooldowns.has(club):
		return null
	if club.requires_ally_player and not _has_ally_player():
		return null
	var fan := FAN_SCENE.instantiate() as Fan
	fan.club = club
	fan.team_id = team_id
	fan.ally_player = ally_player
	fan.enemy_player = enemy_player
	fan.arena_rect = arena_rect
	# Spread out the first shots so simultaneous spawns do not form an unavoidable wall.
	fan.first_attack_offset = (spawn_count % 4) * 0.18 + (0.15 if team_id == 2 else 0.0)
	var spawn_x := arena_rect.position.x + 54 if team_id == 1 else arena_rect.end.x - 54
	var lane := spawn_count % 5
	var spawn_y := arena_rect.position.y + 68 + lane * (arena_rect.size.y - 136) / 4.0
	fan.position = fan_container.to_local(Vector2(spawn_x, spawn_y))
	fan.despawned.connect(_on_fan_despawned)
	fan.died.connect(_on_fan_died.bind(club))
	fan.shoot_requested.connect(projectile_spawner.request_shot)
	used_population += club.population_cost
	spawn_count += 1
	fan_container.add_child(fan)
	population_changed.emit()
	fan_spawned.emit(fan)
	return fan


func _has_ally_player() -> bool:
	return is_instance_valid(ally_player) and ally_player.is_inside_tree() \
		and not ally_player.is_queued_for_deletion()


func _on_fan_died(club: FanClubData) -> void:
	if club.respawn_delay > 0.0:
		respawn_cooldowns[club] = club.respawn_delay


func _on_fan_despawned(cost: int) -> void:
	used_population = maxi(0, used_population - cost)
	population_changed.emit()
