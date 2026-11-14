@tool
class_name PlayerHud
extends Control
## Figma "HUD/Player Panel" — 하단 코너 플레이어 패널 (830×230, 디자인 픽셀).
## P1 = 왼쪽 아래(블루), P2 = 오른쪽 아래(핑크, 좌우 대칭).
## 상태: 기본 / 멘탈 다운(HP 0, 리스폰 대기) / 운반 중(응원봉 운반).
## 이 노드는 HudOverlay의 Canvas 안에서 화면 절반을 차지하고, 패널은 그 아래 구석에 붙는다.

enum State { NORMAL, DOWN, CARRY }

const PANEL_SIZE := Vector2(830, 230)
const CHIP_SIZE := 46.0
const CHIP_STEP := 59.0 # 54 슬롯 + 5 간격 (아이콘 46은 슬롯 가운데)
const GRAYSCALE := preload("res://scenes/ui/hud/grayscale.gdshader")
const TEX := {
	1: {
		"portrait": preload("res://sprites/ui/hud/portrait_p1.png"),
		"aura": preload("res://sprites/ui/hud/aura_p1.svg"),
		"aura_down": preload("res://sprites/ui/hud/aura_p1_down.svg"),
		"aura_carry": preload("res://sprites/ui/hud/aura_p1_carry.svg"),
		"state_edge": preload("res://sprites/ui/hud/state_edge_p1.svg"),
		"state_edge_shape": preload("res://sprites/ui/hud/state_edge_p1_shape.svg"),
	},
	2: {
		"portrait": preload("res://sprites/ui/hud/portrait_p2.png"),
		"aura": preload("res://sprites/ui/hud/aura_p2.svg"),
		"aura_down": preload("res://sprites/ui/hud/aura_p2_down.svg"),
		"aura_carry": preload("res://sprites/ui/hud/aura_p2_carry.svg"),
		"state_edge": preload("res://sprites/ui/hud/state_edge_p2.svg"),
		"state_edge_shape": preload("res://sprites/ui/hud/state_edge_p2_shape.svg"),
	},
}
const SPARKLE_12 := preload("res://sprites/ui/hud/sparkle_12.svg")
const SPARKLE_8 := preload("res://sprites/ui/hud/sparkle_8.svg")

@export var team_id: int = 1:
	set(value):
		team_id = value
		if is_inside_tree():
			_build()
## 비워두면 P1 = CIEL, P2 = LULU
@export var player_name: String = "":
	set(value):
		player_name = value
		if _name_label:
			_name_label.text = _display_name()
@export var total_clubs: int = 5

var sudden_death := false
var _state := State.NORMAL
var _clubs: Array[FanClubData] = []

var _panel: Control
var _aura: TextureRect
var _state_edge: Control
var _portrait: TextureRect
var _name_label: Label
var _chip_row: HBoxContainer
var _club_count: Label
var _club_total: Label
var _fan_count: Label
var _fan_total: Label
var _down_label: Label
var _respawn_row: HBoxContainer
var _carry_chip: ClubChip
var _badge_row: HBoxContainer
var _badge: PanelContainer
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


func set_player_state(_hp: int, _max_hp: int, clubs: Array[FanClubData],
		population: int, population_limit: int) -> void:
	_clubs = clubs
	_refresh_chips()
	_club_count.text = str(clubs.size())
	_club_total.text = " / %d" % total_clubs
	_fan_count.text = str(population)
	_fan_total.text = " / %d" % population_limit


## 멘탈 다운 / 운반 중 표시용. club_total은 게임 전체 팬클럽 수(칩 슬롯 수).
func set_idol_state(player: IdolPlayer, club_total: int) -> void:
	if club_total != total_clubs:
		total_clubs = club_total
		_refresh_chips()
	if player.hp <= 0:
		var secs := maxi(1, ceili(player.respawn_timer.time_left))
		_apply_state(State.DOWN, secs, null)
	elif player.carried_club != null:
		_apply_state(State.CARRY, 0, player.carried_club)
	else:
		_apply_state(State.NORMAL, 0, null)


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
	return "LULU" if _is_p2() else "CIEL"


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
	_panel.clip_contents = true
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

	_aura = HudUi.texture_rect(_tex("aura"), Vector2(_mx(-20, 230), 0), Vector2(230, 230))
	_panel.add_child(_aura)

	# 운반 중: 삼각형 윗변을 따라 금색 글로우 라인
	var edge_pos := Vector2(_mx(-30.32, 820.65), 50.28)
	var edge_size := Vector2(820.65, 175.44)
	_state_edge = Control.new()
	_state_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_edge.add_child(HudUi.texture_rect(_tex("state_edge"), edge_pos, edge_size))
	_state_edge.add_child(HudUi.texture_rect(_tex("state_edge_shape"), edge_pos, edge_size))
	_panel.add_child(_state_edge)

	_panel.add_child(HudUi.texture_rect(SPARKLE_12, Vector2(_mx(330, 12), 96), Vector2(12, 12)))
	_panel.add_child(HudUi.texture_rect(SPARKLE_8, Vector2(_mx(560, 8), 134), Vector2(8, 8)))

	_portrait = HudUi.texture_rect(_tex("portrait"), Vector2(_mx(-8, 210), 0), Vector2(210, 280))
	_portrait.flip_h = true
	_panel.add_child(_portrait)

	_panel.add_child(_make_name_shade())

	_carry_chip = ClubChip.new()
	_carry_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_chip.accent = HudUi.GOLD
	_carry_chip.corner_radius = 10
	_carry_chip.glow_size = 12
	_carry_chip.glow_alpha = 0.9
	HudUi.set_rect(_carry_chip, Vector2(_mx(168, 40), 22), Vector2(40, 40))
	_panel.add_child(_carry_chip)

	# 멘탈 다운: 초상화 위 "MENTAL DOWN" + 리스폰 카운트
	_down_label = HudUi.label("MENTAL\nDOWN", 24, Color.WHITE, Color("3a2a55"))
	_down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_down_label.label_settings.line_spacing = -3
	HudUi.set_rect(_down_label, Vector2(_mx(0, 200), 52), Vector2(200, 56))
	_panel.add_child(_down_label)
	_respawn_row = HBoxContainer.new()
	_respawn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_respawn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	HudUi.set_rect(_respawn_row, Vector2(_mx(0, 200), 108), Vector2(200, 24))
	_respawn_row.add_child(HudUi.pill("리스폰 3", 13, Color("3a2a55"),
		Color(1, 1, 1, 0.92), Color(0, 0, 0, 0), 0, Vector2(10, 1)))
	_panel.add_child(_respawn_row)

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

	# CLUBS n / 5
	var club_box := VBoxContainer.new()
	club_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	club_box.add_theme_constant_override("separation", -4)
	HudUi.set_rect(club_box, Vector2(_mx(516, 120), 174), Vector2(120, 50))
	var clubs_caption := HudUi.label("CLUBS", 12, HudUi.LABEL_DIM)
	clubs_caption.size_flags_horizontal = Control.SIZE_SHRINK_END if p2 else Control.SIZE_SHRINK_BEGIN
	club_box.add_child(clubs_caption)
	var club_value := HBoxContainer.new()
	club_value.add_theme_constant_override("separation", 0)
	club_value.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	_club_count = HudUi.label("0", 24, _light())
	_club_total = HudUi.label(" / 5", 24)
	club_value.add_child(_club_count)
	club_value.add_child(_club_total)
	club_box.add_child(club_value)
	_panel.add_child(club_box)

	# FANS n / 16
	var fans := HBoxContainer.new()
	fans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fans.add_theme_constant_override("separation", 0)
	fans.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	HudUi.set_rect(fans, Vector2(_mx(587, 160), 192), Vector2(160, 30))
	var fans_caption := HudUi.label("FANS  ", 12, HudUi.LABEL_DIM)
	fans_caption.size_flags_vertical = Control.SIZE_SHRINK_END
	_fan_count = HudUi.label("0", 19, _light())
	_fan_total = HudUi.label(" / 16", 19)
	fans.add_child(fans_caption)
	fans.add_child(_fan_count)
	fans.add_child(_fan_total)
	_panel.add_child(fans)

	# 상태 배지 (멘탈 다운 / 운반 중)
	_badge_row = HBoxContainer.new()
	_badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_row.alignment = BoxContainer.ALIGNMENT_END if p2 else BoxContainer.ALIGNMENT_BEGIN
	HudUi.set_rect(_badge_row, Vector2(_mx(212, 406), 122), Vector2(406, 30))
	_badge = HudUi.pill("", 13, Color.WHITE, Color("4a3a66"), HudUi.INK, 2, Vector2(10, 2),
		Color(0.043, 0.02, 0.086, 0.7))
	_badge_row.add_child(_badge)
	_panel.add_child(_badge_row)

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
	_apply_state(_state, 3, null)


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


func _apply_state(state: State, respawn_secs: int, carried: FanClubData) -> void:
	_state = state
	var down := state == State.DOWN
	var carry := state == State.CARRY
	match state:
		State.DOWN:
			_aura.texture = _tex("aura_down")
		State.CARRY:
			_aura.texture = _tex("aura_carry")
		_:
			_aura.texture = _tex("aura")
	_state_edge.visible = carry
	_portrait.material = _grayscale_material() if down else null
	_down_label.visible = down
	_respawn_row.visible = down
	_carry_chip.visible = carry
	_carry_chip.texture = carried.sprite_texture if carried != null else null
	_badge_row.visible = down or carry
	var badge_label := HudUi.pill_label(_badge)
	var box := _badge.get_theme_stylebox("panel") as StyleBoxFlat
	if down:
		HudUi.pill_label(_respawn_row.get_child(0) as PanelContainer).text = "리스폰 %d" % respawn_secs
		badge_label.text = "멘탈 다운 · %d초 후 리스폰" % respawn_secs
		badge_label.label_settings.font_color = Color.WHITE
		box.bg_color = Color("4a3a66")
	elif carry:
		badge_label.text = "운반 중 · %s → 내 무대" % (carried.display_name if carried else "")
		badge_label.label_settings.font_color = Color("4a1236")
		box.bg_color = HudUi.GOLD


var _gray_mat: ShaderMaterial

func _grayscale_material() -> ShaderMaterial:
	if _gray_mat == null:
		_gray_mat = ShaderMaterial.new()
		_gray_mat.shader = GRAYSCALE
	return _gray_mat
