@tool
class_name ResultScreen
extends Control
## Figma "Final Result" — 경기 종료 연출.
## 1 Game Set(0.00s) → 2 Slash(1.00s): 승자/패자 패널이 양쪽에서 들어오며 사선으로 갈라짐
## → 3 Result(1.35s~): VICTORY / DEFEAT, 점수, 다시하기 / 타이틀로.
## URI(P1)가 이기면 승자 패널이 왼쪽, HANA(P2)가 이기면 좌우 반전.
## 연출이 시작되면 게임은 일시정지 (버튼만 동작).
##
## 사용: get_tree().call_group("result_screen", "play_result", winner, p1_clubs, p2_clubs, fans, sudden)

const DESIGN := Vector2(1920, 1200)
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const T_SLASH := 1.0
const T_RESULT := 1.35

const SILHOUETTE := preload("res://scenes/ui/hud/silhouette.gdshader")
const GRAYSCALE := preload("res://scenes/ui/hud/grayscale.gdshader")
const GRADIENT_TEXT := preload("res://scenes/ui/hud/gradient_text.gdshader")
const WIN_MASK := preload("res://sprites/ui/result/winner_mask.svg")
const LOSE_MASK := preload("res://sprites/ui/result/loser_mask.svg")
const RAYS := preload("res://sprites/ui/result/rays.svg")

const TEAM := {
	1: {
		"name": "URI",
		"art": preload("res://sprites/ui/cutin/uri_full.png"),
		"lose_art": preload("res://sprites/ui/result/uri_lose_full.png"),
		"flare": preload("res://sprites/ui/result/flare_uri.svg"),
		"accent": Color("4c8dff"), "light": Color("8fb4ff"), "ink": Color("0f2560"),
		"shade": Color("081638"), "watermark": Color("c9ddff"),
		"bg_stops": [[0.0, Color("8fb4ff")], [0.175, Color(0.431, 0.631, 1.0, 0.925)],
			[0.35, Color(0.298, 0.553, 1.0, 0.85)], [0.5125, Color(0.231, 0.435, 0.804, 0.6375)],
			[0.675, Color(0.165, 0.322, 0.612, 0.425)], [1.0, Color(0.031, 0.086, 0.22, 0.0)]],
		"confetti": [Color("ffd36b"), Color.WHITE, Color("8fb4ff"), Color("fff4b8"), Color("c9ddff")],
	},
	2: {
		"name": "HANA",
		"art": preload("res://sprites/ui/cutin/hana_full.png"),
		"lose_art": preload("res://sprites/ui/result/hana_lose_full.png"),
		"flare": preload("res://sprites/ui/result/flare_hana.svg"),
		"accent": Color("ff5fa8"), "light": Color("ffa6d2"), "ink": Color("5e1240"),
		"shade": Color("2e0820"), "watermark": Color("ffd6ea"),
		"bg_stops": [[0.0, Color("ffa6d2")], [0.175, Color(1.0, 0.529, 0.761, 0.925)],
			[0.35, Color(1.0, 0.373, 0.659, 0.85)], [0.5125, Color(0.804, 0.263, 0.51, 0.6375)],
			[0.675, Color(0.6, 0.145, 0.384, 0.425)], [1.0, Color(0.18, 0.031, 0.125, 0.0)]],
		"confetti": [Color("ffd36b"), Color.WHITE, Color("ffa6d2"), Color("fff4b8"), Color("ffd6ea")],
	},
}

var _playing := false
var _winner := 1
var _stage: Control
var _dim: ColorRect
var _flash: ColorRect
var _win_panel: Control
var _lose_panel: Control
var _slash: Control
var _game_set: Control
var _win_title: Control
var _lose_title: Control
var _bar: Control
var _retry: SlantButton
var _rays: TextureRect
var _flare: TextureRect
var _confetti: Array = []   # [node, speed, spin, sway phase]
var _rain: Array = []       # [node, speed]
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not Engine.is_editor_hint():
		add_to_group("result_screen")


func play_result(winner_team: int, p1_clubs: int, p2_clubs: int, _winner_fans: int = 0,
		_sudden: bool = false) -> void:
	if _playing or not TEAM.has(winner_team):
		return
	_playing = true
	# 마지막 쟁탈 컷인이 재생 중이면 끝난 뒤에 시작
	var cutin := get_tree().get_first_node_in_group("steal_cutin") as StealCutIn
	if cutin != null and cutin.is_playing():
		await cutin.finished
	get_tree().paused = true
	_winner = winner_team
	_build(winner_team, p1_clubs, p2_clubs)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_animate()


func _process(delta: float) -> void:
	if not _playing or not visible:
		return
	_time += delta
	if _rays:
		_rays.rotation += delta * 0.12 * (1.0 if _winner == 1 else -1.0)
	if _flare:
		var k := 1.0 + 0.04 * sin(_time * 2.2)
		_flare.scale = Vector2(k, k)
	for c in _confetti:
		var n: Control = c[0]
		n.position.y += c[1] * delta
		n.position.x += sin(_time * 2.0 + c[3]) * 18.0 * delta
		n.rotation += c[2] * delta
		if n.position.y > 1260:
			n.position.y = -40
	for r in _rain:
		var n: Control = r[0]
		n.position += Vector2(sin(deg_to_rad(12.0)), cos(deg_to_rad(12.0))) * r[1] * delta
		if n.position.y > 1260:
			n.position.y -= 1400
			n.position.x -= 1400 * tan(deg_to_rad(12.0))


# --- 구성 ----------------------------------------------------------------------

## 승자가 URI면 디자인 좌표 그대로, HANA면 좌우 반전
func _mx(x: float, w: float) -> float:
	return DESIGN.x - x - w if _winner == 2 else x


func _build(w: int, p1_clubs: int, p2_clubs: int) -> void:
	for child in get_children():
		child.free()
	_confetti.clear()
	_rain.clear()
	var l := 3 - w
	var win: Dictionary = TEAM[w]
	var lose: Dictionary = TEAM[l]

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.012, 0.039, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = DESIGN
	_stage.position = Vector2(0, (size.y - DESIGN.y) / 2.0)
	add_child(_stage)

	_win_panel = _make_winner_panel(win)
	_stage.add_child(_win_panel)
	_lose_panel = _make_loser_panel(lose)
	_stage.add_child(_lose_panel)

	_slash = SlashLine.new()
	_slash.mirror = _winner == 2
	_slash.size = DESIGN
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slash)

	_game_set = _make_game_set()
	_stage.add_child(_game_set)

	# 승리/패배 아래 설명 문구(이유, 팬클럽 수 등)는 넣지 않음 — VICTORY / DEFEAT 와 점수판만
	_win_title = _make_win_title(win)
	_stage.add_child(_win_title)
	_lose_title = _make_lose_title()
	_stage.add_child(_lose_title)
	_bar = _make_result_bar(p1_clubs, p2_clubs)
	_stage.add_child(_bar)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)


func _masked(mask_tex: Texture2D, rect: Rect2) -> TextureRect:
	# 마스크 도형 안에만 자식이 보이도록 (clip_children)
	var m := HudUi.texture_rect(mask_tex, Vector2(_mx(rect.position.x, rect.size.x), rect.position.y), rect.size)
	m.flip_h = _winner == 2
	m.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	return m


## 디자인(스테이지) 좌표 rect를 마스크 안 좌표로 바꿔 배치 (x는 승자에 따라 반전)
func _place(mask: Control, c: Control, rect: Rect2) -> void:
	c.position = Vector2(_mx(rect.position.x, rect.size.x), rect.position.y) - mask.position
	c.size = rect.size
	mask.add_child(c)


func _make_winner_panel(t: Dictionary) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = DESIGN
	var mask := _masked(WIN_MASK, Rect2(-40, -40, 1292, 1280))
	panel.add_child(mask)

	var base := ColorRect.new()
	base.color = t["shade"]
	_place(mask, base, Rect2(0, 0, 1920, 1200))
	var glow := GradientTexture2D.new()
	glow.gradient = _gradient(t["bg_stops"])
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.width = 512
	glow.height = 320
	var cx := 0.8 if _winner == 2 else 0.2
	glow.fill_from = Vector2(cx, 0.5)
	glow.fill_to = Vector2(cx + 0.4545, 0.5)
	_place(mask, HudUi.texture_rect(glow, Vector2.ZERO, Vector2.ZERO), Rect2(0, 0, 1920, 1200))

	_rays = HudUi.texture_rect(RAYS, Vector2.ZERO, Vector2.ZERO)
	_place(mask, _rays, Rect2(-1260, -1180, 3400, 3400))
	_rays.pivot_offset = Vector2(1700, 1700)

	var wm := HudUi.label(t["name"], 560, Color(t["watermark"], 0.22))
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(mask, wm, Rect2(560 - 700, 421 - 380, 1400, 760))
	wm.pivot_offset = wm.size / 2.0
	wm.rotation_degrees = -6.0

	_flare = HudUi.texture_rect(t["flare"], Vector2.ZERO, Vector2.ZERO)
	_place(mask, _flare, Rect2(-10, 80, 900, 900))
	_flare.pivot_offset = Vector2(450, 450)

	var char_rect := Rect2(155.39, 10, 569.22, 1229.6)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(mask, holder, char_rect)
	var shadow := _art(t["art"], char_rect.size)
	shadow.position = Vector2(22 if _winner == 2 else -22, 14)
	var mat := ShaderMaterial.new()
	mat.shader = SILHOUETTE
	mat.set_shader_parameter("tint", t["accent"])
	shadow.material = mat
	holder.add_child(shadow)
	holder.add_child(_art(t["art"], char_rect.size))

	# 색종이 (승자 쪽 영역 안에서 계속 떨어짐)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var palette: Array = t["confetti"]
	for i in range(58):
		var piece := ColorRect.new()
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = palette[i % palette.size()]
		piece.color = Color(col, rng.randf_range(0.75, 1.0))
		var w := rng.randf_range(10.0, 25.0)
		var h := w * rng.randf_range(0.4, 0.5)
		_place(mask, piece, Rect2(rng.randf_range(0, 1060), rng.randf_range(-40, 1200), w, h))
		piece.pivot_offset = piece.size / 2.0
		piece.rotation = rng.randf_range(0, TAU)
		_confetti.append([piece, rng.randf_range(70.0, 160.0), rng.randf_range(-3.0, 3.0), rng.randf_range(0, TAU)])
	return panel


func _make_loser_panel(t: Dictionary) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = DESIGN
	var mask := _masked(LOSE_MASK, Rect2(888, -40, 1072, 1280))
	panel.add_child(mask)

	_place(mask, HudUi.texture_rect(_v_gradient([[0.0, Color("2a2238")], [1.0, Color("0a0710")]]),
		Vector2.ZERO, Vector2.ZERO), Rect2(0, 0, 1920, 1200))

	var wm := HudUi.label(t["name"], 400, Color(1, 1, 1, 0))
	wm.label_settings.outline_size = 6
	wm.label_settings.outline_color = Color(0.78, 0.76, 0.87, 0.1)
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(mask, wm, Rect2(1500 - 700, 878 - 320, 1400, 640))
	wm.pivot_offset = wm.size / 2.0
	wm.rotation_degrees = -6.0

	# 우는 일러스트를 흑백 + 어둡게
	var art := _art(t["lose_art"], Vector2(598.92, 1032.18))
	var gray := ShaderMaterial.new()
	gray.shader = GRAYSCALE
	art.material = gray
	art.modulate = Color(0.522, 0.502, 0.6)
	_place(mask, art, Rect2(1214.69, 360, 598.92, 1032.18))

	_place(mask, HudUi.texture_rect(_v_gradient([[0.0, Color(0.039, 0.027, 0.063, 0.0)],
		[1.0, Color(0.039, 0.027, 0.063, 0.95)]]), Vector2.ZERO, Vector2.ZERO), Rect2(0, 680, 1920, 520))

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drop_tex := _v_gradient([[0.0, Color(0.788, 0.765, 0.867, 0.0)], [1.0, Color(0.788, 0.765, 0.867, 1.0)]])
	for i in range(80):
		var drop_len := rng.randf_range(55.0, 185.0)
		var drop := HudUi.texture_rect(drop_tex, Vector2.ZERO, Vector2.ZERO)
		_place(mask, drop, Rect2(rng.randf_range(820, 1980), rng.randf_range(-60, 1200), 2, drop_len))
		drop.rotation_degrees = -12.0
		drop.modulate.a = rng.randf_range(0.1, 0.28)
		_rain.append([drop, rng.randf_range(900.0, 1300.0)])

	return panel


func _make_game_set() -> Control:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -10)
	HudUi.set_rect(col, Vector2(160, 298), Vector2(1600, 380))
	col.pivot_offset = col.size / 2.0
	var title := HudUi.label("GAME SET!", 230, Color.WHITE, Color("b48cff"), Vector2(0, 12))
	title.label_settings.outline_size = 18
	title.label_settings.outline_color = Color("1a0f2e")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := HudUi.label("경기 종료", 64, Color("ffd36b"), Color("1a0f2e"), Vector2(0, 5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	return col


func _make_win_title(t: Dictionary) -> Control:
	var box_size := Vector2(1046, 512)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudUi.set_rect(box, Vector2(_mx(76.89, box_size.x), 630), box_size)
	box.pivot_offset = box_size / 2.0
	box.rotation_degrees = -6.0

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -26)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(col)

	# WINNER URI 알약
	var pill := PanelContainer.new()
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Color.WHITE
	pill_box.set_corner_radius_all(999)
	pill_box.content_margin_left = 26
	pill_box.content_margin_right = 26
	pill_box.content_margin_top = 4
	pill_box.content_margin_bottom = 4
	pill_box.shadow_color = Color(t["shade"], 0.9)
	pill_box.shadow_size = 1
	pill_box.shadow_offset = Vector2(0, 5)
	pill.add_theme_stylebox_override("panel", pill_box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 12)
	pill_row.add_child(HudUi.label("WINNER", 34, t["ink"]))
	pill_row.add_child(HudUi.label(t["name"], 34, t["accent"]))
	pill.add_child(pill_row)
	col.add_child(pill)

	var victory := HudUi.label("VICTORY", 236, Color.WHITE, t["accent"], Vector2(0, 12))
	victory.label_settings.outline_size = 14
	victory.label_settings.outline_color = Color(0.1, 0.06, 0.18, 0.9)
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.custom_minimum_size = Vector2(box_size.x, 300)
	var m := ShaderMaterial.new()
	m.shader = GRADIENT_TEXT
	m.set_shader_parameter("color_a", Color("fffdf0"))
	m.set_shader_parameter("color_b", Color("ffe28a"))
	m.set_shader_parameter("color_c", Color("ff9f3b"))
	m.set_shader_parameter("mid", 0.45)
	m.set_shader_parameter("vertical", true)
	m.set_shader_parameter("box_size", Vector2(box_size.x, 300))
	victory.material = m
	col.add_child(victory)
	return box


func _make_lose_title() -> Control:
	var box_size := Vector2(643, 353)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -14)
	HudUi.set_rect(box, Vector2(_mx(1208.53, box_size.x), 108), box_size)
	box.pivot_offset = box_size / 2.0
	box.rotation_degrees = -6.0
	var defeat := HudUi.label("DEFEAT", 150, Color("3a3248"))
	defeat.label_settings.outline_size = 8
	defeat.label_settings.outline_color = Color(0.604, 0.576, 0.698, 0.55)
	defeat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(defeat)
	return box


func _make_result_bar(p1_clubs: int, p2_clubs: int) -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 28)
	HudUi.set_rect(bar, Vector2(360, 1085), Vector2(1200, 79))

	var score := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.102, 0.059, 0.18, 0.92)
	sbox.border_color = Color.WHITE
	sbox.set_border_width_all(3)
	sbox.skew = Vector2(SlantButton.SLANT, 0)
	sbox.content_margin_left = 40
	sbox.content_margin_right = 40
	sbox.content_margin_top = 6
	sbox.content_margin_bottom = 6
	sbox.shadow_color = Color(0, 0, 0, 0.7)
	sbox.shadow_size = 1
	sbox.shadow_offset = Vector2(0, 6)
	score.add_theme_stylebox_override("panel", sbox)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 18)
	for part in [["URI", 30, Color("8fb4ff")], ["%d : %d" % [p1_clubs, p2_clubs], 44, Color.WHITE],
			["HANA", 30, Color("ffa6d2")]]:
		var l := HudUi.label(part[0], part[1], part[2])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		srow.add_child(l)
	score.add_child(srow)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 타이틀 메뉴와 같은 평행사변형 버튼 (주: 잉크+빨강 그림자 / 보조: 종이+잉크 선)
	_retry = SlantButton.make("다시하기", Vector2(250, 72), true, 32, "stars")
	_retry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_retry.pressed.connect(_on_retry)
	var to_title := SlantButton.make("타이틀로", Vector2(240, 72), false, 32)
	to_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	to_title.pressed.connect(_on_title)

	# HANA 승리 화면은 디자인처럼 [다시하기][타이틀로][점수] 순서
	if _winner == 2:
		bar.add_child(_retry)
		bar.add_child(to_title)
		bar.add_child(score)
	else:
		bar.add_child(score)
		bar.add_child(_retry)
		bar.add_child(to_title)
	return bar


func _art(tex: Texture2D, box: Vector2) -> TextureRect:
	var t := HudUi.texture_rect(tex, Vector2.ZERO, box)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func _gradient(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	return g


func _v_gradient(stops: Array) -> GradientTexture2D:
	var tex := HudUi.h_gradient(stops)
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	tex.width = 4
	tex.height = 256
	return tex


# --- 애니메이션 ------------------------------------------------------------------

func _animate() -> void:
	var dir := 1.0 if _winner == 1 else -1.0 # 승자 패널이 들어오는 쪽(URI=왼쪽)
	_dim.modulate.a = 0.0
	_flash.modulate.a = 0.6
	_win_panel.position.x = -1500.0 * dir
	_lose_panel.position.x = 1500.0 * dir
	_slash.modulate.a = 0.0
	_game_set.scale = Vector2(1.6, 1.6)
	_game_set.modulate.a = 0.0
	_win_title.modulate.a = 0.0
	_win_title.scale = Vector2(1.5, 1.5)
	_lose_title.modulate.a = 0.0
	var lose_y := _lose_title.position.y
	_lose_title.position.y = lose_y - 40
	var bar_y := _bar.position.y
	_bar.position.y = bar_y + 140
	_bar.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	# 1 Game Set
	t.tween_property(_dim, "modulate:a", 1.0, 0.2)
	t.tween_property(_flash, "modulate:a", 0.0, 0.3)
	t.tween_property(_game_set, "modulate:a", 1.0, 0.15)
	t.tween_property(_game_set, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 2 Slash: 번쩍 + 패널이 양쪽에서 들어오며 가운데가 사선으로 갈라짐
	t.tween_property(_flash, "modulate:a", 0.85, 0.05).set_delay(T_SLASH)
	t.tween_property(_flash, "modulate:a", 0.0, 0.35).set_delay(T_SLASH + 0.05)
	t.tween_property(_win_panel, "position:x", 0.0, 0.32).set_delay(T_SLASH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_lose_panel, "position:x", 0.0, 0.32).set_delay(T_SLASH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_slash, "modulate:a", 1.0, 0.08).set_delay(T_SLASH)
	t.tween_property(_game_set, "modulate:a", 0.0, 0.18).set_delay(T_SLASH)
	t.tween_property(_game_set, "scale", Vector2(1.25, 1.25), 0.18).set_delay(T_SLASH)
	# 3 Result
	t.tween_property(_win_title, "modulate:a", 1.0, 0.2).set_delay(T_RESULT)
	t.tween_property(_win_title, "scale", Vector2.ONE, 0.4).set_delay(T_RESULT) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_lose_title, "modulate:a", 1.0, 0.45).set_delay(T_RESULT + 0.1)
	t.tween_property(_lose_title, "position:y", lose_y, 0.6).set_delay(T_RESULT + 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	t.tween_property(_bar, "modulate:a", 1.0, 0.3).set_delay(T_RESULT + 0.25)
	t.tween_property(_bar, "position:y", bar_y, 0.4).set_delay(T_RESULT + 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.chain().tween_callback(func(): _retry.grab_focus())


func _on_retry() -> void:
	_play_click()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title() -> void:
	_play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _play_click() -> void:
	var click_sound := get_tree().current_scene.get_node_or_null("SfxClick") as AudioStreamPlayer
	if click_sound != null:
		click_sound.play()


## 승자/패자 패널 경계의 사선 (흰 선 + 글로우)
class SlashLine extends Control:
	var mirror := false

	func _draw() -> void:
		var a := Vector2(1280, -60)
		var b := Vector2(860, 1260)
		if mirror:
			a.x = 1920 - a.x
			b.x = 1920 - b.x
		for g in [[70.0, 0.08], [46.0, 0.14], [30.0, 0.22]]:
			draw_line(a, b, Color(1, 1, 1, g[1]), g[0], true)
		draw_line(a, b, Color.WHITE, 12.0, true)
