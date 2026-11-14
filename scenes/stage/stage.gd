class_name IdolStage
extends Area2D

signal idol_entered(idol: IdolPlayer, stage: IdolStage)

@export var team_id: int = 1
@export var stage_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if stage_texture != null:
		sprite.texture = stage_texture
	body_entered.connect(_on_body_entered)
	add_to_group("stages")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("idols"):
		idol_entered.emit(body as IdolPlayer, self)
