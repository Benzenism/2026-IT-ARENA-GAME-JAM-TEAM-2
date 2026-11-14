extends SceneTree
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/enemy_system_test.gd

const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const FAN_SCENE: PackedScene = preload("res://scenes/fan/fan.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const BULLET_SCENE: PackedScene = preload("res://scenes/projectile/normal_bullet.tscn")
const LAB_SCENE: PackedScene = preload("res://scenes/demo/enemy_lab.tscn")
const BOUNDS := Rect2(0, 0, 1400, 900)

var failures: int = 0
var checks: int = 0
var fixture: Node2D
var spawner: ProjectileSpawner


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _new_fixture()
	_test_patterns_and_isolation()
	await _new_fixture()
	_test_lifecycle()
	await _new_fixture()
	_test_population()
	await _new_fixture()
	await _test_collision()
	await _new_fixture()
	await _test_projectile_lifecycle()
	await _new_fixture()
	await _test_player_respawn_and_target_loss()
	await _new_fixture()
	await _test_lab_and_battle()
	fixture.queue_free()
	await process_frame
	print("Enemy system: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _new_fixture() -> void:
	if is_instance_valid(fixture):
		fixture.queue_free()
		await process_frame
	fixture = Node2D.new()
	root.add_child(fixture)
	spawner = ProjectileSpawner.new()
	fixture.add_child(spawner)


func _fan(club: FanClubData, team: int = 1, pos := Vector2(150, 300),
		target: PrototypePlayer = null) -> Fan:
	var fan := FAN_SCENE.instantiate() as Fan
	fan.club = club
	fan.team_id = team
	fan.enemy_player = target
	fan.arena_rect = BOUNDS
	fan.position = pos
	fan.shoot_requested.connect(spawner.request_shot)
	fixture.add_child(fan)
	fan.set_physics_process(false)
	fan.attack_timer.stop()
	return fan


func _player(team: int, pos: Vector2) -> PrototypePlayer:
	var player := PLAYER_SCENE.instantiate() as PrototypePlayer
	player.team_id = team
	player.input_enabled = false
	player.position = pos
	player.spawn_position = pos
	player.arena_rect = BOUNDS
	fixture.add_child(player)
	return player


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func _test_patterns_and_isolation() -> void:
	var target := _player(2, Vector2(600, 500))
	var normal := _fan(NORMAL, 1, Vector2(100, 300), target)
	var reverse := _fan(NORMAL, 2)
	var anti := _fan(ANTI, 1, Vector2(100, 300), target)
	_check(normal.movement.get_direction(normal) == Vector2.RIGHT, "P1 normal moves right")
	_check(reverse.movement.get_direction(reverse) == Vector2.LEFT, "P2 normal moves left")
	var aim := normal.global_position.direction_to(target.global_position)
	_check(anti.movement.get_direction(anti).is_equal_approx(aim), "Anti tracks the opponent")
	var normal_shots: Array[Vector2] = []
	var anti_shots: Array[Vector2] = []
	normal.shoot_requested.connect(func(_scene, _pos, direction, _team, _bounds):
		normal_shots.append(direction))
	anti.shoot_requested.connect(func(_scene, _pos, direction, _team, _bounds):
		anti_shots.append(direction))
	normal.attack.fire(normal)
	anti.attack.fire(anti)
	_check(normal_shots.size() == 1 and normal_shots[0] == Vector2.RIGHT,
		"Normal fires forward regardless of target location")
	_check(anti_shots.size() == 1 and anti_shots[0].is_equal_approx(aim),
		"Anti aims at the current target position")
	target.position = Vector2(100, 330)
	_check(anti.movement.get_direction(anti) == Vector2.ZERO, "Anti keeps its stopping distance")
	normal.take_damage(1)
	_check(normal.hp == 2 and reverse.hp == 3 and NORMAL.max_hp == 3,
		"Damage is per-instance and never mutates shared club data")


func _test_lifecycle() -> void:
	var fan := _fan(ANTI)
	var events: Array[int] = [0, 0, 0]
	fan.died.connect(func(): events[0] += 1)
	fan.despawned.connect(func(cost):
		events[1] += 1
		events[2] += cost)
	fan.take_damage(99)
	fan.take_damage(99)
	fan.die()
	fan.exit_map()
	_check(events == [1, 1, 2], "Death/despawn and population refund occur exactly once")
	var exiting := _fan(NORMAL)
	var exit_events: Array[int] = [0, 0]
	exiting.died.connect(func(): exit_events[0] += 1)
	exiting.despawned.connect(func(_cost): exit_events[1] += 1)
	exiting.exit_map()
	exiting.exit_map()
	_check(exit_events == [0, 1], "Map removal does not trigger death abilities")


func _test_population() -> void:
	var team := TeamController.new()
	team.owned_clubs = [ANTI, NORMAL]
	team.population_limit = 4
	team.fan_container = fixture
	team.projectile_spawner = spawner
	team.arena_rect = BOUNDS
	fixture.add_child(team)
	team.spawn_timer.stop()
	var first := team.try_spawn()
	var second := team.try_spawn()
	var third := team.try_spawn()
	_check(first.club == ANTI and second.club == NORMAL and third.club == NORMAL,
		"Round robin skips an unaffordable club and uses remaining capacity")
	_check(team.used_population == 4 and team.try_spawn() == null, "Population cap is enforced")
	first.die()
	first.exit_map()
	_check(team.used_population == 2, "Cost-2 fan refunds exactly two population once")
	_check(team.try_spawn() != null and team.used_population == 4, "Freed capacity can be reused")
	team.owned_clubs.clear()
	_check(team.try_spawn() == null, "An empty club list is safe")
	team.owned_clubs = [null, NORMAL]
	_check(team.try_spawn() == null and team.used_population == 4, "Null clubs cannot bypass the cap")
	second.exit_map()
	var replacement := team.try_spawn()
	_check(replacement != null and replacement.club == NORMAL,
		"Future spawns follow a changed owned-club list")


func _test_collision() -> void:
	var friend := _fan(NORMAL, 1, Vector2(290, 400))
	var enemy := _fan(ANTI, 2, Vector2(430, 400))
	spawner.request_shot(BULLET_SCENE, Vector2(200, 400), Vector2.RIGHT, 1, BOUNDS)
	await _frames(70)
	_check(friend.hp == NORMAL.max_hp, "Real physics: bullets pass through friendly fans")
	_check(enemy.hp == ANTI.max_hp - 1, "Real physics: an enemy fan takes one hit")
	_check(spawner.get_child_count() == 0, "A hit consumes the projectile")
	friend.position = Vector2(800, 700)
	enemy.position = Vector2(850, 700)
	var friendly_player := _player(1, Vector2(290, 400))
	var enemy_player := _player(2, Vector2(430, 400))
	spawner.request_shot(BULLET_SCENE, Vector2(200, 400), Vector2.RIGHT, 1, BOUNDS)
	await _frames(70)
	_check(friendly_player.hp == friendly_player.max_hp, "Friendly players take no friendly fire")
	_check(enemy_player.hp == enemy_player.max_hp - 1, "Enemy players take projectile damage")
	var hp_before := enemy_player.hp
	var bullet := BULLET_SCENE.instantiate() as FanProjectile
	bullet.position = Vector2(1100, 100)
	fixture.add_child(bullet)
	enemy_player.invulnerability = 0
	bullet._on_body_entered(enemy_player)
	bullet._on_body_entered(enemy_player)
	_check(enemy_player.hp == hp_before - 1, "Multiple overlap callbacks cannot damage twice")


func _test_projectile_lifecycle() -> void:
	var shooter := _fan(NORMAL, 1, Vector2(100, 200))
	shooter.shoot(Vector2.RIGHT)
	shooter.die()
	await _frames(3)
	_check(spawner.get_child_count() == 1, "A shot survives its shooter being freed")
	var shot := spawner.get_child(0) as FanProjectile
	var before := shot.direction
	await _frames(3)
	_check(shot.direction == before, "Projectiles keep their direction after firing")
	shot.lifetime = 0.01
	await _frames(3)
	_check(spawner.get_child_count() == 0, "Expired projectiles are removed")
	spawner.request_shot(BULLET_SCENE, Vector2(BOUNDS.end.x + 40, 200), Vector2.RIGHT, 1, BOUNDS)
	await _frames(3)
	_check(spawner.get_child_count() == 0, "Out-of-bounds projectiles are removed")
	var leaving := _fan(NORMAL, 1, Vector2(BOUNDS.end.x + 30, 100))
	var map_events: Array[int] = [0, 0]
	leaving.died.connect(func(): map_events[0] += 1)
	leaving.despawned.connect(func(_cost): map_events[1] += 1)
	leaving.set_physics_process(true)
	await _frames(3)
	_check(not is_instance_valid(leaving) and map_events == [0, 1],
		"A fan outside the arena despawns without dying")


func _test_player_respawn_and_target_loss() -> void:
	var target := _player(2, Vector2(700, 400))
	var anti := _fan(ANTI, 1, Vector2(300, 300), target)
	target.position = Vector2(750, 420)
	target.take_damage(999)
	_check(not anti.has_active_target(), "Respawning players are not active targets")
	_check(anti.movement.get_direction(anti) == Vector2.RIGHT, "Anti advances while its target is down")
	await _frames(100)
	_check(target.hp == target.max_hp and target.position == target.spawn_position,
		"Players respawn at their starting point with restored HP")
	_check(anti.has_active_target(), "Anti reacquires the respawned player")
	target.queue_free()
	await _frames(2)
	_check(not anti.has_active_target() and anti.movement.get_direction(anti) == Vector2.RIGHT,
		"A freed target is handled safely")
	anti.attack.fire(anti)


func _test_lab_and_battle() -> void:
	var lab := LAB_SCENE.instantiate()
	fixture.add_child(lab)
	await _frames(3)
	_check(lab.examples.size() == 2, "The entry scene shows exactly the two requested clubs")
	lab._damage_example(0)
	_check(lab.examples[0].fan.hp == NORMAL.max_hp - 1, "The example damage button reaches the fan")
	lab._toggle_target()
	_check(not lab.examples[0].move_target and not lab.examples[1].move_target,
		"Target movement can be switched off for comparison")
	lab._toggle_pause()
	var fan_position: Vector2 = lab.examples[0].fan.position
	await _frames(90)
	_check(lab.examples[0].fan.position == fan_position, "Pause freezes the simulation")
	lab._show_mode(1)
	await _frames(3)
	var cap_ok: bool = true
	var accounting_ok: bool = true
	for i in range(1200):
		await physics_frame
		var living_costs: Array[int] = [0, 0]
		for fan: Fan in lab.battle.fans.get_children():
			if not fan.is_despawning:
				living_costs[fan.team_id - 1] += fan.club.population_cost
		for team: TeamController in lab.battle.teams:
			cap_ok = cap_ok and team.used_population <= 16 and team.used_population >= 0
			accounting_ok = accounting_ok and team.used_population == living_costs[team.team_id - 1]
	_check(cap_ok, "Both teams stay within the population cap during 20 seconds of combat")
	_check(accounting_ok, "Population matches live costs throughout combat and deaths")
	_check(lab.battle.teams[0].spawn_count > 2 and lab.battle.teams[1].spawn_count > 2,
		"Both teams automatically spawn both clubs")
	Input.action_press("p1_right")
	var start: Vector2 = lab.battle.players[0].position
	await _frames(4)
	Input.action_release("p1_right")
	_check(lab.battle.players[0].position.x > start.x, "P1 responds to its movement input")
	Input.action_press("p2_left")
	start = lab.battle.players[1].position
	await _frames(4)
	Input.action_release("p2_left")
	_check(lab.battle.players[1].position.x < start.x, "P2 responds to its movement input")
	lab._show_mode(0)
	await _frames(3)
	_check(lab.world.get_child_count() == 2, "Switching back removes the old battle")
