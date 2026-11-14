extends Node2D
## Entry point: two live club examples and an optional local combat sandbox.

const NORMAL: FanClubData = preload("res://data/fanclubs/normal_fan.tres")
const ANTI: FanClubData = preload("res://data/fanclubs/anti_fan.tres")
const CARDS: Array[Rect2] = [Rect2(32, 176, 672, 572), Rect2(736, 176, 672, 572)]

var world: Node2D
var content: Control
var ui: Control
var examples: Array[FanExample] = []
var battle: BattleDemo
var mode: int = 0
var paused: bool = false
var target_moving: bool = true
var metrics: Array[Label] = []
var population_labels: Array[Label] = []
var health_labels: Array[Label] = []
var status_label: Label
var pause_button: Button
var target_button: Button
var gallery_tab: Button
var battle_tab: Button
var preview_path: String = ""
var preview_elapsed: float = 0


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	LabUI.label(ui, "MAGICAL IDOLS  /  ENEMY SYSTEM", Vector2(36, 20), Vector2(640, 22),
		12, LabUI.CYAN)
	LabUI.label(ui, "팬클럽 실험실", Vector2(32, 45), Vector2(700, 47), 34)
	LabUI.label(ui, "일반팬과 안티팬, 두 가지 행동을 직접 확인해 보세요.",
		Vector2(36, 101), Vector2(850, 28), 15, LabUI.MUTED)
	gallery_tab = LabUI.button(ui, "01  패턴 비교", Vector2(1032, 52), Vector2(176, 44))
	gallery_tab.pressed.connect(_show_mode.bind(0))
	battle_tab = LabUI.button(ui, "02  2인 전장", Vector2(1220, 52), Vector2(188, 44))
	battle_tab.pressed.connect(_show_mode.bind(1))
	status_label = LabUI.label(ui, "", Vector2(50, 140), Vector2(1300, 25), 13, LabUI.MINT)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(content)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-preview="):
			preview_path = arg.trim_prefix("--capture-preview=")
	mode = 1 if OS.get_cmdline_user_args().has("--battle") else 0
	_show_mode(mode)


func _show_mode(next_mode: int) -> void:
	paused = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	examples.clear()
	metrics.clear()
	population_labels.clear()
	health_labels.clear()
	battle = null
	mode = next_mode
	gallery_tab.disabled = mode == 0
	battle_tab.disabled = mode == 1
	gallery_tab.add_theme_stylebox_override("disabled", LabUI.panel(
		Color("183248") if mode == 0 else Color("162136"), LabUI.CYAN))
	battle_tab.add_theme_stylebox_override("disabled", LabUI.panel(
		Color("183248") if mode == 1 else Color("162136"), LabUI.CYAN))
	if mode == 0:
		_create_gallery()
	else:
		_create_battle()
	_create_footer()
	_update_status()
	queue_redraw()


func _create_gallery() -> void:
	var clubs: Array[FanClubData] = [NORMAL, ANTI]
	for i in range(2):
		var card := CARDS[i]
		var pos := card.position
		var club := clubs[i]
		LabUI.label(content, "FAN CLUB  /  0%d" % (i + 1), pos + Vector2(24, 14),
			Vector2(500, 20), 11, club.accent)
		LabUI.label(content, club.display_name, pos + Vector2(24, 37),
			Vector2(470, 43), 28)
		LabUI.label(content, "BASIC" if i == 0 else "CHASER", pos + Vector2(545, 44),
			Vector2(110, 30), 13, club.accent)
		LabUI.label(content, club.description, pos + Vector2(24, 86),
			Vector2(630, 58), 15, LabUI.MUTED)
		var stat_texts := ["HP  %d" % club.max_hp, "이속  %d" % int(club.move_speed),
			"인구  %d" % club.population_cost, "공격  %.1f초" % club.attack_interval]
		for j in range(4):
			var stat_pos := pos + Vector2(24 + j * 155, 149)
			var pill := Panel.new()
			pill.position = stat_pos
			pill.size = Vector2(142, 34)
			pill.add_theme_stylebox_override("panel", LabUI.panel(Color("19253a"),
				Color("2a3952"), 8))
			content.add_child(pill)
			LabUI.label(content, stat_texts[j], stat_pos + Vector2(12, 3),
				Vector2(130, 27), 13, LabUI.TEXT)
		var example := FanExample.new()
		example.club = club
		example.bounds = Rect2(pos + Vector2(20, 201), Vector2(632, 222))
		example.move_target = target_moving
		example.show_aim_line = i == 1
		world.add_child(example)
		examples.append(example)
		LabUI.label(content, "LIVE PREVIEW", pos + Vector2(35, 210),
			Vector2(180, 24), 10, LabUI.MUTED)
		LabUI.label(content, "팬", pos + Vector2(68, 390), Vector2(80, 21), 11, club.accent)
		LabUI.label(content, "움직이는 상대 표적", pos + Vector2(487, 390),
			Vector2(160, 21), 11, LabUI.PINK)
		LabUI.label(content, "이동", pos + Vector2(24, 438), Vector2(70, 27), 13, club.accent)
		LabUI.label(content, club.movement_label, pos + Vector2(87, 438),
			Vector2(550, 27), 14)
		LabUI.label(content, "공격", pos + Vector2(24, 469), Vector2(70, 27), 13, club.accent)
		LabUI.label(content, club.attack_label, pos + Vector2(87, 469),
			Vector2(550, 27), 14)
		var reset := LabUI.button(content, "팬 재생성", pos + Vector2(24, 518),
			Vector2(137, 34), club.accent)
		reset.pressed.connect(example.restart)
		var damage := LabUI.button(content, "피해 1 주기", pos + Vector2(173, 518),
			Vector2(145, 34), club.accent)
		damage.pressed.connect(_damage_example.bind(i))
		metrics.append(LabUI.label(content, "", pos + Vector2(338, 522),
			Vector2(320, 25), 12, LabUI.MUTED))


func _create_battle() -> void:
	battle = BattleDemo.new()
	world.add_child(battle)
	for i in range(2):
		var x := 48 if i == 0 else 780
		var color := LabUI.CYAN if i == 0 else LabUI.PINK
		LabUI.label(content, "P%d" % (i + 1), Vector2(x, 182), Vector2(60, 40), 27, color)
		LabUI.label(content, "W A S D" if i == 0 else "방향키 ↑ ↓ ← →",
			Vector2(x + 70, 191), Vector2(250, 30), 15, LabUI.MUTED)
		population_labels.append(LabUI.label(content, "", Vector2(x + 350, 184),
			Vector2(285, 34), 18, color))
		health_labels.append(LabUI.label(content, "", Vector2(60 + i * 728, 714),
			Vector2(560, 31), 15, color))
	LabUI.label(content, "P1 BASE", Vector2(66, 250), Vector2(140, 25), 11, LabUI.CYAN)
	LabUI.label(content, "P2 BASE", Vector2(1268, 250), Vector2(140, 25), 11, LabUI.PINK)
	LabUI.label(content, "일반팬 · 직진 / 안티팬 · 상대 추적     |     양 진영이 번갈아 자동 생성합니다.",
		Vector2(48, 756), Vector2(1344, 29), 14, LabUI.MUTED)


func _create_footer() -> void:
	pause_button = LabUI.button(content, "일시정지", Vector2(32, 800), Vector2(152, 42))
	pause_button.pressed.connect(_toggle_pause)
	var reset := LabUI.button(content, "전체 다시 시작", Vector2(196, 800), Vector2(178, 42))
	reset.pressed.connect(_show_mode.bind(mode))
	if mode == 0:
		target_button = LabUI.button(content, "", Vector2(386, 800), Vector2(190, 42), LabUI.PINK)
		target_button.pressed.connect(_toggle_target)
		_update_target_button()
		LabUI.label(content, "표적은 자동으로 이동합니다. 피해 버튼으로 사망과 재생성을 확인하세요.",
			Vector2(604, 808), Vector2(810, 30), 13, LabUI.MUTED)
	else:
		LabUI.label(content, "P1: WASD  ·  P2: 방향키     |     HP 0 → 1.5초 후 리스폰     |     진영별 인구 상한 16",
			Vector2(408, 808), Vector2(1000, 30), 14, LabUI.MUTED)
	LabUI.label(content, "PROTOTYPE  01", Vector2(34, 867), Vector2(200, 22), 10, LabUI.MUTED)
	LabUI.label(content, "민트 = 일반팬    /    보라 = 안티팬    /    하늘·분홍 고리와 탄환 = 진영",
		Vector2(634, 864), Vector2(790, 25), 12, LabUI.MUTED)


func _process(delta: float) -> void:
	if mode == 0:
		for i in range(examples.size()):
			var example := examples[i]
			var fan_hp := example.fan.hp if is_instance_valid(example.fan) else 0
			metrics[i].text = "팬 HP %d/%d   ·   발사 %02d" % [fan_hp,
				example.club.max_hp, example.shots_fired]
	elif is_instance_valid(battle):
		for i in range(battle.teams.size()):
			var team := battle.teams[i]
			var player := battle.players[i]
			population_labels[i].text = "인구 %02d / %02d" % [team.used_population, team.population_limit]
			health_labels[i].text = ("P%d  ·  HP %d/%d   ·   리스폰 %d회" %
				[i + 1, player.hp, player.max_hp, player.deaths]) if player.is_combat_active() else \
				"P%d  ·  %.1f초 후 시작점에서 리스폰" % [i + 1, player.respawn_remaining]
	if not preview_path.is_empty():
		preview_elapsed += delta
		if preview_elapsed >= 4.0:
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			var result := screenshot.save_png(preview_path)
			print("Preview saved: ", preview_path, " (", result, ")")
			preview_path = ""
			if OS.get_cmdline_user_args().has("--quit-after-preview"):
				get_tree().quit(result)


func _damage_example(index: int) -> void:
	if is_instance_valid(examples[index].fan):
		examples[index].fan.take_damage(1)


func _toggle_pause() -> void:
	paused = not paused
	world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	pause_button.text = "계속 재생" if paused else "일시정지"
	_update_status()
	queue_redraw()


func _toggle_target() -> void:
	target_moving = not target_moving
	for example in examples:
		example.move_target = target_moving
	_update_target_button()


func _update_target_button() -> void:
	target_button.text = "표적 멈추기" if target_moving else "표적 움직이기"


func _update_status() -> void:
	status_label.text = ("PAUSED  ·  일시정지" if paused else "LIVE  ·  자동 재생 중") + \
		("     /     같은 팬 씬 · 다른 행동 컴포넌트" if mode == 0 else \
		"     /     자동 생성 · 피격 · 리스폰 · 인구수 테스트")
	status_label.modulate = Color.WHITE if not paused else Color("f5d58b")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 900), Color("090f1c"))
	draw_circle(Vector2(1340, -120), 450, Color("0b1728"))
	draw_circle(Vector2(1460, -120), 390, Color("10172b"))
	draw_line(Vector2(32, 126), Vector2(1408, 126), Color("253149"), 1)
	draw_circle(Vector2(38, 154), 3, LabUI.MINT if not paused else Color("f5d58b"))
	draw_line(Vector2(32, 854), Vector2(1408, 854), Color("253149"), 1)
	if mode == 0:
		for i in range(2):
			var card := CARDS[i]
			var accent := LabUI.MINT if i == 0 else LabUI.LILAC
			draw_style_box(LabUI.panel(Color("111b2d"), Color("29354c"), 18), card)
			draw_line(card.position + Vector2(24, 0), card.position + Vector2(100, 0),
				accent, 2, true)
			draw_line(card.position + Vector2(24, 506), card.position + Vector2(648, 506),
				Color("29354c"), 1)
