extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween

func _ready() -> void:
	if mesh_instance == null:
		return

	# Try to get active material first (more reliable)
	var base_material: Material = mesh_instance.get_active_material(0)

	if base_material == null and mesh_instance.mesh:
		base_material = mesh_instance.mesh.surface_get_material(0)

	if base_material == null:
		push_warning("No material found on mesh.")
		return

	# Ensure it's StandardMaterial3D
	if base_material is StandardMaterial3D:
		highlight_material = base_material.duplicate()
	else:
		push_warning("Material is not StandardMaterial3D.")
		return

	mesh_instance.set_surface_override_material(0, highlight_material)
	original_color = highlight_material.albedo_color


func highlight(active: bool) -> void:
	if highlight_material == null:
		return

	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	var target_color := original_color
	if active:
		target_color = original_color * 1.4

	tween.tween_property(highlight_material, "albedo_color", target_color, 0.15)
