extends Camera2D
## target을 따라다니는 카메라. field가 지정되면 필드 밖은 안 보이도록 limit을 건다.
## 화면 분할 시 각 SubViewport 안에 하나씩 둔다.

@export var target: Node2D
@export var field: Field


func _ready() -> void:
	if field:
		var r := field.get_field_rect()
		limit_left = floori(r.position.x)
		limit_top = floori(r.position.y)
		limit_right = ceili(r.end.x)
		limit_bottom = ceili(r.end.y)
	if target:
		global_position = target.global_position
		reset_smoothing()


func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position
