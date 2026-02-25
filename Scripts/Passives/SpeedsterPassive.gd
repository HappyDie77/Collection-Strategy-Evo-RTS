# SpeedsterPassive.gd
extends Passive
# Increases movement speed when not in combat

@export var out_of_combat_speed_bonus: float = 1.5  # 50% speed bonus
@export var combat_timeout: float = 3.0  # Seconds without taking/dealing damage to leave combat

var original_speed: float = 0.0
var time_since_last_combat: float = 0.0
var in_combat: bool = false

func _ready():
	original_speed = unit.data.move_speed
	unit.damaged.connect(_on_combat_event)

func _process(delta: float) -> void:
	if not unit:
		return
	
	# Check if we're attacking
	if unit.enemies_in_attack_range.size() > 0:
		_on_combat_event(null)
	
	time_since_last_combat += delta
	
	# Enter out-of-combat state
	if time_since_last_combat >= combat_timeout and in_combat:
		in_combat = false
		unit.speed = original_speed * out_of_combat_speed_bonus
		print("[", unit.name, "] Out of combat - speed boost active!")
	
	# In combat state
	elif time_since_last_combat < combat_timeout and not in_combat:
		in_combat = true
		unit.speed = original_speed

func _on_combat_event(_attacker):
	time_since_last_combat = 0.0
