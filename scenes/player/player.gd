extends CharacterBody2D
## 탑다운 2D 플레이어. input_prefix로 어떤 키 세트를 쓸지 정함.
## "p1" → WASD, "p2" → 방향키 (Project Settings > Input Map 참고)

@export var input_prefix: String = "p1"
@export var speed: float = 300.0
@export var color: Color = Color.WHITE
@export var team_id: int = 1
@export var max_hp: int = 3

signal health_changed(current_hp: int, maximum_hp: int)
signal respawned

var hp: int
var spawn_position: Vector2
var invulnerability: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("idols")
	_sprite.modulate = color
	hp = max_hp
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
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


func is_combat_active() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	if amount <= 0 or invulnerability > 0 or not is_combat_active():
		return
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp == 0:
		respawn()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	hp = max_hp
	invulnerability = 1.0
	reset_physics_interpolation()
	health_changed.emit(hp, max_hp)
	respawned.emit()
