class_name CaptureMenu
extends Control

signal confirmed(team_id: int, club: FanClubData)
signal cancelled(team_id: int)

@export var team_id: int = 1
@export var input_prefix: String = "p1"

var options: Array[FanClubData] = []
var selection: int = 0
var active: bool = false

@onready var title_label: Label = %Title
@onready var options_label: Label = %Options
@onready var hint_label: Label = %Hint


func _ready() -> void:
	visible = false
	add_to_group("capture_menus")


func open_menu(clubs: Array[FanClubData]) -> void:
	if clubs.is_empty():
		return
	options = clubs
	selection = 0
	active = true
	visible = true
	_refresh()


func close_menu() -> void:
	active = false
	visible = false


func _process(_delta: float) -> void:
	if not active:
		return
	if Input.is_action_just_pressed(input_prefix + "_up"):
		selection = posmod(selection - 1, options.size())
		_refresh()
	elif Input.is_action_just_pressed(input_prefix + "_down"):
		selection = posmod(selection + 1, options.size())
		_refresh()
	elif Input.is_action_just_pressed(input_prefix + "_right"):
		_confirm_selection()


func _confirm_selection() -> void:
	if not active or options.is_empty():
		return
	var club := options[selection]
	close_menu()
	confirmed.emit(team_id, club)


func _refresh() -> void:
	title_label.text = "FAN CLUB CAPTURE"
	var rows: Array[String] = []
	for i in range(options.size()):
		var marker := ">" if i == selection else " "
		rows.append("%s %s" % [marker, options[i].display_name])
	options_label.text = "\n".join(rows)
	hint_label.text = "UP/DOWN SELECT    RIGHT CONFIRM"
