extends Control
## Figma "Title Screen" (Mii - UI, 63:951) — 게임 시작 화면. 시작하기 → 인게임, 게임 설명 → 규칙 패널.
## 디자인 좌표(1920×1200)로 만든 Canvas를 화면 폭에 맞춰 스케일하고 세로 가운데 정렬.

const GAME_SCENE := "res://scenes/test/fan_player_test.tscn"
const DESIGN := Vector2(1920, 1200)
const PAPER := Color("fbf5f8")
const INK := Color("160c26")
const RED := Color("ff2e6e")

const BG := preload("res://sprites/ui/title/title_bg_paper.png")
const LOGO := preload("res://sprites/ui/title/title_logo.png")
const URI_ART := preload("res://sprites/ui/title/uri_idle.png")
const HANA_ART := preload("res://sprites/ui/title/hana_idle.png")
const URI_GLOW := preload("res://sprites/ui/title/uri_glow.png")
const HANA_GLOW := preload("res://sprites/ui/title/hana_glow.png")

## 디자인 배치 (1000×2000 일러스트를 디자인과 같은 크기·위치로)
const URI_RECT := Rect2(-4.1, 163.0, 621.0, 1242.0)
## HANA는 원본 비율(1:2) 그대로: 디자인의 보이는 키(951)·가로 중심(x≈1660)에 맞춰 균일 스케일
const HANA_RECT := Rect2(1343.1, 156.2, 636.7, 1273.4)
## 두 줄이 겹치지 않게 다시 합성한 로고 (Figma 레이어별 렌더, 원본과 같은 배율 0.6335)
const LOGO_RECT := Rect2(352.81, 113.08, 1218.19, 453.57)
## 메뉴 버튼 위치 (Figma 메뉴 영역 기준)
const START_POS := Vector2(730, 727)
const HELP_POS := Vector2(770, 863)

var _canvas: Control
var _start_button: SlantButton
var _help: Control
var _uri: Control
var _hana: Control
var _logo: Control
var _menu: Array[SlantButton] = []
var _leaving := false
var _time := 0.0


func _ready() -> void:
	get_tree().paused = false
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
	# 두 히로인이 반대 박자로 살짝 둥실
	var bob := sin(_time * 1.6) * 5.0
	_uri.position.y = float(_uri.get_meta("base_y")) + bob
	_hana.position.y = float(_hana.get_meta("base_y")) - bob


func _unhandled_input(event: InputEvent) -> void:
	if _help.visible and event.is_action_pressed("ui_cancel"):
		_close_help()
		get_viewport().set_input_as_handled()


# --- 구성 ----------------------------------------------------------------------

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := ColorRect.new()
	base.color = PAPER
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.add_child(HudUi.texture_rect(BG, Vector2.ZERO, DESIGN))

	_uri = _heroine(URI_ART, URI_GLOW, URI_RECT)
	_canvas.add_child(_uri)
	_hana = _heroine(HANA_ART, HANA_GLOW, HANA_RECT)
	_canvas.add_child(_hana)

	_logo = HudUi.texture_rect(LOGO, LOGO_RECT.position, LOGO_RECT.size)
	_logo.pivot_offset = LOGO_RECT.size / 2.0
	_canvas.add_child(_logo)

	_start_button = _menu_button("시작하기", Vector2(460, 96), true, 44, "stars", START_POS)
	_start_button.pressed.connect(_start_game)
	var help_button := _menu_button("게임 설명", Vector2(380, 74), false, 34, "question", HELP_POS)
	help_button.pressed.connect(_open_help)
	_start_button.focus_neighbor_bottom = help_button.get_path()
	help_button.focus_neighbor_top = _start_button.get_path()

	_help = _make_help()
	_canvas.add_child(_help)

	var curtain := ColorRect.new()
	curtain.name = "Curtain"
	curtain.color = PAPER
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)


## 히로인: 팀 색으로 은은하게 번지는 글로우 + 일러스트 (같은 사각형에 겹침)
func _heroine(art: Texture2D, glow: Texture2D, rect: Rect2) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudUi.set_rect(holder, rect.position, rect.size)
	var g := HudUi.texture_rect(glow, Vector2.ZERO, rect.size)
	g.modulate.a = 0.35
	holder.add_child(g)
	holder.add_child(HudUi.texture_rect(art, Vector2.ZERO, rect.size))
	holder.set_meta("base_y", rect.position.y)
	return holder


## 타이틀 메뉴 버튼 (Figma 디자인과 같은 평행사변형 스타일, 글자는 프로젝트 폰트)
func _menu_button(text_: String, body: Vector2, primary: bool, font_size: int, deco: String,
		pos: Vector2) -> SlantButton:
	var b := SlantButton.make(text_, body, primary, font_size, deco)
	b.position = pos
	_canvas.add_child(b)
	_menu.append(b)
	return b


func _make_help() -> Control:
	var layer := Control.new()
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	HudUi.set_rect(layer, Vector2.ZERO, DESIGN)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# 종이 패널 + 잉크 테두리 + 핑크 하드 섀도
	var rect := Rect2(400, 300, 1120, 600)
	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = RED
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudUi.set_rect(shadow, rect.position + Vector2(14, 14), rect.size)
	layer.add_child(shadow)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = INK
	box.set_border_width_all(4)
	box.content_margin_left = 72
	box.content_margin_right = 72
	box.content_margin_top = 48
	box.content_margin_bottom = 48
	panel.add_theme_stylebox_override("panel", box)
	HudUi.set_rect(panel, rect.position, rect.size)
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var title := HudUi.label("게임 설명", 56, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var rule := ColorRect.new()
	rule.color = RED
	rule.custom_minimum_size = Vector2(120, 6)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rule)
	var lines := [
		"상대 무대의 응원봉을 내 무대로 가져오면 그 팬이 내 편이 됩니다.",
		"응원 탄에 맞으면 하트가 줄고 응원봉을 떨어뜨립니다.",
		"Shift로 에너지를 방출해 주변을 밀쳐내고 탄을 지웁니다.",
		"상대의 팬을 모두 가져오면 승리합니다.",
		"2분이 지나면 팬이 더 많은 쪽이 승리합니다.",
		"동점이면 서든데스! 먼저 팬을 가져오는 쪽이 승리합니다.",
	]
	for i in range(lines.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var bullet := ColorRect.new()
		bullet.color = HudUi.BLUE if i % 2 == 0 else HudUi.PINK
		bullet.custom_minimum_size = Vector2(12, 12)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bullet)
		var l := HudUi.label(lines[i], 32, INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	var keys := HudUi.label("P1  WASD / 왼쪽 Shift      P2  방향키 / 오른쪽 Shift", 26, Color(INK, 0.6))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(keys)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close := SlantButton.make("닫기", Vector2(230, 66), false, 30)
	close.name = "Close"
	close.pressed.connect(_close_help)
	# 팝업 안에서 포커스가 밖으로 나가지 않게 (버튼이 하나뿐이라 자기 자신을 가리킴)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		close.set_focus_neighbor(side, NodePath("."))
	close.focus_next = NodePath(".")
	close.focus_previous = NodePath(".")
	close_row.add_child(close)
	col.add_child(close_row)
	return layer


# --- 동작 ----------------------------------------------------------------------

func _intro() -> void:
	var curtain := get_node("Curtain") as ColorRect
	var t := create_tween().set_parallel(true)
	t.tween_property(curtain, "modulate:a", 0.0, 0.45)
	# 히로인은 양옆에서 살짝 밀려 들어오고, 로고는 톡 튀어나오고, 메뉴는 차례로
	for pair in [[_uri, -60.0, 0.1], [_hana, 60.0, 0.18]]:
		var c: Control = pair[0]
		var x := c.position.x
		c.position.x = x + float(pair[1])
		c.modulate.a = 0.0
		t.tween_property(c, "position:x", x, 0.6).set_delay(pair[2]) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "modulate:a", 1.0, 0.5).set_delay(pair[2])
	_logo.modulate.a = 0.0
	_logo.scale = Vector2(0.92, 0.92)
	t.tween_property(_logo, "modulate:a", 1.0, 0.35).set_delay(0.3)
	t.tween_property(_logo, "scale", Vector2.ONE, 0.5).set_delay(0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(_menu.size()):
		var m := _menu[i]
		m.modulate.a = 0.0
		t.tween_property(m, "modulate:a", 1.0, 0.3).set_delay(0.55 + i * 0.1)


func _start_game() -> void:
	if _leaving:
		return
	_leaving = true
	var curtain := get_node("Curtain") as ColorRect
	curtain.color = INK
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(curtain, "modulate:a", 1.0, 0.35)
	t.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))


## 설명 팝업이 떠 있는 동안 아래 메뉴는 클릭·포커스·키 입력 모두 막음
func _open_help() -> void:
	for m in _menu:
		m.set_blocked(true)
	_help.visible = true
	_fit_help()
	(_help.find_child("Close", true, false) as Control).grab_focus()


## 패널 높이를 글자 양(폰트 크기)에 맞추고 화면 가운데에 둠 — 폰트가 바뀌어도 여백이 고르게
func _fit_help() -> void:
	var panel := _help.get_node("Panel") as PanelContainer
	var shadow := _help.get_node("Shadow") as Control
	# 설명은 한 줄씩이라 줄바꿈 없이 최소 크기 = 실제 글자 크기 (폰트가 바뀌어도 그대로 맞음)
	var h := panel.get_combined_minimum_size().y
	var pos := Vector2(panel.position.x, (DESIGN.y - h) / 2.0)
	HudUi.set_rect(panel, pos, Vector2(panel.size.x, h))
	HudUi.set_rect(shadow, pos + Vector2(14, 14), Vector2(panel.size.x, h))


func _close_help() -> void:
	_help.visible = false
	for m in _menu:
		m.set_blocked(false)
	_start_button.grab_focus()
