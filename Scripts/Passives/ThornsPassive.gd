extends Passive

func _ready():
	unit.damaged.connect(_on_damaged)

func _on_damaged(attacker):
	if attacker:
		# Pass is_reflect = true to prevent infinite recursion
		attacker.take_damage(unit.damage/5, unit, true)
