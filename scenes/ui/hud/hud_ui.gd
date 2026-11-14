@tool
class_name HudUi
extends RefCounted
## HUD 노드를 코드로 만들 때 쓰는 작은 헬퍼 모음.
## 좌표/크기는 모두 Figma 디자인(1920×1200) 기준 픽셀.

const INK := Color("1a0f2e")
const BLUE := Color("4c8dff")
const BLUE_LIGHT := Color("b3d1ff")
const BLUE_SHADE := Color("0f2560")
const PINK := Color("ff5fa8")
const PINK_LIGHT := Color("ffb3d9")
const PINK_SHADE := Color("5e1240")
const GOLD := Color("ffd36b")
const LABEL_DIM := Color(1, 1, 1, 0.65)


static func label(text: String, font_size: int, color: Color = Color.WHITE,
		shadow: Color = Color(0, 0, 0, 0), shadow_offset := Vector2(0, 2)) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	if shadow.a > 0.0:
		settings.shadow_color = shadow
		settings.shadow_offset = shadow_offset
		settings.shadow_size = 0
	l.label_settings = settings
	return l


## 둥근 알약 모양 배지 (player-tag, ribbon, state-badge 등)
static func pill(text: String, font_size: int, text_color: Color, bg: Color,
		border: Color = Color(0, 0, 0, 0), border_width: int = 0,
		pad := Vector2(10, 3), drop_shadow: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(999)
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	if drop_shadow.a > 0.0:
		box.shadow_color = drop_shadow
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 2)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", box)
	var l := label(text, font_size, text_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	return panel


static func pill_label(pill_panel: PanelContainer) -> Label:
	return pill_panel.get_child(0) as Label


static func texture_rect(tex: Texture2D, pos: Vector2, rect_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = pos
	t.size = rect_size
	return t


## 가로 그라디언트 텍스처 (stops: [[offset, Color], ...])
static func h_gradient(stops: Array) -> GradientTexture2D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	return tex


static func set_rect(c: Control, pos: Vector2, rect_size: Vector2) -> void:
	c.position = pos
	c.size = rect_size
