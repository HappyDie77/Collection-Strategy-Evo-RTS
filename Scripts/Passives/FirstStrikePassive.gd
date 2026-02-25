# FirstStrikePassive.gd
extends Passive
# First attack deals bonus damage, then goes on cooldown

@export var bonus_damage_multiplier: float = 2.0  # 200% damage on first hit
@export var cooldown_seconds: float = 10.0

var first_strike_ready: bool = true
var cooldown_timer: float = 0.0
var original_damage: int = 0
var attack_triggered: bool = false

func _ready():
	original_damage = unit.data.damage

func _process(delta: float) -> void:
	if not unit:
		return
	
	# Cooldown timer
	if not first_strike_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			first_strike_ready = true
			print("[", unit.name, "] First Strike ready!")
	
	# Check if unit is about to attack
	if first_strike_ready and unit.attack_timer <= 0 and unit.enemies_in_attack_range.size() > 0:
		if not attack_triggered:
			# Boost damage for the next attack
			unit.damage = int(original_damage * bonus_damage_multiplier)
			attack_triggered = true
			print("[", unit.name, "] First Strike activated! ", unit.damage, " damage")
	
	# Reset damage after attack
	if attack_triggered and unit.attack_timer > 0:
		unit.damage = original_damage
		first_strike_ready = false
		cooldown_timer = cooldown_seconds
		attack_triggered = false
