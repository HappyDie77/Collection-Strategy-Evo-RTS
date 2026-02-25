# BerserkPassive.gd
extends Passive
# Attack speed increases as health decreases

@export var max_attack_speed_bonus: float = 0.5  # Up to 50% faster at low HP

var original_cooldown: float = 0.0

func _ready():
	original_cooldown = unit.data.attack_cooldown

func _process(_delta: float) -> void:
	if not unit:
		return
	
	var health_percent = float(unit.health) / float(unit.data.max_health)
	
	# Attack speed increases as HP drops (inverted health percent)
	var speed_bonus = (1.0 - health_percent) * max_attack_speed_bonus
	
	# Lower cooldown = faster attacks
	unit.attack_cooldown = original_cooldown * (1.0 - speed_bonus)
