class_name CaptureBaton
extends Area2D

signal picked_up(baton: CaptureBaton, idol: IdolPlayer)
signal returned(baton: CaptureBaton)

var club: FanClubData
var source_team_id: int
var target_team_id: int
var lifetime: float = 5.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var return_timer: Timer = $ReturnTimer


func setup(baton_club: FanClubData, source: int, target: int) -> void:
	club = baton_club
	source_team_id = source
	target_team_id = target
	sprite.texture = club.sprite_texture
	return_timer.start(lifetime)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	return_timer.timeout.connect(_on_return_timer_timeout)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("idols"):
		return
	var idol := body as IdolPlayer
	if idol.team_id == target_team_id:
		picked_up.emit(self, idol)
	elif idol.team_id == source_team_id:
		returned.emit(self)


func _on_return_timer_timeout() -> void:
	returned.emit(self)
