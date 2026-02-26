class_name UnitData
extends Resource

#Stats
@export var max_health: int = 100
@export var move_speed: float = 5.0
@export var damage: int = 10
var damage_bonus: int = 0

#Attack
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.0
@export var defend_range: float = 3.5
@export var ranged_range: float = 7.0
@export var attack_count: int = 1

#Modes: "Attack" or "Defend"
@export var default_mode: String = "Attack"

#Unit class: "Melee" or "Ranged"
@export var unit_class: String = "Melee"

#Passives
@export var passives: Array[PackedScene]
