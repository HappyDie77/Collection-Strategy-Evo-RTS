# Camera.gd
extends Node3D

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var main_camera: Camera3D = $"SpringArm3D/Main Camera"

# Reference to the stats panel (set in editor or find in scene)
@export var stats_panel: NodePath
var stats_panel_node: Node = null

@export var zoom_speed: float = 1.0
@export var min_zoom: float = 2.5
@export var max_zoom: float = 20.0
@export var zoom_smoothness: float = 6.0
@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 2.0

var target_zoom: float
var last_highlighted: Node = null
var selected_unit_scene: PackedScene = null
var placement_mode: bool = false
var selected_unit: Node = null

func _ready() -> void:
	target_zoom = 6
	
	# Find stats panel
	if stats_panel:
		stats_panel_node = get_node(stats_panel)
	else:
		# Try to find it in the scene
		stats_panel_node = get_tree().root.find_child("StatsPanel", true, false)
	
	# Connect to unit buttons
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
		global_move.y = 0.0
		global_position += global_move * speed * delta

func _unhandled_input(event: InputEvent) -> void:
	
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = main_camera.project_ray_origin(mouse_pos)
	var to = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	query.collision_mask = 3  # Place anywhere (both layers)

	var result = space_state.intersect_ray(query)
	
	# Zoom
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_zoom = max(min_zoom, target_zoom - zoom_speed)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		target_zoom = min(max_zoom, target_zoom + zoom_speed)
	
	# Left click → select/place
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if placement_mode and result:
			var instance = selected_unit_scene.instantiate()
			get_tree().current_scene.add_child(instance)
			var spawn_pos = result["position"]
			spawn_pos.y += 1.0
			instance.global_position = spawn_pos
			placement_mode = false
			selected_unit_scene = null
			return
		
		if result:
			var collider = result["collider"]
			var unit_node = _get_unit_from_collider(collider)
			if unit_node:
				_select_unit(unit_node)
			else:
				_deselect_unit()
		else:
			_deselect_unit()
	
	# Right click → move selected unit
	elif event.button_index == MOUSE_BUTTON_RIGHT and result and selected_unit:
		# Check if the selected unit is controllable (not hostile)
		if selected_unit.team == "Team2":  # Assuming Team2 is hostile
			return
		var target_pos = result["position"]
		print("test")
		if selected_unit.has_method("move_to"):
			selected_unit.move_to(target_pos)

# Select and highlight a unit
func _select_unit(unit: Node) -> void:
	# Unhighlight previous unit
	if last_highlighted and last_highlighted.has_method("highlight"):
		last_highlighted.highlight(false)
	
	# Highlight new unit
	if unit.has_method("highlight"):
		unit.highlight(true)
	
	last_highlighted = unit
	selected_unit = unit
	
	# Update stats panel
	if stats_panel_node and stats_panel_node.has_method("set_unit"):
		stats_panel_node.set_unit(unit)

# Deselect current unit
func _deselect_unit() -> void:
	if selected_unit and selected_unit.has_method("highlight"):
		selected_unit.highlight(false)
	
	selected_unit = null
	last_highlighted = null
	
	# Clear stats panel
	if stats_panel_node and stats_panel_node.has_method("set_unit"):
		stats_panel_node.set_unit(null)

# Traverse up to find root unit with move_to() and highlight()
func _get_unit_from_collider(collider: Node) -> Node:
	var node = collider
	while node:
		if node.has_method("move_to") and node.has_method("highlight"):
			return node
		node = node.get_parent()
	return null
