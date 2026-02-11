extends CharacterBody3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween
var speed: float = 5.0

func _ready() -> void:
	if mesh_instance == null:
		return

	# Get material safely
	var base_material: Material = mesh_instance.get_active_material(0)
	if base_material == null and mesh_instance.mesh:
		base_material = mesh_instance.mesh.surface_get_material(0)

	if base_material == null:
		push_warning("No material found on mesh.")
		return

	if base_material is StandardMaterial3D:
		highlight_material = base_material.duplicate()
	else:
		push_warning("Material is not StandardMaterial3D.")
		return

	mesh_instance.set_surface_override_material(0, highlight_material)
	original_color = highlight_material.albedo_color

func _physics_process(delta):
	if nav_agent == null:
		velocity = Vector3.ZERO
		return

	# Stop if path is finished
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return

	# Move toward next path position
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func move_to(target_pos: Vector3) -> void:
	if nav_agent:
		nav_agent.target_position = target_pos  # ✅ Correct way in Godot 4.5

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
