class_name FanClubData
extends Resource
## Shared configuration only. HP, targets and cooldowns belong to each Fan.

@export_group("Identity")
@export var club_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Visuals")
@export var sprite_texture: Texture2D
@export_range(0.0, 2.0, 0.05) var hit_flash_duration: float = 0.0

@export_group("Stats")
@export_range(1, 100) var max_hp: int = 3
@export_range(1.0, 100.0) var hitbox_radius: float = 40.0
@export var move_speed: float = 68.0
@export_range(1, 16) var population_cost: int = 1
@export_range(0.0, 60.0, 0.5) var respawn_delay: float = 0.0
@export_range(0.05, 30.0) var attack_interval: float = 1.0
@export_range(0.15, 3.0) var charge_duration: float = 0.5
@export_range(30.0, 1000.0) var projectile_speed: float = 230.0
@export_range(0.1, 30.0) var projectile_lifetime: float = 2.0

@export_group("Behaviors")
@export var movement_scene: PackedScene
@export var attack_scene: PackedScene
@export var projectile_scene: PackedScene
@export var ability_scenes: Array[PackedScene] = []
@export var requires_ally_player: bool = false
@export var intercepts_projectiles: bool = false
