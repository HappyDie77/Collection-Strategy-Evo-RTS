extends Passive

@export var guaranteed_time: float = 20.0
@export var roll_interval: float = 10.0
@export var roll_chance: float = 0.1
@export var transform_duration: float = 30.0

var state := "NORMAL"

var cycle_timer := 0.0
var roll_timer := 0.0
var transform_timer := 0.0

var original_health: int
var damage_transform: int = 8
var current_stacks: int = 0

func _ready():
	if unit:
		original_health = unit.max_health
		
		# Duplicate mesh so we don't modify shared resource
		if unit.mesh_instance and unit.mesh_instance.mesh:
			unit.mesh_instance.mesh = unit.mesh_instance.mesh.duplicate()

func _process(delta):
	if not unit:
		return

	match state:

		"NORMAL":
			cycle_timer += delta
			roll_timer += delta

			# Roll every 10 seconds
			if roll_timer >= roll_interval:
				roll_timer = 0.0
				if randf() <= roll_chance:
					_start_transform()
					return

			# Guaranteed transform
			if cycle_timer >= guaranteed_time:
				_start_transform()

		"TRANSFORMED":
			transform_timer += delta
			if transform_timer >= transform_duration:
				_end_transform()

func _start_transform():
	state = "TRANSFORMED"
	transform_timer = 0.0
	cycle_timer = 0.0
	roll_timer = 0.0

	var mesh = unit.mesh_instance.mesh
	if mesh is CapsuleMesh:
		mesh.height = 4
		mesh.radius = 1

	current_stacks += 1
	unit.max_health = 200
	unit.health = unit.max_health

	print("Transformed")

func _end_transform():
	state = "NORMAL"

	var mesh = unit.mesh_instance.mesh
	if mesh is CapsuleMesh:
		mesh.height = 2
		mesh.radius = 0.5

	current_stacks -= 1
	unit.max_health = original_health
	unit.health = min(unit.health, unit.max_health)

	print("Reverted")

func get_bonus() -> int:
	return int(current_stacks) * damage_transform
