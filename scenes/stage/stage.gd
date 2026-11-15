class_name IdolStage
extends Area2D

signal idol_entered(idol: IdolPlayer, stage: IdolStage)

@export var team_id: int = 1
@export var stage_texture: Texture2D

const PULSE_PERIOD := 3.0
const ENTRY_FLASH_DURATION := 0.18
const ENTRY_FLASH_BRIGHTNESS := 0.25

@onready var sprite: Sprite2D = $Sprite2D
var pulse_time := 0.0
var entry_flash_remaining := 0.0


func _ready() -> void:
	if stage_texture != null:
		sprite.texture = stage_texture
	body_entered.connect(_on_body_entered)
	add_to_group("stages")


func _process(delta: float) -> void:
	pulse_time = fmod(pulse_time + delta, PULSE_PERIOD)
	entry_flash_remaining = maxf(0.0, entry_flash_remaining - delta)
	var pulse_progress := pulse_time / PULSE_PERIOD
	var alpha := lerpf(0.8, 1.0, (sin(pulse_progress * TAU) + 1.0) * 0.5)
	var flash_strength := ENTRY_FLASH_BRIGHTNESS \
			* entry_flash_remaining / ENTRY_FLASH_DURATION
	sprite.modulate = Color(1.0 + flash_strength, 1.0 + flash_strength,
			1.0 + flash_strength, alpha)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("idols"):
		entry_flash_remaining = ENTRY_FLASH_DURATION
		idol_entered.emit(body as IdolPlayer, self)
