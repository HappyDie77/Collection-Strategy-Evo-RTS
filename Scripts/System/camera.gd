# Camera.gd
extends Node3D

@onready var spring_arm_3d: SpringArm3D = $SpringArm3D
@onready var main_camera: Camera3D = $"SpringArm3D/Main Camera"

@export var stats_panel: NodePath
var stats_panel_node: Node = null

@export var zoom_speed: float = 1.0
@export var min_zoom: float = 2.5
@export var max_zoom: float = 20.0
@export var zoom_smoothness: float = 6.0
@export var move_speed: float = 5.0
@export var sprint_multiplier: float = 2.0

# ── Temp test spawning (remove when real spawn system is ready) ────────────────
# Assign these in the editor: one friendly unit scene, one enemy unit scene
@export var friendly_unit_scene: PackedScene   # hotkey: 1
@export var enemy_unit_scene: PackedScene      # hotkey: 2

var target_zoom: float
var last_highlighted: Node = null
var selected_unit_scene: PackedScene = null
var placement_mode: bool = false
var selected_unit: Node = null

func _ready() -> void:
	target_zoom = 6

	if stats_panel:
		stats_panel_node = get_node(stats_panel)
	else:
		stats_panel_node = get_tree().root.find_child("StatsPanel", true, false)

	for button in get_tree().get_nodes_in_group("unit_buttons"):
		button.unit_selected.connect(_on_unit_selected)

func _on_unit_selected(scene: PackedScene) -> void:
	selected_unit_scene = scene
	placement_mode = true

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT  (keyboard handled here; mouse handled in _unhandled_input)
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# ── Spawn / placement hotkeys ────────────────────────────────────────────
	if event.is_action_pressed("1"):
		if friendly_unit_scene:
			selected_unit_scene = friendly_unit_scene
			placement_mode = true

	elif event.is_action_pressed("2"):
		if enemy_unit_scene:
			selected_unit_scene = enemy_unit_scene
			placement_mode = true

	# ── Toggle mode on selected unit ─────────────────────────────────────────
	elif event.is_action_pressed("v"):
		if selected_unit and selected_unit.has_method("set_mode"):
			var new_mode = "Defend" if selected_unit.mode == "Attack" else "Attack"
			selected_unit.set_mode(new_mode)

			# Refresh HUD
			if stats_panel_node and stats_panel_node.has_method("set_unit"):
				stats_panel_node.set_unit(selected_unit)

# ─────────────────────────────────────────────────────────────────────────────
#  PHYSICS / CAMERA MOVEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	spring_arm_3d.spring_length = lerp(spring_arm_3d.spring_length, target_zoom, delta * zoom_smoothness)

	var move_dir = Vector3.ZERO
	if Input.is_action_pressed("w"): move_dir.z -= 1
	if Input.is_action_pressed("a"): move_dir.x -= 1
	if Input.is_action_pressed("s"): move_dir.z += 1
	if Input.is_action_pressed("d"): move_dir.x += 1

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		var speed = move_speed
		if Input.is_action_pressed("shift"):
			speed *= sprint_multiplier
		var global_move = (transform.basis * move_dir).normalized()
		global_move.y = 0.0
		global_position += global_move * speed * delta

# ─────────────────────────────────────────────────────────────────────────────
#  MOUSE INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var mouse_pos  = get_viewport().get_mouse_position()
	var from       = main_camera.project_ray_origin(mouse_pos)
	var to         = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query      = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	query.collision_mask      = 3
	var result = space_state.intersect_ray(query)

	# ── Zoom ─────────────────────────────────────────────────────────────────
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_zoom = max(min_zoom, target_zoom - zoom_speed)
		return
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		target_zoom = min(max_zoom, target_zoom + zoom_speed)
		return

	# ── Left click: place unit OR select ─────────────────────────────────────
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if placement_mode and result:
			var instance = selected_unit_scene.instantiate()
			get_tree().current_scene.add_child(instance)
			var spawn_pos   = result["position"]
			spawn_pos.y    += 1
			instance.global_position = spawn_pos
			placement_mode       = false
			selected_unit_scene  = null
			return

		if result:
			var collider  = result["collider"]
			var unit_node = _get_unit_from_collider(collider)
			if unit_node:
				_select_unit(unit_node)
			else:
				_deselect_unit()
		else:
			_deselect_unit()

	# ── Right click: move or attack-target ───────────────────────────────────
	elif event.button_index == MOUSE_BUTTON_RIGHT and selected_unit:
		if selected_unit.team == "Team2":
			return

		var collider    = result["collider"] if result else null
		var target_unit = _get_unit_from_collider(collider)

		# Clicked an enemy unit → force attack on that target
		if target_unit and target_unit.team != selected_unit.team:
			if selected_unit.has_method("set_attack_target"):
				selected_unit.set_attack_target(target_unit)
			return

		# Clicked ground → move
		if result:
			if selected_unit.has_method("move_to"):
				selected_unit.move_to(result["position"])

# ─────────────────────────────────────────────────────────────────────────────
#  SELECTION HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _select_unit(unit: Node) -> void:
	if last_highlighted and last_highlighted.has_method("highlight"):
		last_highlighted.highlight(false)

	if unit.has_method("highlight"):
		unit.highlight(true)

	last_highlighted = unit
	selected_unit    = unit

	if stats_panel_node and stats_panel_node.has_method("set_unit"):
		stats_panel_node.set_unit(unit)

func _deselect_unit() -> void:
	if selected_unit and selected_unit.has_method("highlight"):
		selected_unit.highlight(false)

	selected_unit    = null
	last_highlighted = null

	if stats_panel_node and stats_panel_node.has_method("set_unit"):
		stats_panel_node.set_unit(null)

func _get_unit_from_collider(collider: Node) -> Node:
	var node = collider
	while node:
		if node.has_method("move_to") and node.has_method("highlight"):
			return node
		node = node.get_parent()
	return null
