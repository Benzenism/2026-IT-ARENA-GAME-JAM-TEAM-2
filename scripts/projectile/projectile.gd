class_name FanProjectile
extends Area2D

@export var speed: float = 260.0
@export var damage: int = 1
@export var lifetime: float = 4.8

var team_id: int = 1
var direction := Vector2.RIGHT
var arena_rect := Rect2(48, 230, 1344, 480)
var consumed: bool = false
var age: float = 0.0


func _ready() -> void:
	add_to_group("projectiles")
	direction = direction.normalized()
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if consumed:
		return
	age += delta
	global_position += direction * speed * delta
	if age >= lifetime or not arena_rect.grow(28).has_point(global_position):
		consumed = true
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if consumed or not body.has_method("take_damage") or body.get("team_id") == team_id:
		return
	if body.has_method("is_combat_active") and not body.is_combat_active():
		return
	consumed = true
	body.take_damage(damage)
	queue_free()


func _draw() -> void:
	var color := Color("83dfff") if team_id == 1 else Color("ff98bf")
	draw_circle(Vector2.ZERO, 9, Color(color, 0.09))
	draw_line(-direction * 12, Vector2.ZERO, Color(color, 0.3), 3, true)
	draw_circle(Vector2.ZERO, 4, color)
	draw_circle(-direction, 1.7, Color.WHITE)
