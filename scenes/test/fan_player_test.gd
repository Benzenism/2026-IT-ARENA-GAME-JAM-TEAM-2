extends Node2D
## Test-only setup in the same World2D viewed by both player cameras.

const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const CAMERA: FanClubData = preload("res://data/fanclubs/camera_fan.tres")
const PLACEHOLDER: Texture2D = preload("res://icon.svg")
const BATON_SCENE: PackedScene = preload("res://scenes/gameplay/baton.tscn")
const MATCH_DURATION := 240.0

var teams: Array[TeamController] = []
var players: Array[IdolPlayer] = []
var stages: Array[IdolStage] = []
var fans: Node2D
var projectiles: ProjectileSpawner
var match_time_left := MATCH_DURATION
var sudden_death := false
var game_over := false
var winner_team := 0
var carrying_sources: Dictionary = {}
var dropped_batons: Array[CaptureBaton] = []
var ui_connected := false


func _enter_tree() -> void:
	# Field builds its collision walls in _ready(), so set its size first.
	(get_parent().get_node("Field") as Field).size = Vector2(2200, 1200)


func _ready() -> void:
	var world := get_parent()
	var field := world.get_node("Field") as Field
	players = [
		world.get_node("Player1") as IdolPlayer,
		world.get_node("Player2") as IdolPlayer
	]
	var bounds := field.get_field_rect()
	stages = [
		world.get_node("Stage1") as IdolStage,
		world.get_node("Stage2") as IdolStage
	]
	for stage in stages:
		stage.idol_entered.connect(_on_stage_idol_entered)
	for player in players:
		player.baton_dropped.connect(_on_baton_dropped)
		player.health_changed.connect(_on_player_health_changed.bind(player))
		player.set_own_stage(stages[player.team_id - 1].global_position, 220.0)
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
		if i == 0:
			team.owned_clubs.append(NORMAL)
			team.owned_clubs.append(CAMERA)
		else:
			team.owned_clubs.append(ANTI)
		team.enemy_player = players[1 - i]
		team.fan_container = fans
		team.projectile_spawner = projectiles
		team.arena_rect = bounds
		team.fan_spawned.connect(_on_fan_spawned)
		add_child(team)
		teams.append(team)
		team.try_spawn()
		team.try_spawn()
	add_to_group("game_controller")
	call_deferred("_connect_ui")


func _on_fan_spawned(fan: Fan) -> void:
	# Use the existing project icon only when the club has no sprite configured.
	if fan.sprite.texture == null:
		fan.sprite.texture = PLACEHOLDER
		fan.sprite.scale = Vector2(0.36, 0.36)
		fan.sprite.modulate = Color(1, 0.55, 0.55) if fan.team_id == 1 else Color(0.55, 0.7, 1)


func _process(_delta: float) -> void:
	if not ui_connected:
		_connect_ui()
	# Give otherwise invisible bullets a temporary marker in this test scene only.
	for bullet: FanProjectile in projectiles.get_children():
		var sprite := bullet.get_node("Sprite2D") as Sprite2D
		if sprite.texture == null:
			sprite.texture = PLACEHOLDER
			sprite.scale = Vector2(0.3, 0.3)
			sprite.modulate = Color(1, 0.55, 0.55) if bullet.team_id == 1 else Color(0.55, 0.7, 1)
	if not game_over and not sudden_death:
		match_time_left = maxf(0.0, match_time_left - _delta)
		if is_zero_approx(match_time_left):
			_resolve_time_limit()
	_update_ui()


func _on_stage_idol_entered(idol: IdolPlayer, stage: IdolStage) -> void:
	if game_over:
		return
	if idol.carried_club != null:
		if idol.team_id == stage.team_id:
			_complete_capture(idol)
		return
	if idol.team_id == stage.team_id:
		return
	var defending_team := _team(stage.team_id)
	if defending_team.owned_clubs.is_empty():
		_finish_game(idol.team_id)
		return
	var menu := _menu(idol.team_id)
	if menu == null or menu.active:
		return
	idol.set_movement_locked(true)
	menu.open_menu(defending_team.owned_clubs)


func _on_capture_confirmed(team_id: int, club: FanClubData) -> void:
	if game_over:
		return
	var idol := _player(team_id)
	var source_team_id := 3 - team_id
	if idol == null or idol.carried_club != null or not _team(source_team_id).owned_clubs.has(club):
		return
	idol.set_movement_locked(false)
	idol.start_carrying(club)
	carrying_sources[idol] = source_team_id


func _on_baton_dropped(idol: IdolPlayer, club: FanClubData, position: Vector2) -> void:
	var source_team_id: int = carrying_sources.get(idol, 3 - idol.team_id)
	carrying_sources.erase(idol)
	var baton := BATON_SCENE.instantiate() as CaptureBaton
	baton.position = position
	baton.picked_up.connect(_on_baton_picked_up)
	baton.returned.connect(_on_baton_returned)
	get_parent().add_child(baton)
	baton.setup(club, source_team_id, idol.team_id)
	dropped_batons.append(baton)


func _on_baton_picked_up(baton: CaptureBaton, idol: IdolPlayer) -> void:
	if game_over or idol.carried_club != null:
		return
	_remove_dropped_baton(baton)
	idol.start_carrying(baton.club)
	carrying_sources[idol] = baton.source_team_id
	baton.queue_free()


func _on_baton_returned(baton: CaptureBaton) -> void:
	_remove_dropped_baton(baton)
	baton.queue_free()


func _complete_capture(idol: IdolPlayer) -> void:
	var club: FanClubData = idol.finish_carrying()
	var target_team_id := idol.team_id
	var source_team_id: int = carrying_sources.get(idol, 3 - target_team_id)
	carrying_sources.erase(idol)
	var source_team := _team(source_team_id)
	var target_team := _team(target_team_id)
	source_team.owned_clubs.erase(club)
	if not target_team.owned_clubs.has(club):
		target_team.owned_clubs.append(club)
	for fan: Fan in get_tree().get_nodes_in_group("fans"):
		if fan.team_id == source_team_id and fan.club == club:
			fan.change_team(target_team_id, _player(source_team_id))
	if sudden_death or source_team.owned_clubs.is_empty():
		_finish_game(target_team_id)


func _resolve_time_limit() -> void:
	var player_one_count := teams[0].owned_clubs.size()
	var player_two_count := teams[1].owned_clubs.size()
	if player_one_count == player_two_count:
		sudden_death = true
	elif player_one_count > player_two_count:
		_finish_game(1)
	else:
		_finish_game(2)


func _finish_game(team_id: int) -> void:
	if game_over:
		return
	game_over = true
	winner_team = team_id
	for player in players:
		player.set_movement_locked(true)
	for menu: CaptureMenu in get_tree().get_nodes_in_group("capture_menus"):
		menu.close_menu()


func _on_player_health_changed(_current_hp: int, _maximum_hp: int,
		player: IdolPlayer) -> void:
	var menu := _menu(player.team_id)
	if menu != null and menu.active:
		menu.close_menu()
		player.set_movement_locked(false)


func _update_ui() -> void:
	for team_id in [1, 2]:
		var team := _team(team_id)
		team._sync_population()
		var player := _player(team_id)
		for hud: PlayerHud in get_tree().get_nodes_in_group("player_huds"):
			if hud.team_id == team_id:
				hud.set_match_state(match_time_left, sudden_death, game_over, winner_team)
				hud.set_player_state(player.hp, player.max_hp, team.owned_clubs,
					team.used_population, 16)


func _remove_dropped_baton(baton: CaptureBaton) -> void:
	dropped_batons.erase(baton)


func _team(team_id: int) -> TeamController:
	return teams[team_id - 1]


func _player(team_id: int) -> IdolPlayer:
	return players[team_id - 1]


func _connect_ui() -> void:
	if ui_connected:
		return
	var menus := get_tree().get_nodes_in_group("capture_menus")
	if menus.is_empty():
		return
	for menu: CaptureMenu in menus:
		menu.confirmed.connect(_on_capture_confirmed)
	ui_connected = true


func _menu(team_id: int) -> CaptureMenu:
	for menu: CaptureMenu in get_tree().get_nodes_in_group("capture_menus"):
		if menu.team_id == team_id:
			return menu
	return null
