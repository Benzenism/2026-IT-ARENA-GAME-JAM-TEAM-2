class_name PillButton
extends Button
## Figma "UI/Title Button" 스타일의 둥근 버튼. 마우스 호버/키보드 포커스 시 금색 글로우.
## 스타일 딕셔너리 키: a, b, c(채우기 3색), border, border_width, glow, glow_size, drop, drop_offset

const PILL := preload("res://scenes/ui/hud/pill.gdshader")
const PAD := 44.0

const PRIMARY := {
	"a": Color("4c8dff"), "b": Color("b48cff"), "c": Color("ff5fa8"),
	"border": Color.WHITE, "border_width": 4.0,
	"glow": Color(0.788, 0.659, 1.0, 0.6), "glow_size": 24.0,
	"drop": Color(0.102, 0.059, 0.18, 0.9), "drop_offset": 8.0,
}
const PRIMARY_HOVER := {
	"a": Color("4c8dff"), "b": Color("b48cff"), "c": Color("ff5fa8"),
	"border": Color.WHITE, "border_width": 6.0,
	"glow": Color(1.0, 0.827, 0.42, 0.95), "glow_size": 36.0,
	"drop": Color(0.102, 0.059, 0.18, 0.9), "drop_offset": 4.0,
}
const SECONDARY := {
	"a": Color(0.102, 0.059, 0.18, 0.78), "b": Color(0.102, 0.059, 0.18, 0.78), "c": Color(0.102, 0.059, 0.18, 0.78),
	"border": Color("e3d4ff"), "border_width": 3.0,
	"glow": Color(0, 0, 0, 0), "glow_size": 0.0,
	"drop": Color(0.043, 0.02, 0.086, 0.85), "drop_offset": 6.0,
}
const SECONDARY_HOVER := {
	"a": Color(0.227, 0.141, 0.4, 0.95), "b": Color(0.227, 0.141, 0.4, 0.95), "c": Color(0.227, 0.141, 0.4, 0.95),
	"border": Color("ffd36b"), "border_width": 3.0,
	"glow": Color(1.0, 0.827, 0.42, 0.6), "glow_size": 20.0,
	"drop": Color(0.043, 0.02, 0.086, 0.85), "drop_offset": 6.0,
}

var normal_style: Dictionary = PRIMARY
var hover_style: Dictionary = PRIMARY_HOVER
var _bg: ColorRect
var _mat: ShaderMaterial
var _content: HBoxContainer
var _icon_circles: Array[Panel] = []


## label: 버튼 글자, size_px: 버튼 크기, primary: 그라디언트(true) / 어두운(false)
## icon: "stars"(양옆 별) / "question"(왼쪽 ? 원) / ""
static func make(label: String, size_px: Vector2, primary: bool, font_size: int,
		icon: String = "") -> PillButton:
	var b := PillButton.new()
	b.custom_minimum_size = size_px
	b.size = size_px
	b.normal_style = PRIMARY if primary else SECONDARY
	b.hover_style = PRIMARY_HOVER if primary else SECONDARY_HOVER
	b._build(label, size_px, font_size, icon, primary)
	return b


func _build(label: String, size_px: Vector2, font_size: int, icon: String, primary: bool) -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	_mat = ShaderMaterial.new()
	_mat.shader = PILL
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.material = _mat
	_bg.position = Vector2(-PAD, -PAD)
	_bg.size = size_px + Vector2(PAD * 2, PAD * 2)
	add_child(_bg)

	_content = HBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 14)
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	var star := preload("res://sprites/ui/title/star_icon.svg")
	if icon == "stars":
		_content.add_child(_icon_rect(star))
	elif icon == "question":
		_content.add_child(_question_icon())
	var l := HudUi.label(label, font_size, Color.WHITE,
		Color(0.165, 0.09, 0.282, 0.8) if primary else Color(0, 0, 0, 0), Vector2(0, 3))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.add_child(l)
	if icon == "stars":
		_content.add_child(_icon_rect(star))

	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	button_down.connect(func(): _content.position.y = 3.0)
	button_up.connect(func(): _content.position.y = 0.0)
	_apply(normal_style)


func _icon_rect(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(34, 34)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _question_icon() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(34, 34)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e3d4ff")
	box.set_corner_radius_all(999)
	p.add_theme_stylebox_override("panel", box)
	var q := HudUi.label("?", 22, Color("1a0f2e"))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(q)
	_icon_circles.append(p)
	return p


func _refresh() -> void:
	var lit := has_focus() or is_hovered()
	_apply(hover_style if lit else normal_style)


func _apply(s: Dictionary) -> void:
	_mat.set_shader_parameter("pill_size", size if size.x > 0 else custom_minimum_size)
	_mat.set_shader_parameter("pad", PAD)
	_mat.set_shader_parameter("color_a", s["a"])
	_mat.set_shader_parameter("color_b", s["b"])
	_mat.set_shader_parameter("color_c", s["c"])
	_mat.set_shader_parameter("border_color", s["border"])
	_mat.set_shader_parameter("border_width", s["border_width"])
	_mat.set_shader_parameter("glow_color", s["glow"])
	_mat.set_shader_parameter("glow_size", s["glow_size"])
	_mat.set_shader_parameter("drop_color", s["drop"])
	_mat.set_shader_parameter("drop_offset", s["drop_offset"])
	for c in _icon_circles:
		var box := c.get_theme_stylebox("panel") as StyleBoxFlat
		box.bg_color = Color("ffd36b") if s == hover_style else Color("e3d4ff")
