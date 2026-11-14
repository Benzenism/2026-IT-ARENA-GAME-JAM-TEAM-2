extends Node2D
## Short-lived visual only; projectile damage is handled separately.

const DURATION := 0.22
const PINK := Color("e845e0")
const BLUE := Color("0c56f6")

var team_id: int = 1
var elapsed := 0.0


func _ready() -> void:
	scale = Vector2.ONE * 1.5


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	scale = Vector2.ONE * (1.5 * (1.0 + progress * 2.0))
	modulate.a = 1.0 - progress


func _draw() -> void:
	var color := PINK if team_id == 1 else BLUE
	var light := color.lerp(Color.WHITE, 0.45)
	draw_circle(Vector2.ZERO, 8.0, Color(color, 0.10))
	draw_arc(Vector2.ZERO, 4.5, 0.0, TAU, 24, Color(light, 0.8), 1.5, true)
	for i in 4:
		var direction := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
		draw_line(direction * 4.0, direction * 7.0, Color(light, 0.8), 1.5, true)
