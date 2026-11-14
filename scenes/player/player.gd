extends CharacterBody2D
## 탑다운 2D 플레이어. input_prefix로 어떤 키 세트를 쓸지 정함.
## "p1" → WASD, "p2" → 방향키 (Project Settings > Input Map 참고)

@export var input_prefix: String = "p1"
@export var speed: float = 300.0
@export var color: Color = Color.WHITE

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.modulate = color


func _physics_process(_delta: float) -> void:
	# get_vector는 입력 벡터 길이를 최대 1로 제한함.
	# 그래서 대각선(→+↓)이어도 (0.707, 0.707)이 되어 속도가 빨라지지 않음.
	var direction := Input.get_vector(
		input_prefix + "_left",
		input_prefix + "_right",
		input_prefix + "_up",
		input_prefix + "_down"
	)
	velocity = direction * speed
	move_and_slide()
