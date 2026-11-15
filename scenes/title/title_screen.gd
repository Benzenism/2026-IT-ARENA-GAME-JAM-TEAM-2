extends Control
## Figma "Title Screen" — 게임 시작 화면. 시작하기 → 인게임, 게임 설명 → 규칙 패널.
## 디자인 좌표(1920×1200)로 만든 Canvas를 화면 폭에 맞춰 스케일하고, 배경은 화면을 꽉 채운다.

const GAME_SCENE := "res://scenes/test/fan_player_test.tscn"
const DESIGN := Vector2(1920, 1200)
## 히로인 배치: 보이는 키, 발 위치(바닥선), 화면 가운데에서 머리까지의 가로 거리
const HEROINE_HEIGHT := 940.0
const HEROINE_FLOOR := 1110.0
const HEROINE_SPREAD := 605.0
## 타이틀 글자 묶음의 위쪽 위치 (가로는 화면 가운데 정렬)
const TITLE_TOP := 100.0
const GRADIENT_TEXT := preload("res://scenes/ui/hud/gradient_text.gdshader")
const BGM2: AudioStream = preload("res://sounds/bgm2.mp3")

const BG := preload("res://sprites/ui/title/title_bg.png")
const GLOW_URI := preload("res://sprites/ui/title/glow_uri.svg")
const GLOW_HANA := preload("res://sprites/ui/title/glow_hana.svg")
const URI_ART := preload("res://sprites/ui/cutin/uri_full.png")
const HANA_ART := preload("res://sprites/ui/cutin/hana_full.png")
# 필터(글로우)가 걸린 SVG는 Godot에서 글로우만 그려지므로 원본(글로우) + _shape(도형)를 겹침
const SPARKLES := [
	[preload("res://sprites/ui/title/sparkle_a.svg"), preload("res://sprites/ui/title/sparkle_a_shape.svg"),
		Vector2(1420, 86), 70.0, 102.0],
	[preload("res://sprites/ui/title/sparkle_b.svg"), preload("res://sprites/ui/title/sparkle_b_shape.svg"),
		Vector2(688, 330), 44.0, 76.0],
	[preload("res://sprites/ui/title/sparkle_c.svg"), preload("res://sprites/ui/title/sparkle_c_shape.svg"),
		Vector2(1213, 420), 36.0, 68.0],
]

var _canvas: Control
var _start_button: PillButton
var _help: Control
var _uri: Control
var _hana: Control
var _sparkles: Array[Control] = []
var _music_player: AudioStreamPlayer
var _leaving := false
var _time := 0.0


func _ready() -> void:
	get_tree().paused = false
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.volume_db = -6.0
	_music_player.stream = BGM2
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_music_player.play()
	_build()
	resized.connect(_layout)
	_layout()
	_start_button.grab_focus()
	_intro()


func _layout() -> void:
	if _canvas == null or size.x <= 0.0:
		return
	var s := size.x / DESIGN.x
	_canvas.scale = Vector2(s, s)
	_canvas.size = DESIGN
	_canvas.position = Vector2(0, (size.y - DESIGN.y * s) / 2.0)


func _process(delta: float) -> void:
	_time += delta
	# 캐릭터는 살짝 둥실, 반짝이는 깜빡임
	if _uri:
		# 둘이 같은 리듬으로 살짝 반대 박자로 둥실
		var bob := sin(_time * 1.6) * 7.0
		_uri.position.y = float(_uri.get_meta("base_y")) + bob
		_hana.position.y = float(_hana.get_meta("base_y")) - bob
	for i in range(_sparkles.size()):
		var sp := _sparkles[i]
		var k := 0.82 + 0.18 * sin(_time * 2.4 + i * 1.9)
		sp.scale = Vector2(k, k)
		sp.rotation = sin(_time * 0.8 + i) * 0.25


func _on_music_finished() -> void:
	if not _leaving and is_instance_valid(_music_player):
		_music_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if _help.visible and event.is_action_pressed("ui_cancel"):
		_close_help()
		get_viewport().set_input_as_handled()


# --- 구성 ----------------------------------------------------------------------

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := ColorRect.new()
	base.color = Color("120a20")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 좌(블루) 우(핑크) 색 입히기 + 비네트
	var tint := HudUi.texture_rect(HudUi.h_gradient([
		[0.0, Color(0.298, 0.553, 1.0, 0.35)], [0.4, Color(0.298, 0.553, 1.0, 0.0)],
		[0.6, Color(1.0, 0.373, 0.659, 0.0)], [1.0, Color(1.0, 0.373, 0.659, 0.35)]]), Vector2.ZERO, Vector2.ZERO)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tint)
	add_child(_vignette())

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	var fade := HudUi.texture_rect(_v_gradient([[0.0, Color(0.071, 0.039, 0.125, 0.0)],
		[1.0, Color(0.071, 0.039, 0.125, 0.92)]]), Vector2(0, 680), Vector2(1920, 520))
	_canvas.add_child(fade)
	# 두 히로인: 같은 키, 같은 바닥선, 화면 가운데 기준 좌우 대칭 (머리 위치 기준)
	var center_y := HEROINE_FLOOR - HEROINE_HEIGHT * 0.5
	for g in [[GLOW_URI, 960.0 - HEROINE_SPREAD], [GLOW_HANA, 960.0 + HEROINE_SPREAD]]:
		_canvas.add_child(HudUi.texture_rect(g[0], Vector2(g[1] - 450.0, center_y - 450.0), Vector2(900, 900)))
	_uri = _heroine(URI_ART, 960.0 - HEROINE_SPREAD)
	_canvas.add_child(_uri)
	_hana = _heroine(HANA_ART, 960.0 + HEROINE_SPREAD)
	_canvas.add_child(_hana)

	_canvas.add_child(_make_logo())
	for sp in SPARKLES:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var full: float = sp[4]
		var pos: Vector2 = sp[2]
		var inset: float = (full - float(sp[3])) / 2.0
		HudUi.set_rect(holder, pos - Vector2(inset, inset), Vector2(full, full))
		holder.pivot_offset = Vector2(full, full) / 2.0
		holder.add_child(HudUi.texture_rect(sp[0], Vector2.ZERO, Vector2(full, full)))
		holder.add_child(HudUi.texture_rect(sp[1], Vector2.ZERO, Vector2(full, full)))
		_canvas.add_child(holder)
		_sparkles.append(holder)

	# 메뉴
	var menu := VBoxContainer.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.alignment = BoxContainer.ALIGNMENT_BEGIN
	menu.add_theme_constant_override("separation", 22)
	HudUi.set_rect(menu, Vector2(730, 760), Vector2(460, 202))
	_start_button = PillButton.make("시작하기", Vector2(460, 100), true, 46, "stars")
	_start_button.pressed.connect(_start_game)
	menu.add_child(_start_button)
	var help_button := PillButton.make("게임 설명", Vector2(400, 80), false, 36, "question")
	help_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help_button.pressed.connect(_open_help)
	menu.add_child(help_button)
	_canvas.add_child(menu)

	_canvas.add_child(_controls_hint())
	var foot := HudUi.label("PRESS START · v0.1", 18, Color(1, 1, 1, 0.5))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudUi.set_rect(foot, Vector2(560, 1146), Vector2(800, 30))
	_canvas.add_child(foot)

	_help = _make_help()
	_canvas.add_child(_help)

	var curtain := ColorRect.new()
	curtain.name = "Curtain"
	curtain.color = Color("120a20")
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)


## 일러스트의 실제 보이는 부분(투명 아닌 픽셀)을 재서, 키가 HEROINE_HEIGHT가 되고
## 발이 HEROINE_FLOOR에 닿고 머리 가운데가 head_x에 오도록 배치
func _heroine(tex: Texture2D, head_x: float) -> TextureRect:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	# 머리 부분(위쪽 22%)의 가로 중심 — 마이크처럼 옆으로 튀어나온 소품에 끌려가지 않게
	var head := img.get_region(Rect2i(used.position, Vector2i(used.size.x, int(used.size.y * 0.22))))
	var head_used := head.get_used_rect()
	var sum := 0.0
	var count := 0.0
	for y in range(0, head.get_height(), 4):
		for x in range(head_used.position.x, head_used.end.x, 2):
			if head.get_pixel(x, y).a > 0.1:
				sum += x
				count += 1.0
	var head_cx := used.position.x + (sum / maxf(count, 1.0))
	var s := HEROINE_HEIGHT / float(used.size.y)
	var size_px := Vector2(img.get_width(), img.get_height()) * s
	var pos := Vector2(head_x - head_cx * s, HEROINE_FLOOR - used.end.y * s)
	var t := HudUi.texture_rect(tex, pos, size_px)
	t.set_meta("base_y", pos.y)
	return t


## 게임 타이틀 "마법소녀는 / (탭) 사랑받고 싶어"
## 두 줄을 살짝 겹치고 왼쪽으로 기울인, 날카로운 명조 타이틀 (모노가타리 시리즈 느낌)
func _make_logo() -> Control:
	var logo := Control.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := Color("1a0f2e")
	# 1행: 마법소녀는 — 흰 글자, 블루 그림자
	var line1 := HudUi.label("마법소녀는", 100, Color.WHITE, HudUi.BLUE, Vector2(6, 6))
	line1.label_settings.outline_size = 10
	line1.label_settings.outline_color = ink
	line1.position = Vector2(0, 0)
	logo.add_child(line1)

	# 탭 자리의 날카로운 핑크 막대 + 가는 흰 선
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = HudUi.PINK
	HudUi.set_rect(bar, Vector2(10, 178), Vector2(112, 8))
	logo.add_child(bar)
	var hair := ColorRect.new()
	hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hair.color = Color(1, 1, 1, 0.85)
	HudUi.set_rect(hair, Vector2(10, 191), Vector2(68, 3))
	logo.add_child(hair)

	# 2행: 사랑받고 싶어 — 한 탭 들여서, 1행 아래쪽에 살짝 겹치게. 핑크 그라디언트
	var line2 := HudUi.label("사랑받고 싶어", 128, Color.WHITE, Color("2a1748"), Vector2(7, 7))
	line2.label_settings.outline_size = 12
	line2.label_settings.outline_color = ink
	line2.position = Vector2(134, 100)
	logo.add_child(line2)
	line2.material = _gradient_material(Color("fff0f7"), Color("ffa6d2"), Color("ff5fa8"), true,
		Vector2(1, 175))

	# 두 줄 묶음의 실제 크기를 재서, 화면 가운데 축(x=960)에 맞추고 그 중심으로 왼쪽으로 기울임
	var w1 := line1.get_minimum_size().x
	var w2 := line2.position.x + line2.get_minimum_size().x
	var logo_size := Vector2(maxf(w1, w2), line2.position.y + line2.get_minimum_size().y)
	HudUi.set_rect(logo, Vector2(960.0 - logo_size.x / 2.0, TITLE_TOP), logo_size)
	logo.pivot_offset = logo_size / 2.0
	logo.rotation_degrees = -7.0
	return logo


func _controls_hint() -> Control:
	var row := _center_row(1004, 44)
	row.add_theme_constant_override("separation", 14)
	row.add_child(_pill_label("P1", 18, Color.WHITE, HudUi.BLUE, Color(0, 0, 0, 0), 0, Vector2(12, 2), Color(0, 0, 0, 0)))
	row.add_child(HudUi.label("W A S D", 22, Color(1, 1, 1, 0.85)))
	row.add_child(HudUi.label("·", 22, Color(1, 1, 1, 0.5)))
	row.add_child(_pill_label("P2", 18, Color.WHITE, HudUi.PINK, Color(0, 0, 0, 0), 0, Vector2(12, 2), Color(0, 0, 0, 0)))
	row.add_child(HudUi.label("← ↑ ↓ →", 22, Color(1, 1, 1, 0.85)))
	row.add_child(HudUi.label("·  키보드 1대로 2인 대결", 22, Color(1, 1, 1, 0.85)))
	for c in row.get_children():
		(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _make_help() -> Control:
	var layer := Control.new()
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	HudUi.set_rect(layer, Vector2.ZERO, DESIGN)
	var dim := ColorRect.new()
	dim.color = Color(0.031, 0.016, 0.063, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.102, 0.059, 0.18, 0.96)
	box.border_color = Color("e3d4ff")
	box.set_border_width_all(3)
	box.set_corner_radius_all(36)
	box.content_margin_left = 64
	box.content_margin_right = 64
	box.content_margin_top = 44
	box.content_margin_bottom = 44
	box.shadow_color = Color(0.043, 0.02, 0.086, 0.85)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", box)
	HudUi.set_rect(panel, Vector2(410, 300), Vector2(1100, 600))
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var title := HudUi.label("게임 설명", 56, Color.WHITE, Color("b48cff"), Vector2(0, 5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var lines := [
		"상대 무대에 들어가면 팬클럽 응원봉을 하나 뺏어 와요.",
		"응원봉을 내 무대까지 가져오면 그 팬클럽이 내 편이 돼요.",
		"팬들의 응원 탄에 맞으면 하트가 줄고 응원봉을 떨어뜨려요.",
		"2분이 지나면 팬클럽이 더 많은 쪽이 승리!",
		"같으면 서든데스 — 먼저 하나 가져오는 쪽이 승리.",
		"상대의 팬클럽을 모두 뺏으면 그 자리에서 승리!",
	]
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var bullet := Panel.new()
		bullet.custom_minimum_size = Vector2(14, 14)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dot := StyleBoxFlat.new()
		dot.bg_color = Color("ffd36b")
		dot.set_corner_radius_all(999)
		bullet.add_theme_stylebox_override("panel", dot)
		row.add_child(bullet)
		var l := HudUi.label(line, 32, Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	var keys := HudUi.label("P1  W A S D   ·   P2  ← ↑ ↓ →", 26, Color(0.89, 0.831, 1.0, 0.85))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(keys)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close := PillButton.make("닫기", Vector2(260, 72), false, 32)
	close.name = "Close"
	close.pressed.connect(_close_help)
	close_row.add_child(close)
	col.add_child(close_row)
	return layer


# --- 헬퍼 ----------------------------------------------------------------------

func _center_row(top: float, height: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	HudUi.set_rect(row, Vector2(0, top), Vector2(1920, height))
	return row


func _pill_label(text: String, font_size: int, fg: Color, bg: Color, border: Color, border_w: int,
		pad: Vector2, text_shadow: Color) -> PanelContainer:
	var p := HudUi.pill(text, font_size, fg, bg, border, border_w, pad)
	if text_shadow.a > 0.0:
		var l := HudUi.pill_label(p)
		l.label_settings.shadow_color = text_shadow
		l.label_settings.shadow_offset = Vector2(0, 3)
		l.label_settings.shadow_size = 0
	return p


func _gradient_material(a: Color, b: Color, c: Color, vertical: bool, box: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRADIENT_TEXT
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("color_c", c)
	m.set_shader_parameter("vertical", vertical)
	m.set_shader_parameter("box_size", box)
	return m


func _v_gradient(stops: Array) -> GradientTexture2D:
	var tex := HudUi.h_gradient(stops)
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	tex.width = 4
	tex.height = 256
	return tex


func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var ink := Color(0.071, 0.039, 0.125)
	g.colors = PackedColorArray([Color(ink, 0.0), Color(ink, 0.0), Color(ink, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 160
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var t := HudUi.texture_rect(tex, Vector2.ZERO, Vector2.ZERO)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	return t


# --- 동작 ----------------------------------------------------------------------

func _intro() -> void:
	var curtain := get_node("Curtain") as ColorRect
	var t := create_tween().set_parallel(true)
	t.tween_property(curtain, "modulate:a", 0.0, 0.5)
	_uri.modulate.a = 0.0
	_hana.modulate.a = 0.0
	t.tween_property(_uri, "modulate:a", 1.0, 0.6).set_delay(0.15)
	t.tween_property(_hana, "modulate:a", 1.0, 0.6).set_delay(0.25)


func _start_game() -> void:
	if _leaving:
		return
	_leaving = true
	var curtain := get_node("Curtain") as ColorRect
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(curtain, "modulate:a", 1.0, 0.35)
	t.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))


func _open_help() -> void:
	_help.visible = true
	(_help.find_child("Close", true, false) as Control).grab_focus()


func _close_help() -> void:
	_help.visible = false
	_start_button.grab_focus()
