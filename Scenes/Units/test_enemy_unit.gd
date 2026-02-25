extends CharacterBody3D

@export var data: UnitData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var passive_container = $Passives

@onready var attack_shape: CollisionShape3D = $AttackRange/AttackShape
@onready var defend_shape: CollisionShape3D = $DefendRange/DefendShape
@onready var ranged_shape: CollisionShape3D = $RangedRange/RangedShape

var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween

var health: int
var speed: float
var damage: int
var attack_cooldown: float
var attack_count: int
var attack_timer: float = 0.0

var attack_range: float
var defend_range: float
var ranged_range: float

# Unit Mode & Class
var mode: String
var unit_class: String

var current_target: Node = null
var detected_enemies: Array = []
var enemies_in_attack_range: Array = []
signal damaged(attacker)

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
		
		load_passives()
		
		attack_count = data.attack_count
	
	# Resize areas to match unit data
	ranged_shape.shape.radius = ranged_range
	defend_shape.shape.radius = defend_range
	attack_shape.shape.radius = attack_range

func _physics_process(delta):
	update_detection()
	
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
	
	attack_timer -= delta
	
	if mode == "Attack":
		handle_attack_mode()
	elif mode == "Defend":
		handle_defend_mode()

func update_detection():
	# Rebuild detected enemies list every frame
	detected_enemies.clear()
	enemies_in_attack_range.clear()

	# Ranged detection
	for body in $RangedRange.get_overlapping_bodies():
		if body.is_in_group("FriendlyUnits"):
			detected_enemies.append(body)
			
	# Melee attack range
	for body in $AttackRange.get_overlapping_bodies():
		if body.is_in_group("FriendlyUnits"):
			enemies_in_attack_range.append(body)

func take_damage(amount: int, attacker: Node = null, is_reflect: bool = false):
	if health <= 0:
		return  # Already dead, prevent further damage
	
	health -= amount
	
	if not is_reflect:
		emit_signal("damaged", attacker)  # Only emit signal if not a reflected damage
	
	if health <= 0:
		die()

func die():
	queue_free()

func attack(target: Node):
	if attack_timer > 0 or not is_instance_valid(target):
		return

	if target == null:
		return

	# Reset cooldown
	attack_timer = attack_cooldown

	# Debug
	print("Attacking ", target.name, " for ", damage, " damage")

	target.take_damage(damage, self)

func handle_attack_mode():
	if unit_class == "Ranged":
		if detected_enemies.size() > 0:
			var target = detected_enemies[0]
			print("Ranged attacking ", target.name)
			attack(target)
	else:
		if enemies_in_attack_range.size() > 0:
			var target = enemies_in_attack_range[0]
			print("Melee attacking ", target.name)
			attack(target)
		elif detected_enemies.size() > 0:
			var target = detected_enemies[0]
			move_to(target.global_position)

func handle_defend_mode():
	if unit_class == "Ranged":
		if detected_enemies.size() > 0:
			var target = detected_enemies[0]
			print("Ranged defending and attacking ", target.name)
			attack(target)
	else:
		var charge_enemies = $DefendRange.get_overlapping_bodies()
		if charge_enemies.size() > 0:
			move_to(charge_enemies[0].global_position)
		if enemies_in_attack_range.size() > 0:
			attack(enemies_in_attack_range[0])

func load_passives():
	for passive_scene in data.passives:
		var p = passive_scene.instantiate()
		p.unit = self
		passive_container.add_child(p)

func move_to(target_pos: Vector3) -> void:
	if nav_agent:
		nav_agent.target_position = target_pos

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

func _on_ranged_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("FriendlyUnits"):
		detected_enemies.append(body)

func _on_ranged_range_body_exited(body: Node3D) -> void:
	if body in detected_enemies:
		detected_enemies.erase(body)

func _on_attack_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("FriendlyUnits"):
		enemies_in_attack_range.append(body)

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body in enemies_in_attack_range:
		enemies_in_attack_range.erase(body)
