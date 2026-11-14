class_name LabUI
extends RefCounted

const TEXT := Color("e9efff")
const MUTED := Color("8c9ab5")
const MINT := Color("7ce8c0")
const LILAC := Color("bfa6ff")
const CYAN := Color("7ddcff")
const PINK := Color("ff92b9")
const BORDER := Color("26334b")
const FONT: SystemFont = preload("res://assets/ui/lab_font.tres")


static func label(parent: Node, value: String, pos: Vector2, size: Vector2,
		font_size: int = 16, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = value
	node.position = pos
	node.size = size
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func panel(color: Color = Color("111b2d"), border: Color = BORDER,
		radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


static func button(parent: Node, text: String, pos: Vector2, size: Vector2,
		accent: Color = CYAN) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", 15)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", accent)
	node.add_theme_color_override("font_disabled_color", accent)
	node.add_theme_stylebox_override("normal", panel(Color("162136")))
	node.add_theme_stylebox_override("hover", panel(Color("202e48"), accent))
	node.add_theme_stylebox_override("pressed", panel(Color("233551"), accent))
	node.add_theme_stylebox_override("focus", panel(Color(0, 0, 0, 0), accent))
	parent.add_child(node)
	return node
