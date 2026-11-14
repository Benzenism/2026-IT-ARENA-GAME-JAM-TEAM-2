class_name PlayerHud
extends Control

@export var team_id: int = 1

@onready var timer_label: Label = %Timer
@onready var hearts_label: Label = %Hearts
@onready var clubs_label: Label = %Clubs
@onready var population_label: Label = %Population
@onready var status_label: Label = %Status
@onready var club_icons: Array[TextureRect] = [
	%ClubIcon1, %ClubIcon2, %ClubIcon3, %ClubIcon4, %ClubIcon5
]


func _ready() -> void:
	add_to_group("player_huds")


func set_match_state(time_left: float, sudden_death: bool, game_over: bool,
		winner_team: int) -> void:
	if sudden_death:
		timer_label.text = "SUDDEN DEATH"
	else:
		var seconds := maxi(0, ceili(time_left))
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if game_over:
		status_label.text = "YOU WIN" if winner_team == team_id else "YOU LOSE"
	elif sudden_death:
		status_label.text = "SUDDEN DEATH"
	else:
		status_label.text = ""


func set_player_state(hp: int, max_hp: int, clubs: Array[FanClubData],
		population: int, population_limit: int) -> void:
	hearts_label.text = "♥".repeat(maxi(0, hp)) + "♡".repeat(maxi(0, max_hp - hp))
	clubs_label.text = "CLUBS  " + ", ".join(_club_names(clubs))
	population_label.text = "FANS  %d/%d" % [population, population_limit]
	for i in range(club_icons.size()):
		club_icons[i].visible = i < clubs.size()
		if i < clubs.size():
			club_icons[i].texture = clubs[i].sprite_texture


func _club_names(clubs: Array[FanClubData]) -> Array[String]:
	var names: Array[String] = []
	for club in clubs:
		names.append(str(club.display_name))
	return names
