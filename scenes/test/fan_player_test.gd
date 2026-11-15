extends Node2D
## Test-only setup in the same World2D viewed by both player cameras.

const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const DIAGONAL: FanClubData = preload("res://data/fanclubs/diagonal_fan.tres")
const VERTICAL: FanClubData = preload("res://data/fanclubs/vertical_fan.tres")
const CAMERA: FanClubData = preload("res://data/fanclubs/camera_fan.tres")
const GUARD: FanClubData = preload("res://data/fanclubs/guard_fan.tres")
const ALL_CLUBS: Array[FanClubData] = [NORMAL, ANTI, DIAGONAL, VERTICAL, CAMERA, GUARD]
const BATON_SCENE: PackedScene = preload("res://scenes/gameplay/baton.tscn")
const MATCH_DURATION := 120.0
const STAGE_OSCILLATION_AMPLITUDE := 400.0
const STAGE_OSCILLATION_PERIOD := 30.0
const STAGE_HORIZONTAL_AMPLITUDE := 100.0
const STAGE_ROTATION_PERIOD := 30.0

var teams: Array[TeamController] = []
var players: Array[IdolPlayer] = []
var stages: Array[IdolStage] = []
var stage_base_positions: Array[Vector2] = []
var fans: Node2D
var projectiles: ProjectileSpawner
var match_time_left := MATCH_DURATION
var sudden_death := false
var game_over := false
var winner_team := 0
var carrying_sources: Dictionary = {}
var dropped_batons: Array[CaptureBaton] = []
var ui_connected := false
var stage_oscillation_time := 0.0


func _enter_tree() -> void:
	# Field builds its collision walls in _ready(), so set its size first.
	(get_parent().get_node("Field") as Field).size = Vector2(4000, 2000)


func _ready() -> void:
	var scene_root := get_tree().current_scene
	var left_viewport := scene_root.get_node("Split/LeftContainer/LeftViewport") as SubViewport
	var right_viewport := scene_root.get_node("Split/RightContainer/RightViewport") as SubViewport
	right_viewport.world_2d = left_viewport.world_2d
	var world := get_parent()
	var field := world.get_node("Field") as Field
	players = [
		world.get_node("Player1") as IdolPlayer,
		world.get_node("Player2") as IdolPlayer
	]
	var bounds := field.get_field_rect()
	var movement_bounds := field.get_movement_rect()
	for obstacle: ArenaObstacle in get_tree().get_nodes_in_group("arena_obstacles"):
		obstacle.set_arena_rect(movement_bounds)
	stages = [
		world.get_node("Stage1") as IdolStage,
		world.get_node("Stage2") as IdolStage
	]
	for stage in stages:
		stage_base_positions.append(stage.position)
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
	var distributed_clubs := _randomize_team_clubs()
	for i in range(2):
		var team := TeamController.new()
		team.name = "Team%d" % (i + 1)
		team.team_id = i + 1
		for club in distributed_clubs[i]:
			team.owned_clubs.append(club)
		team.ally_player = players[i]
		team.enemy_player = players[1 - i]
		team.fan_container = fans
		team.projectile_spawner = projectiles
		team.arena_rect = bounds
		team.spawn_center = stages[i].global_position
		add_child(team)
		teams.append(team)
		for _attempt in team.population_limit:
			if team.try_spawn() == null:
				break
	add_to_group("game_controller")
	call_deferred("_connect_ui")


func _physics_process(delta: float) -> void:
	if stages.is_empty():
		return
	stage_oscillation_time = fmod(stage_oscillation_time + delta, STAGE_OSCILLATION_PERIOD)
	var progress := stage_oscillation_time / STAGE_OSCILLATION_PERIOD
	var vertical_offset := sin(progress * TAU) * STAGE_OSCILLATION_AMPLITUDE
	for index in range(stages.size()):
		var horizontal_direction := 1.0 if index == 0 else -1.0
		var horizontal_offset := horizontal_direction * absf(cos(progress * TAU)) \
				* STAGE_HORIZONTAL_AMPLITUDE
		stages[index].position = stage_base_positions[index] \
				+ Vector2(horizontal_offset, vertical_offset)
		stages[index].sprite.rotation = stage_oscillation_time \
				/ STAGE_ROTATION_PERIOD * TAU
		players[index].set_own_stage(stages[index].global_position, 220.0)
		if index < teams.size():
			teams[index].spawn_center = stages[index].global_position


func _randomize_team_clubs() -> Array:
	var shuffled_clubs := ALL_CLUBS.duplicate()
	shuffled_clubs.shuffle()
	var teams_clubs: Array = [[], []]
	for index in range(shuffled_clubs.size()):
		teams_clubs[index % 2].append(shuffled_clubs[index])
	if teams_clubs[0].is_empty():
		teams_clubs[0].append(teams_clubs[1].pop_back())
	if teams_clubs[1].is_empty():
		teams_clubs[1].append(teams_clubs[0].pop_back())
	return teams_clubs


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()
		return
	if not ui_connected:
		_connect_ui()
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
	if _has_dropped_baton(idol):
		return
	var selected_club: FanClubData = defending_team.owned_clubs.pick_random()
	_on_capture_confirmed(idol.team_id, selected_club)


func _has_dropped_baton(idol: IdolPlayer) -> bool:
	for baton in dropped_batons:
		if is_instance_valid(baton) and baton.dropper == idol:
			return true
	return false


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
	call_deferred("_spawn_dropped_baton", idol, club, position, source_team_id)


func _spawn_dropped_baton(idol: IdolPlayer, club: FanClubData, position: Vector2,
		source_team_id: int) -> void:
	var baton := BATON_SCENE.instantiate() as CaptureBaton
	baton.dropper = idol
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
	if is_instance_valid(baton.dropper):
		call_deferred("_recheck_capture_stage", baton.dropper)


func _recheck_capture_stage(idol: IdolPlayer) -> void:
	if not is_instance_valid(idol) or not idol.is_inside_tree():
		return
	for stage in stages:
		if stage.team_id != idol.team_id and stage.get_overlapping_bodies().has(idol):
			_on_stage_idol_entered(idol, stage)
			return


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
	# 팬 쟁탈 컷인 (재생되는 약 1.4초 동안 게임 일시정지)
	get_tree().call_group("steal_cutin", "play_steal", target_team_id)
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
	# 경기 종료 연출 (GAME SET → 승리/패배 → 다시하기/타이틀로)
	var winner := _team(team_id)
	winner._sync_population()
	get_tree().call_group("result_screen", "play_result", team_id,
		teams[0].owned_clubs.size(), teams[1].owned_clubs.size(), winner.used_population, sudden_death)


func _on_player_health_changed(_current_hp: int, _maximum_hp: int,
		player: IdolPlayer) -> void:
	var menu := _menu(player.team_id)
	if menu != null and menu.active:
		menu.close_menu()
		player.set_movement_locked(false)


func _update_ui() -> void:
	_update_match_timer()
	for team_id in [1, 2]:
		var team := _team(team_id)
		team._sync_population()
		var player := _player(team_id)
		for hud: PlayerHud in get_tree().get_nodes_in_group("player_huds"):
			if hud.team_id == team_id:
				hud.set_match_state(match_time_left, sudden_death, game_over, winner_team)
				hud.set_player_state(player.hp, player.max_hp, team.owned_clubs,
					team.used_population, team.population_limit)


func _update_match_timer() -> void:
	var timer_label := get_tree().get_first_node_in_group("match_timer") as Label
	if timer_label == null:
		return
	if sudden_death:
		timer_label.text = "SUDDEN DEATH"
	else:
		var seconds := maxi(0, ceili(match_time_left))
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]


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
