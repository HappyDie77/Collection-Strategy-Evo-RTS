extends Node3D

@onready var hex_tap: MeshInstance3D = $"Hex Tap"
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var hex_data: Hexdata
var highlight_mat: StandardMaterial3D = null
var original_color: Color = Color(1,1,1,1)  # store the original albedo
var tween: Tween

func _ready():
	if mesh_instance_3d:
		var base_mat = mesh_instance_3d.get_surface_override_material(0)
		if not base_mat:
			base_mat = mesh_instance_3d.mesh.surface_get_material(0)
		if base_mat:
			highlight_mat = base_mat.duplicate()
			mesh_instance_3d.set_surface_override_material(0, highlight_mat)
			original_color = highlight_mat.albedo_color  # save the original color

func is_flat_hex() -> bool:
	return hex_data and hex_data.is_flat

func can_spawn_addon() -> bool:
	return is_flat_hex() and not hex_data.has_river

func setup(hexdata: Hexdata) -> void:
	self.hex_data = hexdata
	self.hex_data.is_flat = true

func highlight(active: bool) -> void:
	#print(hex_data.biome)
	#print(hex_data.has_river)
	#print(hex_data.is_flat)
	# Show/hide selector above hex
	if hex_tap:
		hex_tap.visible = active
		animation_player.play("Select")

	if not highlight_mat:
		return

	# Stop previous tween if running
	if tween and tween.is_running():
		tween.kill()

	# Create a new tween
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	var target_color: Color

	if active:
		target_color = Color(1.353, 1.353, 1.353, 1.0)  # highlight bright
	else:
		target_color = original_color  # restore saved original color

	# Animate albedo_color toward target
	tween.tween_property(highlight_mat, "albedo_color", target_color, 0.3)
