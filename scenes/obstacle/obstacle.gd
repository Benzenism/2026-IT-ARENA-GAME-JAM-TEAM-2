class_name ArenaObstacle
extends CharacterBody2D

@export var pushable: bool = false
@export var push_speed: float = 450.0
@export var push_deceleration: float = 850.0


func _physics_process(delta: float) -> void:
	if not pushable:
		return
	velocity = velocity.move_toward(Vector2.ZERO, push_deceleration * delta)
	move_and_slide()


func apply_push(direction: Vector2, incoming_speed: float = 0.0) -> void:
	if not pushable or direction.is_zero_approx():
		return
	var speed := maxf(push_speed, incoming_speed)
	velocity = direction.normalized() * speed
