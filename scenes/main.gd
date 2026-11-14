extends Control
## 좌우 화면 분할. 월드는 왼쪽 SubViewport 안에 하나만 있고,
## 오른쪽 SubViewport가 같은 World2D를 공유해서 같은 필드를 다른 카메라로 비춘다.

@onready var _left_viewport: SubViewport = %LeftViewport
@onready var _right_viewport: SubViewport = %RightViewport


func _ready() -> void:
	_right_viewport.world_2d = _left_viewport.world_2d
