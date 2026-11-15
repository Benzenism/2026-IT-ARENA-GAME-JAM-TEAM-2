class_name SlantButton
extends Button
## 타이틀 Figma 스타일의 평행사변형 버튼 (기울어진 몸통 + 하드 섀도).
##  - 이미지 모드: Figma에서 뽑은 기본/호버 이미지를 바꿔 끼움 (타이틀 메뉴)
##  - 그리기 모드: 같은 모양을 코드로 그림 (결과 화면 등, 아무 글자나)
## 호버 판정은 보이는 평행사변형 몸통 안쪽만 (빈 모서리·그림자는 제외).
## 마우스를 쓰는 중엔 마우스가 올라간 버튼만, 키보드/패드를 쓰는 중엔 포커스된 버튼만 강조.

const INK := Color("160c26")
const PAPER := Color("f7f6fa")
const RED := Color("ff2e6e")
const BLUE := Color("4f8fff")
const YELLOW := Color("ffd36b")
const PINK_TOP := Color("ff6496")
const PINK_BOTTOM := Color("e0144f")
const SLANT := 0.27   ## 높이 대비 윗변이 오른쪽으로 밀린 비율 (Figma 약 15°)

## 마지막 입력이 키보드/패드였는지 — 모든 SlantButton이 공유
static var _keyboard_mode := true

var body_size := Vector2(300, 74)
var primary := true
var deco := ""             ## "stars" / "question" / ""
var label_text := ""
var font_size := 32
var _normal_tex: TextureRect
var _hover_tex: TextureRect
var _lit := false


## 코드로 그리는 버튼
static func make(text_: String, body: Vector2, primary_: bool, font_size_: int = 32,
		deco_: String = "") -> SlantButton:
	var b := SlantButton.new()
	b.label_text = text_
	b.body_size = body
	b.primary = primary_
	b.font_size = font_size_
	b.deco = deco_
	b._setup(body + Vector2(14, 14))
	return b


## Figma 이미지(2x)로 그리는 버튼. hover_offset: 기본 이미지 대비 호버 이미지 위치(1x)
## body: 보이는 몸통(평행사변형의 바운딩 박스) 크기 — 호버 판정에 사용
static func from_images(normal: Texture2D, hover: Texture2D, hover_offset: Vector2,
		body: Vector2) -> SlantButton:
	var b := SlantButton.new()
	b.body_size = body
	b._setup(normal.get_size() / 2.0)
	b._normal_tex = HudUi.texture_rect(normal, Vector2.ZERO, normal.get_size() / 2.0)
	b._hover_tex = HudUi.texture_rect(hover, hover_offset, hover.get_size() / 2.0)
	b._hover_tex.visible = false
	b.add_child(b._normal_tex)
	b.add_child(b._hover_tex)
	return b


func _setup(min_size: Vector2) -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = min_size
	size = min_size
	pivot_offset = body_size / 2.0
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, empty)
	mouse_entered.connect(func():
		_keyboard_mode = false
		grab_focus()
		_refresh())
	mouse_exited.connect(_refresh)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(func(): scale = Vector2(0.97, 0.97))
	button_up.connect(func(): scale = Vector2.ONE)


func _ready() -> void:
	_refresh()


func _input(event: InputEvent) -> void:
	var was := _keyboard_mode
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 0.5:
		_keyboard_mode = false
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_keyboard_mode = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_keyboard_mode = true
	if was != _keyboard_mode or _lit != _want_lit():
		_refresh()


## 보이는 몸통(평행사변형) 안쪽만 마우스 판정
func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _body_poly(Vector2.ZERO))


func _want_lit() -> bool:
	if disabled:
		return false
	return has_focus() if _keyboard_mode else is_hovered()


func _refresh() -> void:
	_lit = _want_lit()
	if _normal_tex:
		_hover_tex.visible = _lit
		_normal_tex.visible = not _lit
	else:
		queue_redraw()


func _body_poly(offset: Vector2) -> PackedVector2Array:
	var w := body_size.x
	var h := body_size.y
	var k := h * SLANT
	return PackedVector2Array([
		offset + Vector2(k, 0), offset + Vector2(w, 0),
		offset + Vector2(w - k, h), offset + Vector2(0, h)])


# --- 그리기 모드 ------------------------------------------------------------------

func _draw() -> void:
	if _normal_tex:
		return
	var h := body_size.y
	var lift := Vector2(-3, -3) if _lit else Vector2.ZERO   # 호버 시 몸통이 살짝 뜨고 그림자가 길어짐
	var shadow_off := Vector2(10, 10) if _lit else Vector2(7, 7)
	var body := _body_poly(lift)
	var ink_text := false

	if primary:
		if _lit:
			# 은은한 핑크 글로우
			for i in range(6, 0, -1):
				for poly in Geometry2D.offset_polygon(body, i * 3.0):
					draw_colored_polygon(poly, Color(1.0, 0.55, 0.75, 0.05))
		draw_colored_polygon(_body_poly(lift + shadow_off), INK if _lit else RED)
		if _lit:
			var top := PINK_TOP
			var bot := PINK_BOTTOM
			draw_polygon(body, PackedColorArray([top, top, bot, bot]))
		else:
			draw_colored_polygon(body, INK)
		_draw_border(body, Color.WHITE, 3.0)
	else:
		draw_colored_polygon(_body_poly(lift + shadow_off), BLUE if _lit else Color(0.69, 0.72, 0.8))
		draw_colored_polygon(body, INK if _lit else PAPER)
		_draw_border(body, Color(PAPER, 0.9) if _lit else INK, 2.0 if _lit else 2.5)
		ink_text = not _lit

	var text_col := INK if ink_text else Color.WHITE
	var font := get_theme_default_font()
	var ts := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var icon_w := 0.0
	if deco == "question":
		icon_w = font_size * 0.85 + 12.0
	var center := lift + body_size / 2.0
	var text_x := center.x - (ts.x + icon_w) / 2.0 + icon_w
	var baseline := center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(font, Vector2(text_x, baseline), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, text_col)

	if deco == "stars":
		var s := font_size * 0.32
		_draw_sparkle(Vector2(text_x - s * 2.0, center.y + 1), s,
			Color.WHITE if _lit else Color("ff8fb8"))
		_draw_sparkle(Vector2(text_x + ts.x + s * 1.7, center.y - h * 0.14), s * 0.62, YELLOW)
	elif deco == "question":
		var r := font_size * 0.42
		var c := Vector2(text_x - 12.0 - r, center.y)
		draw_arc(c, r, 0, TAU, 32, text_col, 2.0, true)
		var q_size := int(font_size * 0.55)
		var qs := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, q_size)
		draw_string(font, Vector2(c.x - qs.x / 2.0,
			c.y + (font.get_ascent(q_size) - font.get_descent(q_size)) / 2.0), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, q_size, text_col)

	# 아래쪽 액센트 막대 (주: 오른쪽 빨강/흰색, 보조: 왼쪽 파랑)
	var bar_h := maxf(3.0, h * 0.05)
	if primary:
		draw_rect(Rect2(lift + Vector2(body_size.x * 0.76, h * 0.86), Vector2(body_size.x * 0.14, bar_h)),
			Color.WHITE if _lit else RED)
	else:
		draw_rect(Rect2(lift + Vector2(body_size.x * 0.11, h * 0.84), Vector2(body_size.x * 0.13, bar_h)), BLUE)


func _draw_border(poly: PackedVector2Array, col: Color, width: float) -> void:
	var inset := Geometry2D.offset_polygon(poly, -width / 2.0, Geometry2D.JOIN_MITER)
	var pts: PackedVector2Array = inset[0] if inset.size() > 0 else poly
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)


func _draw_sparkle(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a := i * PI / 4.0 - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.3
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
