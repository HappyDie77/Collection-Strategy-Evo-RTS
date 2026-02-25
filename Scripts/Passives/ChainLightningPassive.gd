# ChainLightningPassive.gd
extends Passive
# Attacks chain to nearby enemies dealing reduced damage

@export var chain_count: int = 2  # Number of additional targets
@export var chain_range: float = 4.0
@export var damage_reduction: float = 0.5  # Each chain deals 50% damage

var original_damage: int = 0

func _ready():
	original_damage = unit.data.damage

func _process(delta: float) -> void:
	if not unit:
		return
	
	# Check if unit just attacked
	if unit.attack_timer > 0 and unit.attack_timer < unit.attack_cooldown - delta:
		if unit.enemies_in_attack_range.size() > 0:
			var primary_target = unit.enemies_in_attack_range[0]
			if is_instance_valid(primary_target):
				_chain_lightning(primary_target, chain_count, original_damage * damage_reduction)

func _chain_lightning(from_target: Node, chains_remaining: int, chain_damage: float):
	if chains_remaining <= 0:
		return
	
	# Find all enemies on the opposite team
	var potential_targets = []
	var enemy_team = "Team1" if unit.team == "Team2" else "Team2"
	var all_enemies = get_tree().get_nodes_in_group(enemy_team)
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == from_target:
			continue
		if enemy.health <= 0:
			continue
		
		var distance = from_target.global_position.distance_to(enemy.global_position)
		if distance <= chain_range:
			potential_targets.append(enemy)
	
	# Attack closest valid target
	if potential_targets.size() > 0:
		var closest = potential_targets[0]
		var closest_dist = from_target.global_position.distance_to(closest.global_position)
		
		for target in potential_targets:
			var dist = from_target.global_position.distance_to(target.global_position)
			if dist < closest_dist:
				closest = target
				closest_dist = dist
		
		# Deal chain damage
		closest.take_damage(int(chain_damage), unit, true)
		print("[", unit.name, "] Chain lightning hit ", closest.name, " for ", int(chain_damage), " damage")
		
		# Continue chain with reduced damage
		_chain_lightning(closest, chains_remaining - 1, chain_damage * damage_reduction)
