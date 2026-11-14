class_name FanClubData
extends Resource
## Shared configuration only. HP, targets and cooldowns belong to each Fan.

@export_group("Identity")
@export var club_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var movement_label: String
@export var attack_label: String

@export_group("Stats")
@export_range(1, 100) var max_hp: int = 3
@export var move_speed: float = 68.0
@export_range(1, 16) var population_cost: int = 1
@export_range(0.05, 30.0) var attack_interval: float = 1.0

@export_group("Behaviors")
@export var movement_scene: PackedScene
@export var attack_scene: PackedScene
@export var projectile_scene: PackedScene
@export var ability_scenes: Array[PackedScene] = []

@export_group("Prototype Appearance")
@export var accent: Color = Color("7ce8c0")
@export_range(0.0, 1.0) var eye_slant: float = 0.0
@export_range(3, 6) var crest_points: int = 3
