extends Passive

@export var damage_per_stack: int = 2
@export var max_stacks: float = 8.0
@export var decay_time: float = 5.0
@export var decay_rate: float = 0.8

var current_stacks: float = 0.0
var time_since_last_attack: float = 0.0

func _ready():
	if unit:
		unit.attacked.connect(_on_attack)

func _on_attack(_target):
	if current_stacks < max_stacks:
		current_stacks += 1.0
		print("[", unit.name, "] Rage stack:", current_stacks)

	time_since_last_attack = 0.0

func _process(delta: float):
	if not unit:
		return

	time_since_last_attack += delta

	if time_since_last_attack >= decay_time and current_stacks > 0.0:
		var decay_amount = decay_rate * delta
		current_stacks = max(0.0, current_stacks - decay_amount)

func get_bonus() -> int:
	return int(current_stacks) * damage_per_stack
