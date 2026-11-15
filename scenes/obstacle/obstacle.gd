class_name ArenaObstacle
extends CharacterBody2D

@export var pushable: bool = false
@export var push_speed: float = 450.0
@export var push_deceleration: float = 850.0

var arena_rect := Rect2()
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("arena_obstacles")


func _physics_process(delta: float) -> void:
	if not pushable:
		return
	velocity = velocity.move_toward(Vector2.ZERO, push_deceleration * delta)
	move_and_slide()
	_clamp_to_arena()


func apply_push(direction: Vector2, incoming_speed: float = 0.0) -> void:
	if not pushable or direction.is_zero_approx():
		return
	var speed := maxf(push_speed, incoming_speed)
	velocity = direction.normalized() * speed


func set_arena_rect(rect: Rect2) -> void:
	arena_rect = rect


func _clamp_to_arena() -> void:
	if arena_rect.size == Vector2.ZERO:
		return
	var rectangle := _collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return
	var half_size := rectangle.size * 0.5
	var min_position := arena_rect.position + half_size
	var max_position := arena_rect.end - half_size
	var clamped_position := global_position.clamp(min_position, max_position)
	if not is_equal_approx(clamped_position.x, global_position.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped_position.y, global_position.y):
		velocity.y = 0.0
	global_position = clamped_position
