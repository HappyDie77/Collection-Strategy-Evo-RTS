# ExecutionerPassive.gd
extends Passive
# Deals extra damage to enemies below 30% HP

@export var execute_threshold: float = 0.3  # 30% HP
@export var bonus_damage_percent: float = 0.5  # 50% extra damage

var original_damage: int = 0

func _ready():
	original_damage = unit.data.damage

func _process(_delta: float) -> void:
	if not unit:
		return
	
	# Check if we're attacking a low HP enemy
	var target = null
	if unit.enemies_in_attack_range.size() > 0:
		target = unit.enemies_in_attack_range[0]
	
	if target and is_instance_valid(target):
		var target_health_percent = float(target.health) / float(target.data.max_health)
		
		if target_health_percent <= execute_threshold:
			# Apply execute damage
			unit.damage = int(original_damage * (1.0 + bonus_damage_percent))
		else:
			unit.damage = original_damage
	else:
		unit.damage = original_damage
