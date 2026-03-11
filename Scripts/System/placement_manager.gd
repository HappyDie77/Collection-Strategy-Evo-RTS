extends Node3D

func _ready():
	for button in $UI/UnitButtons.get_children():
		if button.has_signal("unit_selected"):
			button.unit_selected.connect(_on_unit_selected)

var selected_unit_scene: PackedScene = null

func _on_unit_selected(scene: PackedScene) -> void:
	selected_unit_scene = scene
