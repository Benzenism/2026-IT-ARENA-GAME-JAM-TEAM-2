extends Control

signal completed

const DESIGN := Vector2(1920, 1200)
const INK := Color("160c26")
const PAPER := Color("fbf5f8")
const FADE_TIME := 0.3

# 컷이 하나씩 추가되는 전체 이미지. 필요하면 타이틀 씬의 Inspector에서 교체한다.
const DEFAULT_IMAGES := [
	preload("res://sprites/ui/intro/comic_1.png"),
	preload("res://sprites/ui/intro/comic_2.png"),
	preload("res://sprites/ui/intro/comic_3.png"),
	preload("res://sprites/ui/intro/comic_4.png"),
]

var panel_images: Array[Texture2D] = []
var _index := -1
var _panel: TextureRect
var _previous_panel: TextureRect
var _sequence: Tween
var _next: SlantButton
var _counter: Label
var _finished := false


func _ready() -> void:
	size = DESIGN
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = INK
	backdrop.size = DESIGN
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var heading := HudUi.label("두 아이돌의 이야기", 38, PAPER)
	heading.position = Vector2(150, 96)
	add_child(heading)
	_counter = HudUi.label("", 32, PAPER)
	_counter.position = Vector2(1610, 100)
	add_child(_counter)
	var hint := HudUi.label("아무 키나 눌러 계속", 28, PAPER)
	hint.position = Vector2(150, 1045)
	add_child(hint)
	_next = SlantButton.make("다음", Vector2(220, 64), true, 30)
	_next.position = Vector2(1470, 1030)
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(_advance)
	add_child(_next)
	var skip := SlantButton.make("건너뛰기", Vector2(230, 64), false, 30)
	skip.position = Vector2(1200, 1030)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(finish)
	add_child(skip)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	_advance()


func start() -> void:
	_finished = false
	_index = -1
	show()
	_advance()


func _advance() -> void:
	if _finished:
		return
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_remove_previous_panel()
	if is_instance_valid(_panel):
		_panel.modulate.a = 1.0
	_index += 1
	if _index >= DEFAULT_IMAGES.size():
		finish()
		return
	_counter.text = "%d / %d" % [_index + 1, DEFAULT_IMAGES.size()]
	_next.label_text = "설명 보기" if _index == DEFAULT_IMAGES.size() - 1 else "다음"
	_next.queue_redraw()
	var image: Texture2D = DEFAULT_IMAGES[_index]
	if _index < panel_images.size() and panel_images[_index] != null:
		image = panel_images[_index]
	_previous_panel = _panel
	_panel = HudUi.texture_rect(image, Vector2.ZERO, DESIGN)
	_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel.modulate.a = 0.0
	add_child(_panel)
	move_child(_panel, 2 if is_instance_valid(_previous_panel) else 1)
	_sequence = create_tween()
	_sequence.tween_property(_panel, "modulate:a", 1.0, FADE_TIME)
	_sequence.tween_callback(_remove_previous_panel)


func _remove_previous_panel() -> void:
	if is_instance_valid(_previous_panel):
		_previous_panel.queue_free()
	_previous_panel = null


func finish() -> void:
	if _finished:
		return
	_finished = true
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_remove_previous_panel()
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	hide()
	completed.emit()
