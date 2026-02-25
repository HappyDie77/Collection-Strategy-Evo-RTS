extends Passive

@export var regen_per_second: float = 2.0

func _process(delta: float) -> void:
	if unit and unit.health < unit.data.max_health:
		unit.health = min(unit.health + regen_per_second * delta, unit.data.max_health)
		print(unit.health)
