extends Passive

@export var shield_cooldown: float = 5.0
@export var shield_amount: int = 50

var shield_active: bool = true
var cooldown_timer: float = 0.0

func _ready():
	unit.damaged.connect(_on_damaged)

func _process(delta: float) -> void:
	if not shield_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			shield_active = true
			print("[", unit.name, "] Shield recharged!")

func _on_damaged(amount: int, attacker):
	if not shield_active:
		return

	# Block up to shield_amount of the REAL damage
	var blocked = min(shield_amount, amount)

	unit.health += blocked

	shield_active = false
	cooldown_timer = shield_cooldown

	print("[", unit.name, "] Shield blocked ", blocked, " damage!")
