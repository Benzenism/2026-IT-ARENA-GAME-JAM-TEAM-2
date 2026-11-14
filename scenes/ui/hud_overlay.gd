@tool
class_name HudOverlay
extends Control
## Figma "HUD/Overlay 1920×1200" 인게임 HUD.
## 부드러운 화면 구분선 · 하단 공통 베이스(레일 + 시계 탭) · 왼쪽 아래 P1 · 오른쪽 아래 P2.
## 디자인 픽셀(가로 1920) 기준으로 만든 Canvas를 화면 가로 폭에 맞춰 통째로 스케일한다.

const DESIGN_WIDTH := 1920.0
const CLOCK_HEIGHT := 230.0
const GLOW_BOTTOM := 130.0 # 구분선 글로우는 시계 탭 리본 위(디자인 y=1070)에서 끝남

# Godot의 SVG 렌더러(ThorVG)는 필터(그림자/글로우)가 걸린 그룹에서 그림자만 그리고
# 도형은 빠뜨린다. 그래서 원본 SVG = 글로우 레이어, *_shape.svg(필터 제거) = 도형 레이어로 겹쳐 쓴다.
const CLOCK_BASE := preload("res://sprites/ui/hud/clock_base.svg")
const CLOCK_BASE_SHAPE := preload("res://sprites/ui/hud/clock_base_shape.svg")
const CLOCK_TEX := {
	false: {
		"tab": preload("res://sprites/ui/hud/clock_tab_fill.svg"),
		"tab_shape": preload("res://sprites/ui/hud/clock_tab_fill_shape.svg"),
		"band": preload("res://sprites/ui/hud/clock_accent_band.svg"),
		"outline": preload("res://sprites/ui/hud/clock_outline.svg"),
	},
	true: {
		"tab": preload("res://sprites/ui/hud/clock_tab_fill_sudden.svg"),
		"tab_shape": preload("res://sprites/ui/hud/clock_tab_fill_sudden_shape.svg"),
		"band": preload("res://sprites/ui/hud/clock_accent_band_sudden.svg"),
		"outline": preload("res://sprites/ui/hud/clock_outline_sudden.svg"),
	},
}
const LINE_CAP := preload("res://sprites/ui/hud/divider_line_cap.svg")
const LINE_CAP_SHAPE := preload("res://sprites/ui/hud/divider_line_cap_shape.svg")

var _canvas: Control
var _huds: Array[PlayerHud] = []
var _sudden := false
var _tab_glow: TextureRect
var _tab_fill: TextureRect
var _accent_band: TextureRect
var _outline: TextureRect
var _time_label: Label
var _time_ribbon: Control
var _sudden_label: Label
var _sudden_sub: Label
var _sudden_ribbon: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sudden := false
	var total_clubs := 0
	for hud in _huds:
		sudden = sudden or hud.sudden_death
		total_clubs += hud.owned_club_count()
	if sudden != _sudden:
		_set_sudden(sudden)
	# 팬클럽은 두 팀이 나눠 가지므로, 칩 슬롯 수 = 두 팀 보유 수의 합 (게임의 팬클럽 수를 따라감)
	if total_clubs > 0:
		for hud in _huds:
			hud.total_clubs = total_clubs


func _layout() -> void:
	if _canvas == null or size.x <= 0.0:
		return
	var s := size.x / DESIGN_WIDTH
	_canvas.scale = Vector2(s, s)
	_canvas.size = size / s


func _build() -> void:
	for child in get_children():
		child.free()
	_huds.clear()

	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_canvas.add_child(_make_divider())
	_canvas.add_child(_make_clock())
	for team in [1, 2]:
		var hud := PlayerHud.new()
		hud.name = "Player%dHud" % team
		hud.team_id = team
		_canvas.add_child(hud)
		_huds.append(hud)

	for tex in [LINE_CAP, LINE_CAP_SHAPE]:
		var cap := HudUi.texture_rect(tex, Vector2.ZERO, Vector2(25, 25))
		_anchor(cap, 0.5, 1.0, 0.5, 1.0, Rect2(-12.5, -146, 25, 25))
		_canvas.add_child(cap)

	_set_sudden(false)


## anchors + offsets(rect.position / rect.end)를 한 번에 지정
func _anchor(c: Control, left: float, top: float, right: float, bottom: float, rect: Rect2) -> void:
	c.anchor_left = left
	c.anchor_top = top
	c.anchor_right = right
	c.anchor_bottom = bottom
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y


func _make_divider() -> Control:
	var divider := Control.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(divider, 0.5, 0.0, 0.5, 1.0, Rect2(-60, 0, 120, 0))

	var ink := Color(18 / 255.0, 10 / 255.0, 32 / 255.0)
	var soft := HudUi.texture_rect(HudUi.h_gradient([
		[0.0, Color(ink, 0.0)], [0.32, Color(ink, 0.5)], [0.45, Color(ink, 0.96)],
		[0.5, Color(ink, 1.0)], [0.55, Color(ink, 0.96)], [0.68, Color(ink, 0.5)],
		[1.0, Color(ink, 0.0)],
	]), Vector2.ZERO, Vector2.ZERO)
	soft.name = "SoftEdge"
	_anchor(soft, 0, 0, 1, 1, Rect2())
	divider.add_child(soft)

	var glow := Control.new()
	glow.name = "TeamGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(glow, 0, 0, 1, 1, Rect2(0, 0, 0, -GLOW_BOTTOM))
	divider.add_child(glow)

	var blue := HudUi.BLUE
	var pink := HudUi.PINK
	var lilac := Color("c9a8ff")
	var bars := [
		# [x, width, gradient stops]
		[0.0, 58.0, [[0.0, Color(blue, 0.0)], [0.55, Color(blue, 0.08)], [1.0, Color(blue, 0.45)]]],
		[62.0, 58.0, [[0.0, Color(pink, 0.45)], [0.45, Color(pink, 0.08)], [1.0, Color(pink, 0.0)]]],
		[55.0, 10.0, [[0.0, Color(lilac, 0.0)], [0.3, Color(lilac, 0.35)], [0.7, Color(lilac, 0.35)],
			[1.0, Color(lilac, 0.0)]]],
		[58.5, 3.0, [[0.0, Color("8fb4ff")], [0.5, Color("e3d4ff")], [1.0, Color("ffa6d2")]]],
	]
	for bar in bars:
		var rect := HudUi.texture_rect(HudUi.h_gradient(bar[2]), Vector2.ZERO, Vector2.ZERO)
		_anchor(rect, 0, 0, 0, 1, Rect2(bar[0], 0, bar[1], 0))
		glow.add_child(rect)
	return divider


func _make_clock() -> Control:
	var clock := Control.new()
	clock.name = "Clock"
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.clip_contents = true
	_anchor(clock, 0.0, 1.0, 0.0, 1.0, Rect2(0, -CLOCK_HEIGHT, DESIGN_WIDTH, CLOCK_HEIGHT))

	clock.add_child(HudUi.texture_rect(CLOCK_BASE, Vector2(-30, 52.32), Vector2(1980, 204.68)))
	clock.add_child(HudUi.texture_rect(CLOCK_BASE_SHAPE, Vector2(-30, 52.32), Vector2(1980, 204.68)))
	_tab_glow = HudUi.texture_rect(null, Vector2(797.87, 92), Vector2(324.27, 139))
	clock.add_child(_tab_glow)
	_tab_fill = HudUi.texture_rect(null, Vector2(797.87, 92), Vector2(324.27, 139))
	clock.add_child(_tab_fill)
	_accent_band = HudUi.texture_rect(null, Vector2(-20, 26.94), Vector2(1960, 190.43))
	clock.add_child(_accent_band)
	_outline = HudUi.texture_rect(null, Vector2(-20, 60.78), Vector2(1960.47, 157.32))
	clock.add_child(_outline)

	# 기본: 카운트다운 (게임 쪽에서 "match_timer" 그룹의 Label 텍스트를 갱신)
	_time_label = HudUi.label("04:00", 52, Color.WHITE, Color("b48cff"), Vector2(0, 3))
	_time_label.name = "MatchTimer"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudUi.set_rect(_time_label, Vector2(760, 122), Vector2(400, 74))
	if not Engine.is_editor_hint():
		_time_label.add_to_group("match_timer")
	clock.add_child(_time_label)
	_time_ribbon = _ribbon("TIME", Color("c9a8ff"), Color("2a1748"))
	clock.add_child(_time_ribbon)

	# 서든데스
	_sudden_label = HudUi.label("서든데스", 38, Color.WHITE, Color("ff3b5c"), Vector2(0, 3))
	_sudden_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sudden_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudUi.set_rect(_sudden_label, Vector2(760, 120), Vector2(400, 56))
	clock.add_child(_sudden_label)
	_sudden_sub = HudUi.label("먼저 1개 운반하면 승리", 13, Color(1, 1, 1, 0.8))
	_sudden_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudUi.set_rect(_sudden_sub, Vector2(760, 170), Vector2(400, 22))
	clock.add_child(_sudden_sub)
	_sudden_ribbon = _ribbon("SUDDEN DEATH", Color("ff3b5c"), Color.WHITE)
	clock.add_child(_sudden_ribbon)
	return clock


func _ribbon(text: String, bg: Color, fg: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	HudUi.set_rect(row, Vector2(760, 98), Vector2(400, 24))
	row.add_child(HudUi.pill(text, 12, fg, bg, HudUi.INK, 3, Vector2(12, 0)))
	return row


func _set_sudden(sudden: bool) -> void:
	_sudden = sudden
	var tex: Dictionary = CLOCK_TEX[sudden]
	_tab_glow.texture = tex["tab"]
	_tab_fill.texture = tex["tab_shape"]
	_accent_band.texture = tex["band"]
	_outline.texture = tex["outline"]
	_time_label.visible = not sudden
	_time_ribbon.visible = not sudden
	_sudden_label.visible = sudden
	_sudden_sub.visible = sudden
	_sudden_ribbon.visible = sudden
