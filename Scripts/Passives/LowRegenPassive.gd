extends Passive

var regen_per_tick: int

@onready var timer: Timer = $Timer

func _ready():
	if unit:
		regen_per_tick = unit.data.max_health / 40 #Heals 2.5% each sec

	timer.timeout.connect(_on_tick)

func _on_tick():
	if unit and unit.health < unit.data.max_health:
		unit.health = min(
			unit.health + regen_per_tick,
			unit.data.max_health
		)

		print("Regen tick:", unit.health)
