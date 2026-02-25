# RagePassive.gd
extends Passive
# Gains stacking damage bonus with each attack, decays over time

@export var damage_per_stack: int = 2
@export var max_stacks: int = 10
@export var decay_time: float = 5.0  # Time before stacks start decaying
@export var decay_rate: float = 1.0  # Stacks lost per second

var current_stacks: int = 0
var time_since_last_attack: float = 0.0
var original_damage: int = 0

func _ready():
	original_damage = unit.data.damage

func _process(delta: float) -> void:
	if not unit:
		return
	
	# Check if unit just attacked
	if unit.attack_timer > 0 and unit.attack_timer < unit.attack_cooldown - delta:
		# Attack just happened
		if current_stacks < max_stacks:
			current_stacks += 1
			unit.damage = original_damage + (current_stacks * damage_per_stack)
			print("[", unit.name, "] Rage stack: ", current_stacks, "/", max_stacks)
		time_since_last_attack = 0.0
	
	# Decay stacks
	time_since_last_attack += delta
	if time_since_last_attack >= decay_time and current_stacks > 0:
		var decay_amount = decay_rate * delta
		var old_stacks = current_stacks
		current_stacks = max(0, current_stacks - int(decay_amount))
		
		if old_stacks != current_stacks:
			unit.damage = original_damage + (current_stacks * damage_per_stack)
			if current_stacks == 0:
				print("[", unit.name, "] Rage stacks depleted")
