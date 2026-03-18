extends Passive

var buff_active: bool = false
@export var damage_percent: float = 0.2  # 20%

func _process(_delta: float) -> void:
	if not unit:
		return
	
	var health_percent = float(unit.health) / float(unit.max_health)

	# Only toggle state (NO stat changes here)
	if health_percent <= 0.5:
		if not buff_active:
			buff_active = true
			print("[", unit.name, "] HalfHealthBuff activated!")
	else:
		if buff_active:
			buff_active = false
			print("[", unit.name, "] HalfHealthBuff deactivated!")

func apply_bonus(unit):
	if buff_active:
		var buff_amount = unit.base_damage * damage_percent
		unit.damage_bonus += int(buff_amount)
