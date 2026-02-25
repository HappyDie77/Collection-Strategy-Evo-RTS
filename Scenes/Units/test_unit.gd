extends CharacterBody3D
class_name Unit

@export var data: UnitData
@export var team: String = "Team1"  # "Team1" or "Team2"

# Nodes
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var passive_container = $Passives
@onready var attack_area: Area3D = $AttackRange
@onready var attack_shape: CollisionShape3D = $AttackRange/AttackShape
@onready var defend_area: Area3D = $DefendRange
@onready var defend_shape: CollisionShape3D = $DefendRange/DefendShape
@onready var ranged_area: Area3D = $RangedRange
@onready var ranged_shape: CollisionShape3D = $RangedRange/RangedShape

# Stats
var health: int
var speed: float
var damage: int
var attack_cooldown: float
var attack_timer: float = 0.0
var attack_count: int

# Ranges
var attack_range: float
var defend_range: float
var ranged_range: float

# Unit Mode & Class
var mode: String
var unit_class: String

# Targets
var detected_enemies: Array = []
var enemies_in_attack_range: Array = []
var enemies_in_defend_range: Array = []

# Manual move override
var manual_override: bool = false

# Material highlight
var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween

signal damaged(attacker)

func _ready():
	# Add to team group
	add_to_group(team)
	
	if mesh_instance == null:
		return

	# Material
	var base_material: Material = mesh_instance.get_active_material(0)
	if base_material == null and mesh_instance.mesh:
		base_material = mesh_instance.mesh.surface_get_material(0)

	if base_material is StandardMaterial3D:
		highlight_material = base_material.duplicate()
		mesh_instance.set_surface_override_material(0, highlight_material)
		original_color = highlight_material.albedo_color

	# Load stats from UnitData
	if data:
		health = data.max_health
		speed = data.move_speed
		damage = data.damage
		attack_range = data.attack_range
		defend_range = data.defend_range
		ranged_range = data.ranged_range
		attack_cooldown = data.attack_cooldown
		mode = data.default_mode
		unit_class = data.unit_class
		attack_count = data.attack_count

		load_passives()

	# Resize Areas based on unit class
	attack_shape.shape.radius = attack_range
	defend_shape.shape.radius = defend_range
	
	# Only ranged units use ranged detection
	if unit_class == "Ranged":
		ranged_shape.shape.radius = ranged_range
	else:
		# Melee units use defend range for detection
		ranged_shape.shape.radius = defend_range

	# Wait for navigation to be ready
	if nav_agent:
		call_deferred("_setup_navigation")

func _setup_navigation():
	await get_tree().physics_frame
	# Navigation is now ready

func is_enemy(body: Node) -> bool:
	if body == self:
		return false
	# Check if the body is a Unit and on a different team
	if body is Unit:
		return body.team != team
	# Check groups for backwards compatibility
	if team == "Team1" and body.is_in_group("Team2"):
		return true
	if team == "Team2" and body.is_in_group("Team1"):
		return true
	return false

func _on_ranged_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in detected_enemies:
		detected_enemies.append(body)

func _on_ranged_range_body_exited(body: Node3D):
	if body in detected_enemies:
		detected_enemies.erase(body)

func _on_attack_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in enemies_in_attack_range:
		enemies_in_attack_range.append(body)

func _on_attack_range_body_exited(body: Node3D):
	if body in enemies_in_attack_range:
		enemies_in_attack_range.erase(body)

func _on_defend_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in enemies_in_defend_range:
		enemies_in_defend_range.append(body)

func _on_defend_range_body_exited(body: Node3D):
	if body in enemies_in_defend_range:
		enemies_in_defend_range.erase(body)

func _physics_process(delta):
	attack_timer -= delta

	# Clean up dead/invalid enemies
	detected_enemies = detected_enemies.filter(func(e): return is_instance_valid(e) and e.health > 0)
	enemies_in_attack_range = enemies_in_attack_range.filter(func(e): return is_instance_valid(e) and e.health > 0)
	enemies_in_defend_range = enemies_in_defend_range.filter(func(e): return is_instance_valid(e) and e.health > 0)

	# Reset manual override if finished moving
	if manual_override and nav_agent and nav_agent.is_navigation_finished():
		manual_override = false

	# Manual movement takes priority
	if manual_override:
		if nav_agent and not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		return

	# AI movement
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO

	# Handle attack / defend based on mode
	if mode == "Attack":
		handle_attack_mode()
	elif mode == "Defend":
		handle_defend_mode()

func attack(target: Node):
	if attack_timer > 0 or not is_instance_valid(target):
		return
	if target == null or not target.has_method("take_damage"):
		return
	if target.health <= 0:
		return

	attack_timer = attack_cooldown
	print("[", name, "] (", team, ") Attacking ", target.name, " for ", damage, " damage")
	target.take_damage(damage, self)

func handle_attack_mode():
	# Ranged units attack from ranged distance
	if unit_class == "Ranged" and detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			attack(target)
		return

	# Melee units: attack if in range, otherwise move towards detected enemies
	if enemies_in_attack_range.size() > 0:
		var target = get_closest_enemy(enemies_in_attack_range)
		if target:
			attack(target)
	elif detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			move_to(target.global_position)

func handle_defend_mode():
	# Ranged units still attack from range in defend mode
	if unit_class == "Ranged" and detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			attack(target)
		return

	# Melee units: only charge if enemy enters defend range
	if enemies_in_defend_range.size() > 0:
		var target = get_closest_enemy(enemies_in_defend_range)
		if target:
			move_to(target.global_position)

	# Attack if in attack range
	if enemies_in_attack_range.size() > 0:
		var target = get_closest_enemy(enemies_in_attack_range)
		if target:
			attack(target)

func get_closest_enemy(from_array: Array) -> Node:
	if from_array.is_empty():
		return null
	
	var closest = null
	var closest_dist = INF
	
	for enemy in from_array:
		if not is_instance_valid(enemy):
			continue
		if enemy.health <= 0:
			continue
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	
	return closest

func take_damage(amount: int, attacker: Node = null, is_reflect: bool = false):
	if health <= 0:
		return
	health -= amount
	print("[", name, "] (", team, ") took ", amount, " damage. Health: ", health)

	if not is_reflect:
		emit_signal("damaged", attacker)

	if health <= 0:
		die()

func die():
	print("[", name, "] (", team, ") died")
	queue_free()

func move_to(target_pos: Vector3):
	if nav_agent:
		nav_agent.target_position = target_pos
		manual_override = true  # Set override when manually moved

func load_passives():
	if not data.passives:
		return
	for passive_scene in data.passives:
		var p = passive_scene.instantiate()
		p.unit = self
		passive_container.add_child(p)

func highlight(active: bool):
	if highlight_material == null:
		return
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var target_color = original_color
	if active:
		target_color = original_color * 1.4
	tween.tween_property(highlight_material, "albedo_color", target_color, 0.15)
