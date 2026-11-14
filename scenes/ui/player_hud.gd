@tool
class_name PlayerHud
extends Control
## Figma "HUD/Player Panel" — 하단 코너 플레이어 패널 (830×230, 디자인 픽셀).
## P1 = 왼쪽 아래(블루), P2 = 오른쪽 아래(핑크, 좌우 대칭).
## 이 노드는 HudOverlay의 Canvas 안에서 화면 절반을 차지하고, 패널은 그 아래 구석에 붙는다.

const PANEL_SIZE := Vector2(830, 230)
const CHIP_SIZE := 46.0
const CHIP_STEP := 59.0 # 54 슬롯 + 5 간격 (아이콘 46은 슬롯 가운데)
## 초상화(+뒤 오라)를 디자인 위치보다 화면 가운데 쪽으로 옮기는 양 (디자인 px)
const PORTRAIT_INSET := 12.0
## 초상화를 패널(230) 위로 올리는 양. 초상화 아래는 화면 끝(패널 바닥)에 붙어 있고
## 높이 = 230 + 이 값. 일러스트 파일(480×777)은 이 비율(210×340)로 잘라 둔 것 —
## 값을 바꾸면 일러스트도 같은 비율로 다시 잘라야 늘어나 보이지 않음.
const PORTRAIT_RAISE := 110.0
const PORTRAIT_WIDTH := 210.0
const TEX := {
	1: {
		"portrait": preload("res://sprites/ui/hud/portrait_p1.png"),
		"aura": preload("res://sprites/ui/hud/aura_p1.svg"),
	},
	2: {
		"portrait": preload("res://sprites/ui/hud/portrait_p2.png"),
		"aura": preload("res://sprites/ui/hud/aura_p2.svg"),
	},
}
## HP 1일 때 쓸 중상(아파하는 표정) 일러스트. 지금은 기본 일러스트를 색 반전한 임시 이미지 —
## 진짜 일러스트가 나오면 같은 이름으로 덮어쓰면 됨. 파일이 없으면 HP 1이어도 기본 일러스트.
const HURT_PORTRAIT_PATH := {
	1: "res://sprites/ui/hud/portrait_p1_hurt.png",
	2: "res://sprites/ui/hud/portrait_p2_hurt.png",
}
## 데미지를 받은 순간(HP가 0이 되는 경우 제외) 초상화가 붉게 번쩍였다가 돌아옴
const DAMAGE_TINT := Color(1.0, 0.4, 0.4)
const DAMAGE_FLASH_TIME := 0.35
const GRAYSCALE := preload("res://scenes/ui/hud/grayscale.gdshader")
const SPARKLE_12 := preload("res://sprites/ui/hud/sparkle_12.svg")
const SPARKLE_8 := preload("res://sprites/ui/hud/sparkle_8.svg")

@export var team_id: int = 1:
	set(value):
		team_id = value
		if is_inside_tree():
			_build()
## 비워두면 P1 = Uri, P2 = Hana
@export var player_name: String = "":
	set(value):
		player_name = value
		if _name_label:
			_name_label.text = _display_name()
## 팬클럽 칩 슬롯 수 (게임 전체 팬클럽 수)
@export var total_clubs: int = 5

var sudden_death := false
var _clubs: Array[FanClubData] = []

var _panel: Control
var _portrait: TextureRect
var _hurt_texture: Texture2D
var _gray_material: ShaderMaterial
var _last_hp := -1
var _flash_tween: Tween
var _name_label: Label
var _chip_row: HBoxContainer
var _fan_count: Label
var _fan_total: Label
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		add_to_group("player_huds")
	_build()


# --- 게임 쪽에서 부르는 API (fan_player_test.gd) ---------------------------------

func set_match_state(_time_left: float, is_sudden_death: bool, game_over: bool,
		winner_team: int) -> void:
	sudden_death = is_sudden_death
	if game_over:
		_status.text = "YOU WIN" if winner_team == team_id else "YOU LOSE"
	else:
		_status.text = ""


func set_player_state(hp: int, _max_hp: int, clubs: Array[FanClubData],
		population: int, population_limit: int) -> void:
	_update_portrait(hp)
	_clubs = clubs
	_refresh_chips()
	_fan_count.text = str(population)
	_fan_total.text = " / %d" % population_limit


# --- 레이아웃 ----------------------------------------------------------------

func _is_p2() -> bool:
	return team_id == 2


func _accent() -> Color:
	return HudUi.PINK if _is_p2() else HudUi.BLUE


func _light() -> Color:
	return HudUi.PINK_LIGHT if _is_p2() else HudUi.BLUE_LIGHT


func _shade() -> Color:
	return HudUi.PINK_SHADE if _is_p2() else HudUi.BLUE_SHADE


func _display_name() -> String:
	if player_name != "":
		return player_name
	return "Hana" if _is_p2() else "Uri"


## P1 기준 x 좌표를 P2에서는 좌우 반전
func _mx(x: float, w: float) -> float:
	return PANEL_SIZE.x - x - w if _is_p2() else x


func _tex(key: String) -> Texture2D:
	return TEX[2 if _is_p2() else 1][key]


func _build() -> void:
	for child in get_children():
		child.free()
	var p2 := _is_p2()
	# 화면 절반 영역
	anchor_left = 0.5 if p2 else 0.0
	anchor_right = 1.0 if p2 else 0.5
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 초상화 머리가 패널 위로 나올 수 있게 클립하지 않음 (패널 아래는 어차피 화면 끝)
	_panel.clip_contents = false
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -PANEL_SIZE.y
	_panel.offset_bottom = 0
	if p2:
		_panel.anchor_left = 1.0
		_panel.anchor_right = 1.0
		_panel.offset_left = -PANEL_SIZE.x
		_panel.offset_right = 0
	else:
		_panel.offset_left = 0
		_panel.offset_right = PANEL_SIZE.x
	add_child(_panel)

	_panel.add_child(HudUi.texture_rect(_tex("aura"),
		Vector2(_mx(-20 + PORTRAIT_INSET, 230), 0), Vector2(230, 230)))
	_panel.add_child(HudUi.texture_rect(SPARKLE_12, Vector2(_mx(330, 12), 96), Vector2(12, 12)))
	_panel.add_child(HudUi.texture_rect(SPARKLE_8, Vector2(_mx(560, 8), 134), Vector2(8, 8)))

	# 일러스트는 그려진 방향 그대로 (좌우 반전 없음)
	_portrait = HudUi.texture_rect(_tex("portrait"),
		Vector2(_mx(-8 + PORTRAIT_INSET, PORTRAIT_WIDTH), -PORTRAIT_RAISE),
		Vector2(PORTRAIT_WIDTH, PANEL_SIZE.y + PORTRAIT_RAISE))
	_panel.add_child(_portrait)
	var hurt_path: String = HURT_PORTRAIT_PATH[2 if p2 else 1]
	_hurt_texture = load(hurt_path) as Texture2D if ResourceLoader.exists(hurt_path) else null

	_panel.add_child(_make_name_shade())

	# 이름표: [P1 태그][이름] / P2는 [이름][P2 태그]
	var nameplate := HBoxContainer.new()
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_theme_constant_override("separation", 7)
	nameplate.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	HudUi.set_rect(nameplate, Vector2(_mx(12, 320), 184), Vector2(320, 40))
	var tag := HudUi.pill("P2" if p2 else "P1", 14, Color.WHITE, _accent(), Color.WHITE, 2,
		Vector2(8, 0))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label = HudUi.label(_display_name(), 32, Color.WHITE, _shade())
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if p2:
		nameplate.add_child(_name_label)
		nameplate.add_child(tag)
	else:
		nameplate.add_child(tag)
		nameplate.add_child(_name_label)
	_panel.add_child(nameplate)

	# 팬클럽 칩 5칸
	_chip_row = HBoxContainer.new()
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_row.add_theme_constant_override("separation", int(CHIP_STEP - CHIP_SIZE))
	_chip_row.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	var row_w := CHIP_SIZE * 5 + (CHIP_STEP - CHIP_SIZE) * 4
	HudUi.set_rect(_chip_row, Vector2(_mx(216, row_w), 176), Vector2(row_w, CHIP_SIZE))
	_panel.add_child(_chip_row)

	# FANS n / 16 — 칩 옆 자리를 혼자 크게 차지
	var fans_row := HBoxContainer.new()
	fans_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fans_row.add_theme_constant_override("separation", 0)
	fans_row.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	HudUi.set_rect(fans_row, Vector2(_mx(512, 240), 180), Vector2(240, 48))
	# 화면 가운데 쪽에 캡션: P1 = [n / 16][FANS], P2 = [FANS][n / 16]
	var fans_caption := HudUi.label("FANS  " if p2 else "  FANS", 15, HudUi.LABEL_DIM)
	_fan_count = HudUi.label("0", 34, _light())
	_fan_total = HudUi.label(" / 16", 34)
	var order := [fans_caption, _fan_count, _fan_total] if p2 \
		else [_fan_count, _fan_total, fans_caption]
	for l in order:
		l.size_flags_vertical = Control.SIZE_SHRINK_END
		fans_row.add_child(l)
	_panel.add_child(fans_row)

	# 승패 표시 (화면 절반 가운데)
	_status = HudUi.label("", 56, Color.WHITE, _shade(), Vector2(0, 4))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.anchor_top = 0.42
	_status.anchor_bottom = 0.42
	_status.offset_left = -360
	_status.offset_right = 360
	_status.offset_top = -50
	_status.offset_bottom = 50
	add_child(_status)

	_refresh_chips()


func _make_name_shade() -> TextureRect:
	var shade := _shade()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(shade, 0.95), Color(shade, 0.55), Color(shade, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 320
	tex.height = 150
	tex.fill = GradientTexture2D.FILL_RADIAL
	# 디자인: (96,150) 중심, 반지름 160×75 → UV 기준 원형 반지름 0.5
	var cx := 0.7 if _is_p2() else 0.3
	tex.fill_from = Vector2(cx, 1.0)
	tex.fill_to = Vector2(cx + 0.5, 1.0)
	return HudUi.texture_rect(tex, Vector2(_mx(-20, 320), 80), Vector2(320, 150))


## HP에 따라 초상화 교체: 2 이상 = 기본, 1 = 아파하는 표정 일러스트, 0 = 흑백(리스폰하면 원래대로).
## HP가 줄어든 순간(0이 된 경우 제외)에는 붉은 플래시.
func _update_portrait(hp: int) -> void:
	if _portrait == null:
		return
	var damaged := _last_hp >= 0 and hp < _last_hp
	_last_hp = hp

	if hp <= 0:
		if _gray_material == null:
			_gray_material = ShaderMaterial.new()
			_gray_material.shader = GRAYSCALE
		_portrait.material = _gray_material
		_portrait.texture = _tex("portrait")
		_stop_flash()
		return

	_portrait.material = null
	_portrait.texture = _hurt_texture if hp == 1 and _hurt_texture != null else _tex("portrait")
	if damaged:
		_flash_damage()


func _flash_damage() -> void:
	_stop_flash()
	_portrait.self_modulate = DAMAGE_TINT
	_flash_tween = create_tween()
	_flash_tween.tween_property(_portrait, "self_modulate", Color.WHITE, DAMAGE_FLASH_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _stop_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_portrait.self_modulate = Color.WHITE


func _refresh_chips() -> void:
	if _chip_row == null:
		return
	var slots := maxi(total_clubs, _clubs.size())
	while _chip_row.get_child_count() < slots:
		var chip := ClubChip.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(CHIP_SIZE, CHIP_SIZE)
		chip.accent = _accent()
		_chip_row.add_child(chip)
	while _chip_row.get_child_count() > slots:
		var extra := _chip_row.get_child(_chip_row.get_child_count() - 1)
		_chip_row.remove_child(extra)
		extra.queue_free()
	var owned := _clubs.size()
	var empty := slots - owned
	for i in range(slots):
		var chip := _chip_row.get_child(i) as ClubChip
		# P1: 보유 칩이 왼쪽부터, P2: 빈 칸이 먼저 오고 보유 칩이 초상화 쪽(오른쪽)
		var club_index := i if not _is_p2() else i - empty
		var club: FanClubData = null
		if club_index >= 0 and club_index < owned:
			club = _clubs[club_index]
		chip.texture = club.sprite_texture if club != null else null
