# ShieldPassive.gd
extends Passive
# Blocks all damage from one attack every X seconds

@export var shield_cooldown: float = 5.0
@export var shield_amount: int = 50  # Amount of damage blocked

var shield_active: bool = true
var cooldown_timer: float = 0.0

func _ready():
	unit.damaged.connect(_on_unit_damaged)

func _process(delta: float) -> void:
	if not shield_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			shield_active = true
			print("[", unit.name, "] Shield recharged!")

func _on_unit_damaged(attacker):
	if shield_active:
		# Heal back the damage that was just taken (up to shield amount)
		var damage_taken = min(shield_amount, unit.data.damage)  # Estimate
		unit.health = min(unit.health + damage_taken, unit.data.max_health)
		
		shield_active = false
		cooldown_timer = shield_cooldown
		print("[", unit.name, "] Shield blocked ", damage_taken, " damage!")
