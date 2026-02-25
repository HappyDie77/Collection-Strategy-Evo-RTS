# HalfHealthBuff50.gd
extends Passive

var buff_active: bool = false

func _process(_delta: float) -> void:
	if not unit:
		return
	
	var health_percent = float(unit.health) / float(unit.data.max_health)
	
	# Check if below 50% HP
	if health_percent <= 0.5 and not buff_active:
		# Apply 20% damage buff
		var buff_amount = unit.data.damage * 0.2
		unit.damage += buff_amount
		buff_active = true
		print("[", unit.name, "] HalfHealthBuff activated! +", buff_amount, " damage")
	
	# Remove buff when above 50% HP
	elif health_percent > 0.5 and buff_active:
		var buff_amount = unit.data.damage * 0.2
		unit.damage -= buff_amount
		buff_active = false
		print("[", unit.name, "] HalfHealthBuff deactivated! -", buff_amount, " damage")
