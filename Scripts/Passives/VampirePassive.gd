# VampirePassive.gd
extends Passive
# Heals the unit for a percentage of damage dealt

@export var lifesteal_percent: float = 0.25  # 25% lifesteal

func _ready():
	unit.damaged.connect(_on_unit_attacked)

func _on_unit_attacked(attacker):
	# When this unit deals damage, heal it
	if attacker == unit:
		return
	
	# Calculate heal amount based on damage dealt
	var heal_amount = unit.damage * lifesteal_percent
	unit.health = min(unit.health + heal_amount, unit.data.max_health)
	print("[", unit.name, "] Vampirism healed ", heal_amount, " HP")
