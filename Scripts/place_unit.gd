extends Button

@export var unit_scene: PackedScene

signal unit_selected(scene: PackedScene)

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if unit_scene:
		unit_selected.emit(unit_scene)
	else:
		push_warning("No unit_scene assigned.")
