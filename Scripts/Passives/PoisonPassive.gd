# PoisonPassive.gd
extends Passive
# Attacks apply a poison that deals damage over time

@export var poison_damage_per_second: int = 5
@export var poison_duration: float = 3.0

# Track poisoned enemies and their remaining duration
var poisoned_enemies: Dictionary = {}  # {enemy: time_remaining}

func _process(delta: float) -> void:
	if not unit:
		return
	
	# Check if unit just attacked
	if unit.attack_timer > 0 and unit.attack_timer < unit.attack_cooldown - delta:
		# Apply poison to current target
		if unit.enemies_in_attack_range.size() > 0:
			var target = unit.enemies_in_attack_range[0]
			if is_instance_valid(target):
				poisoned_enemies[target] = poison_duration
				print("[", unit.name, "] Applied poison to ", target.name)
	
	# Tick poison damage
	var enemies_to_remove = []
	for enemy in poisoned_enemies.keys():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			enemies_to_remove.append(enemy)
			continue
		
		poisoned_enemies[enemy] -= delta
		
		# Deal poison damage every second
		enemy.take_damage(int(poison_damage_per_second * delta), unit, true)
		
		# Remove expired poisons
		if poisoned_enemies[enemy] <= 0:
			enemies_to_remove.append(enemy)
			print("[", enemy.name, "] Poison expired")
	
	# Clean up
	for enemy in enemies_to_remove:
		poisoned_enemies.erase(enemy)
