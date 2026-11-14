@tool
class_name StealCutIn
extends Control
## Figma "Steal Cut-in" — 팬클럽을 뺏었을 때 나오는 컷인.
## URI(P1)는 왼쪽, HANA(P2)는 오른쪽에서 등장. 약 1.4초 동안 재생되며 그동안 게임은 일시정지.
## 디자인 좌표(1920×1200) 기준. HudOverlay의 Canvas 안에 있어서 HUD와 같은 비율로 스케일된다.
##
## 사용: get_tree().call_group("steal_cutin", "play_steal", team_id)

const DESIGN := Vector2(1920, 1200)

# 타임라인 (초) — Figma: 1 Flash 0.00 / 2 Slide-in 0.05 / 3 Hold 0.25–1.15 / 4 Out 1.15
const T_SLIDE := 0.05
const T_HOLD := 0.25
const T_OUT := 1.15
const T_END := 1.40

const SILHOUETTE := preload("res://scenes/ui/hud/silhouette.gdshader")
const SPARKLE := preload("res://sprites/ui/hud/sparkle_12.svg")

## 팀별 스타일. P2는 P1을 좌우 반전한 배치.
const STYLE := {
	1: {
		"name": "URI",
		"art": preload("res://sprites/ui/cutin/uri_full.png"),
		"burst": preload("res://sprites/ui/cutin/burst_uri.svg"),
		"burst_pos": Vector2(-230, -150),
		"angle": -8.0,
		"band": [[0.0, Color("8fb4ff")], [0.2, Color("4c8dff")], [0.45, Color("0f2560")], [1.0, Color("081638")]],
		"glow": Color("8fb4ff"),
		"stripe": Color(0.561, 0.706, 1.0, 0.85),
		"accent": Color("4c8dff"),
		"ink": Color("0f2560"),
		"shade": Color(0.031, 0.086, 0.22),
		"watermark": Color(0.788, 0.867, 1.0, 0.2),
		"watermark_center": Vector2(560, 360),
		"char_rect": Rect2(290, 40, 538, 1160),
		"char_shadow": Vector2(-26, 16),
		"title_center": Vector2(1360, 556),
		"sparkles": [[180, 180, 46], [760, 120, 30], [880, 900, 40], [1100, 250, 26], [1720, 330, 52],
			[1580, 880, 34], [1240, 1010, 22], [110, 820, 28], [640, 1050, 20]],
	},
	2: {
		"name": "HANA",
		"art": preload("res://sprites/ui/cutin/hana_full.png"),
		"burst": preload("res://sprites/ui/cutin/burst_hana.svg"),
		"burst_pos": Vector2(650, -150),
		"angle": 8.0,
		"band": [[0.0, Color("2e0820")], [0.55, Color("5e1240")], [0.8, Color("ff5fa8")], [1.0, Color("ffa6d2")]],
		"glow": Color("ffa6d2"),
		"stripe": Color(1.0, 0.651, 0.824, 0.85),
		"accent": Color("ff5fa8"),
		"ink": Color("5e1240"),
		"shade": Color(0.18, 0.031, 0.125),
		"watermark": Color(1.0, 0.839, 0.918, 0.2),
		"watermark_center": Vector2(1360, 360),
		"char_rect": Rect2(1013, 40, 617, 1160),
		"char_shadow": Vector2(26, 16),
		"title_center": Vector2(560, 556),
		"sparkles": [[1694, 180, 46], [1130, 120, 30], [1000, 900, 40], [794, 250, 26], [148, 330, 52],
			[306, 880, 34], [658, 1010, 22], [1782, 820, 28], [1260, 1050, 20]],
	},
}

## 띠 위 스피드 라인 [x, y, 길이, 두께, 불투명도] (Figma band-main 좌표)
const SPEED_LINES := [
	[783, 101, 200, 8.4, 0.5], [2357, 362, 679, 4.3, 0.4], [2577, 116, 816, 6.5, 0.31],
	[-17, 328, 837, 6.9, 0.36], [218, 246, 1030, 7.7, 0.61], [1763, 438, 820, 6.5, 0.6],
	[2646, 159, 535, 4.3, 0.18], [803, 450, 468, 5.0, 0.41], [-1, 131, 856, 8.1, 0.41],
	[456, 436, 658, 5.0, 0.13], [2059, 444, 529, 4.4, 0.38], [764, 175, 349, 4.8, 0.33],
	[1888, 112, 499, 5.7, 0.6], [1959, 304, 612, 8.0, 0.38], [2995, 190, 654, 6.8, 0.49],
	[992, 159, 426, 6.1, 0.32], [178, 393, 915, 8.1, 0.14], [65, 478, 566, 3.1, 0.22],
	[1354, 285, 769, 3.0, 0.18], [2828, 425, 1030, 8.2, 0.6], [-164, 119, 885, 3.9, 0.14],
	[587, 356, 201, 6.3, 0.37], [2799, 113, 819, 3.7, 0.31], [1463, 1, 1005, 2.8, 0.6],
	[-129, 432, 773, 8.5, 0.2], [2110, 128, 1072, 6.0, 0.22], [-22, 369, 388, 6.0, 0.49],
	[-89, 53, 843, 5.5, 0.61], [2836, 18, 318, 6.8, 0.59], [3045, 367, 975, 8.9, 0.33],
	[2800, 191, 423, 7.1, 0.23], [1700, 169, 564, 8.2, 0.44], [2266, 203, 861, 4.3, 0.21],
	[3180, 304, 481, 8.9, 0.58],
]

var _playing := false
var _queue: Array[int] = []
var _was_paused := false
var _tween: Tween

var _dim: ColorRect
var _flash: ColorRect
var _stage: Control
var _burst: TextureRect
var _band: Control
var _lines: Control
var _watermark: Label
var _character: Control
var _char_shadow: TextureRect
var _title: Control
var _sparkles: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 게임을 일시정지한 동안에도 컷인 애니메이션은 돌아가야 함
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not Engine.is_editor_hint():
		add_to_group("steal_cutin")


func is_playing() -> bool:
	return _playing


## 팬클럽을 뺏은 팀(1 = URI, 2 = HANA)의 컷인 재생. 재생 중이면 끝난 뒤 이어서 재생.
func play_steal(team_id: int) -> void:
	if not STYLE.has(team_id):
		return
	if _playing:
		_queue.append(team_id)
		return
	_playing = true
	_build(team_id)
	visible = true
	modulate = Color.WHITE
	_was_paused = get_tree().paused
	get_tree().paused = true
	_animate(team_id)


func _finish() -> void:
	visible = false
	_playing = false
	for child in get_children():
		child.queue_free()
	if not _queue.is_empty():
		play_steal(_queue.pop_front())
		return
	get_tree().paused = _was_paused


# --- 구성 ----------------------------------------------------------------------

func _build(team_id: int) -> void:
	for child in get_children():
		child.free()
	_sparkles.clear()
	var s: Dictionary = STYLE[team_id]

	_dim = ColorRect.new()
	_dim.color = Color(0.043, 0.02, 0.086, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	# 디자인 1200 높이를 화면 가운데에 둠 (화면 비율이 달라도 가운데 정렬)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = DESIGN
	_stage.position = Vector2(0, (size.y - DESIGN.y) / 2.0)
	add_child(_stage)

	_burst = HudUi.texture_rect(s["burst"], s["burst_pos"], Vector2(1500, 1500))
	_burst.pivot_offset = Vector2(750, 750)
	_stage.add_child(_burst)

	_stage.add_child(_make_band(s))

	_watermark = HudUi.label(s["name"], 420, s["watermark"])
	_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var wm_size := Vector2(1400, 600)
	HudUi.set_rect(_watermark, s["watermark_center"] - wm_size / 2.0, wm_size)
	_watermark.pivot_offset = wm_size / 2.0
	_watermark.rotation_degrees = s["angle"]
	_stage.add_child(_watermark)

	_stage.add_child(_make_character(s))
	_stage.add_child(_make_title(s, team_id))

	for sp in s["sparkles"]:
		var size_px := float(sp[2])
		var star := HudUi.texture_rect(SPARKLE, Vector2(sp[0], sp[1]), Vector2(size_px, size_px))
		star.pivot_offset = Vector2(size_px, size_px) / 2.0
		_stage.add_child(star)
		_sparkles.append(star)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)


func _make_band(s: Dictionary) -> Control:
	# 3400×660 띠를 (960, 600) 중심으로 기울여 배치
	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.size = Vector2(3400, 660)
	_band.position = Vector2(960, 600) - _band.size / 2.0
	_band.pivot_offset = _band.size / 2.0
	_band.rotation_degrees = s["angle"]

	var glow_color: Color = s["glow"]
	var glow := HudUi.texture_rect(_v_gradient([[0.0, Color(glow_color, 0.0)],
		[0.5, Color(glow_color, 0.28)], [1.0, Color(glow_color, 0.0)]]), Vector2.ZERO, _band.size)
	_band.add_child(glow)

	var main := Control.new()
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.clip_contents = true
	HudUi.set_rect(main, Vector2(0, 90), Vector2(3400, 480))
	main.add_child(HudUi.texture_rect(HudUi.h_gradient(s["band"]), Vector2.ZERO, main.size))

	# 스피드 라인: 밝은 머리 쪽으로 흘러감 (URI = 왼쪽, HANA = 오른쪽)
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.size = main.size
	var p2: bool = s["angle"] > 0.0
	var line_tex := HudUi.h_gradient([[0.0, Color.WHITE], [1.0, Color(1, 1, 1, 0)]])
	for copy in [0.0, 3400.0]: # 스크롤해도 비지 않게 한 벌 더
		for l in SPEED_LINES:
			var x: float = l[0] + copy
			var line := HudUi.texture_rect(line_tex, Vector2(x, l[1]), Vector2(l[2], l[3]))
			line.modulate.a = l[4]
			line.flip_h = p2
			_lines.add_child(line)
	main.add_child(_lines)

	var steal_text := HudUi.label("STEAL!  STEAL!  STEAL!  STEAL!  STEAL!", 230, Color(1, 1, 1, 0))
	steal_text.label_settings.outline_size = 5
	steal_text.label_settings.outline_color = Color(1, 1, 1, 0.16)
	steal_text.position = Vector2(-120, 110)
	main.add_child(steal_text)
	_band.add_child(main)

	for stripe in [[82, 8, Color.WHITE], [570, 8, Color.WHITE], [52, 12, Color("ffd36b")], [596, 20, s["stripe"]]]:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = stripe[2]
		HudUi.set_rect(bar, Vector2(0, stripe[0]), Vector2(3400, stripe[1]))
		_band.add_child(bar)
	return _band


func _make_character(s: Dictionary) -> Control:
	var rect: Rect2 = s["char_rect"]
	_character = Control.new()
	_character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudUi.set_rect(_character, rect.position, rect.size)

	# 팀 색 그림자 (일러스트 모양 그대로, 살짝 어긋나게)
	var shadow := _art_rect(s["art"], rect.size)
	shadow.position = s["char_shadow"]
	var mat := ShaderMaterial.new()
	mat.shader = SILHOUETTE
	mat.set_shader_parameter("tint", s["accent"])
	shadow.material = mat
	_character.add_child(shadow)
	_char_shadow = shadow
	_character.add_child(_art_rect(s["art"], rect.size))
	return _character


func _art_rect(tex: Texture2D, box: Vector2) -> TextureRect:
	var t := HudUi.texture_rect(tex, Vector2.ZERO, box)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


func _make_title(s: Dictionary, team_id: int) -> Control:
	# "FAN STEAL!" 리본 + "팬 쟁탈!" — 설명(팬클럽 카드, 누구→누구)은 넣지 않음
	var box_size := Vector2(760, 330)
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudUi.set_rect(_title, s["title_center"] - box_size / 2.0, box_size)
	_title.pivot_offset = box_size / 2.0
	_title.rotation_degrees = s["angle"]

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	var align := Control.SIZE_SHRINK_END if team_id == 2 else Control.SIZE_SHRINK_BEGIN

	var ribbon := HudUi.pill("FAN STEAL!", 34, s["ink"], Color.WHITE, Color(0, 0, 0, 0), 0,
		Vector2(22, 4), Color(s["shade"], 0.8))
	var box := ribbon.get_theme_stylebox("panel") as StyleBoxFlat
	box.shadow_offset = Vector2(0, 4)
	ribbon.size_flags_horizontal = align
	column.add_child(ribbon)

	var headline := HudUi.label("팬 쟁탈!", 200, Color.WHITE, s["accent"], Vector2(10, 10))
	headline.size_flags_horizontal = align
	column.add_child(headline)
	_title.add_child(column)
	return _title


func _v_gradient(stops: Array) -> GradientTexture2D:
	var tex := HudUi.h_gradient(stops)
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	tex.width = 4
	tex.height = 256
	return tex


# --- 애니메이션 ------------------------------------------------------------------

func _animate(team_id: int) -> void:
	var dir := 1.0 if team_id == 1 else -1.0 # URI는 왼쪽에서, HANA는 오른쪽에서
	var char_pos := _character.position
	var title_pos := _title.position

	# 1 Flash: 화면이 하얗게 번쩍, 띠는 가는 선
	_flash.modulate.a = 0.92
	_dim.modulate.a = 0.0
	_band.scale = Vector2(1, 0.02)
	_burst.scale = Vector2(0.6, 0.6)
	_burst.modulate.a = 0.0
	_character.position = char_pos - Vector2(760 * dir, 0)
	_title.position = title_pos + Vector2(760 * dir, 0)
	_watermark.modulate.a = 0.0
	for star in _sparkles:
		star.scale = Vector2.ZERO

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var t := _tween
	t.tween_property(_dim, "modulate:a", 1.0, T_SLIDE)
	t.tween_property(_flash, "modulate:a", 0.0, T_HOLD - T_SLIDE).set_delay(T_SLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 2 Slide-in
	t.tween_property(_band, "scale:y", 1.0, T_HOLD - T_SLIDE).set_delay(T_SLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_burst, "scale", Vector2.ONE, 0.35).set_delay(T_SLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_burst, "modulate:a", 1.0, 0.2).set_delay(T_SLIDE)
	t.tween_property(_character, "position", char_pos, T_HOLD - T_SLIDE).set_delay(T_SLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_title, "position", title_pos, T_HOLD - T_SLIDE).set_delay(T_SLIDE + 0.04) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_watermark, "modulate:a", 1.0, 0.25).set_delay(T_SLIDE)
	for i in range(_sparkles.size()):
		var star := _sparkles[i]
		var at := T_SLIDE + 0.03 * i
		t.tween_property(star, "scale", Vector2.ONE * 1.25, 0.14).set_delay(at) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(star, "scale", Vector2.ONE * 0.8, 0.5).set_delay(at + 0.14) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(star, "rotation", deg_to_rad(90.0 * dir), T_END - at).set_delay(at)

	# 3 Hold: 스피드 라인이 흐르고 캐릭터·제목이 살짝 밀림
	t.tween_property(_lines, "position:x", 900.0 * dir * -1.0, T_END).set_trans(Tween.TRANS_LINEAR)
	t.tween_property(_character, "position", char_pos + Vector2(18 * dir, 0), T_OUT - T_HOLD) \
		.set_delay(T_HOLD)
	t.tween_property(_title, "position", title_pos - Vector2(12 * dir, 0), T_OUT - T_HOLD - 0.04) \
		.set_delay(T_HOLD + 0.04)

	# 4 Out: 띠가 접히며 전체가 사라짐
	var out_time := T_END - T_OUT
	# 반투명해질 때 팀 색 그림자가 몸 너머로 비쳐 겹쳐 보이지 않게 먼저 빠르게 지움
	t.tween_property(_char_shadow, "modulate:a", 0.0, 0.08).set_delay(T_OUT)
	t.tween_property(self, "modulate:a", 0.0, out_time).set_delay(T_OUT) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_band, "scale:y", 0.0, out_time).set_delay(T_OUT) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_character, "position", char_pos + Vector2(140 * dir, 0), out_time) \
		.set_delay(T_OUT).set_ease(Tween.EASE_IN)
	t.tween_property(_title, "position", title_pos - Vector2(140 * dir, 0), out_time) \
		.set_delay(T_OUT).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(_finish)
