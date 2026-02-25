# LastStandPassive.gd
extends Passive
# Survives a lethal blow once, healing to X% HP instead of dying

@export var last_stand_heal_percent: float = 0.3  # Heal to 30% HP
@export var cooldown_seconds: float = 60.0  # Once per minute

var last_stand_available: bool = true
var cooldown_timer: float = 0.0

func _ready():
	unit.damaged.connect(_on_unit_damaged)

func _process(delta: float) -> void:
	if not last_stand_available:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			last_stand_available = true
			print("[", unit.name, "] Last Stand ready!")

func _on_unit_damaged(_attacker):
	# Check if this damage would kill the unit
	if unit.health <= 0 and last_stand_available:
		# Prevent death and heal
		var heal_amount = int(unit.data.max_health * last_stand_heal_percent)
		unit.health = heal_amount
		
		last_stand_available = false
		cooldown_timer = cooldown_seconds
		
		print("[", unit.name, "] LAST STAND ACTIVATED! Healed to ", heal_amount, " HP")
		
		# Visual feedback could go here (flash, particle effect, etc.)
