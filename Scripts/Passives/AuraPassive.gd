# AuraPassive.gd
extends Passive
# Provides a damage buff to nearby allied units

@export var aura_radius: float = 5.0
@export var damage_buff: int = 5

var buffed_units: Array = []

func _process(_delta: float) -> void:
	if not unit:
		return
	
	# Find all units in the game
	var all_units = get_tree().get_nodes_in_group(unit.team)
	
	# Clear old buffs
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit) and buffed_unit != unit:
			buffed_unit.damage -= damage_buff
	buffed_units.clear()
	
	# Apply buffs to nearby allies
	for ally in all_units:
		if ally == unit:
			continue
		if not is_instance_valid(ally):
			continue
			
		var distance = unit.global_position.distance_to(ally.global_position)
		if distance <= aura_radius:
			ally.damage += damage_buff
			buffed_units.append(ally)

func _exit_tree():
	# Remove all buffs when this passive is removed
	for buffed_unit in buffed_units:
		if is_instance_valid(buffed_unit):
			buffed_unit.damage -= damage_buff
