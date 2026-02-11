extends Node3D

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var main_camera: Camera3D = $"SpringArm3D/Main Camera"
@onready var ray_cast_3d: RayCast3D = $"SpringArm3D/Main Camera/RayCast3D"
@onready var camera_light: OmniLight3D = $"SpringArm3D/Camera light"
@onready var camera_light_2: SpotLight3D = $"SpringArm3D/Camera light2"

@export var zoom_speed: float = 1.0
@export var min_zoom: float = 2.5
@export var max_zoom: float = 80.0
@export var zoom_smoothness: float = 6.0  # Higher = smoother
@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 2.0

var target_zoom: float
var last_selected: Node3D = null
var selected_unit_scene: PackedScene = null
var placement_mode: bool = false

func _ready() -> void:
	target_zoom = 6
	# Connect all unit buttons
	for button in get_tree().get_nodes_in_group("unit_buttons"):
		button.unit_selected.connect(_on_unit_selected)

func _on_unit_selected(scene: PackedScene) -> void:
	selected_unit_scene = scene
	placement_mode = true

func _physics_process(delta: float) -> void:
	spring_arm_3d.spring_length = lerp(spring_arm_3d.spring_length, target_zoom, delta * zoom_smoothness)
	
	var move_dir = Vector3.ZERO
	if Input.is_action_pressed("w"):
		move_dir.z -= 1
	if Input.is_action_pressed("a"):
		move_dir.x -= 1
	if Input.is_action_pressed("s"):
		move_dir.z += 1
	if Input.is_action_pressed("d"):
		move_dir.x += 1
	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		var speed = move_speed
		if Input.is_action_pressed("shift"):
			speed *= sprint_multiplier
		var global_move = (transform.basis * move_dir).normalized()
		global_move.y = 0.0  # flatten movement
		global_position += global_move * speed * delta


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Mouse wheel up (zoom in)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = max(min_zoom, target_zoom - zoom_speed)
		# Mouse wheel down (zoom out)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = min(max_zoom, target_zoom + zoom_speed)

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			movement()

func movement():
	if not main_camera:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var from = main_camera.project_ray_origin(mouse_pos)
	var to = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1  # Make sure your tiles/objects use this layer
	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		var target = collider
		while target and not target.has_method("highlight"):
			target = target.get_parent()

		if placement_mode and selected_unit_scene:
			var instance = selected_unit_scene.instantiate()
			get_tree().current_scene.add_child(instance)
			var spawn_pos = result.position
			spawn_pos.y += 0.8
			instance.global_position = spawn_pos
			# Optional: Exit placement mode after placing one
			placement_mode = false
			selected_unit_scene = null

		# Change highlight if we hit a new object
		if target:
			# Turn off old selector
			if last_selected and last_selected.has_method("highlight"):
				last_selected.highlight(false)

			# Turn on new one
			if target and target.has_method("highlight"):
				target.highlight(true)

			last_selected = target

		else:
			# If no hit, remove highlight from the previous one
			if last_selected and last_selected.has_method("highlight"):
				last_selected.highlight(false)
			last_selected = null
