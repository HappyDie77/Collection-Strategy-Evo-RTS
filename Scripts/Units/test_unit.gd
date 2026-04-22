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

const GRAVITY = 9.8

# Stats
var max_health: int

# Base stats (from UnitData)
var base_damage: int
var base_speed: float
var base_armor: int
var base_physical_defence: int
var base_magical_defence: int

# Runtime
var health: int

# Bonuses (from passives)
var damage_bonus: int = 0
var speed_bonus: float = 0
var armor_bonus: int = 0

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

# Targets - optimized with cached targets
var detected_enemies: Array = []
var enemies_in_attack_range: Array = []
var enemies_in_defend_range: Array = []
var current_target: Node = null  # Cache current target
var target_recalc_timer: float = 0.0
var target_recalc_interval: float = 0.2  # Recalculate target every 0.2s instead of every frame

# Manual move override
var manual_override: bool = false

# Material highlight
var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween

# Other
var spawn_invulnerable_time := 0.5
var spawn_timer := 0.0
var bonus_timer: float = 0.0
var bonus_interval: float = 0.25

# Performance optimization flags
var cleanup_timer: float = 0.0
var cleanup_interval: float = 0.5  # Clean up dead enemies every 0.5s instead of every frame
var enemy_team: String = ""  # Cache enemy team name

signal damaged(attacker)
signal attacked(target)

func _ready():
	# Add to team group
	add_to_group(team)
	
	# Cache enemy team
	enemy_team = "Team2" if team == "Team1" else "Team1"
	
	spawn_timer = spawn_invulnerable_time
	
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
		max_health = data.max_health
		health = max_health
		base_damage = data.damage
		base_speed = data.move_speed
		base_armor = data.armor
		base_physical_defence = data.physical_defence
		base_magical_defence = data.magical_defence
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
		# Optimize navigation agent settings
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance = 3.0
		call_deferred("_setup_navigation")

func get_damage() -> int:
	return base_damage + damage_bonus

func get_speed() -> float:
	return base_speed + speed_bonus

func get_armor() -> int:
	return base_armor + armor_bonus

func get_physical_defence() -> int:
	return base_physical_defence

func get_magical_defence() -> int:
	return base_magical_defence


func _setup_navigation():
	await get_tree().physics_frame
	if nav_agent:
		nav_agent.set_velocity(Vector3.ZERO)

func is_enemy(body: Node) -> bool:
	if body == self:
		return false
	# Optimized: Use cached enemy_team instead of checking both conditions
	if body is Unit:
		return body.team == enemy_team
	# Check groups for backwards compatibility
	return body.is_in_group(enemy_team)

func _on_ranged_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in detected_enemies:
		detected_enemies.append(body)

func _on_ranged_range_body_exited(body: Node3D):
	detected_enemies.erase(body)

func _on_attack_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in enemies_in_attack_range:
		enemies_in_attack_range.append(body)

func _on_attack_range_body_exited(body: Node3D):
	enemies_in_attack_range.erase(body)

func _on_defend_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in enemies_in_defend_range:
		enemies_in_defend_range.append(body)

func _on_defend_range_body_exited(body: Node3D):
	enemies_in_defend_range.erase(body)

func update_bonuses():
	damage_bonus = 0
	speed_bonus = 0
	armor_bonus = 0

	for passive in passive_container.get_children():
		if passive.has_method("apply_bonus"):
			passive.apply_bonus(self)

func _physics_process(delta):
	attack_timer -= delta
	cleanup_timer += delta
	target_recalc_timer += delta
	
	if spawn_timer > 0:
		spawn_timer -= delta

	# OPTIMIZATION: Only clean up dead enemies periodically, not every frame
	if cleanup_timer >= cleanup_interval:
		cleanup_timer = 0.0
		_cleanup_dead_enemies()
	
	bonus_timer += delta
	if bonus_timer >= bonus_interval:
		bonus_timer = 0.0
		update_bonuses()

	# Reset manual override if finished moving
	if manual_override and nav_agent:
		if nav_agent.is_navigation_finished():
			manual_override = false
			current_target = null

	# Manual movement takes priority
	if manual_override:
		if nav_agent and not nav_agent.is_navigation_finished():
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity.x = direction.x * (base_speed + speed_bonus)
			velocity.z = direction.z * (base_speed + speed_bonus)
			# Let nav mesh Y guide climbing, but still apply gravity when falling
			if is_on_floor():
				velocity.y = direction.y * (base_speed + speed_bonus)
			else:
				velocity.y -= GRAVITY * delta
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	# OPTIMIZATION: Only recalculate navigation if we're not already moving
	# or if target became invalid
	var should_recalculate = false
	if current_target and not is_instance_valid(current_target):
		current_target = null
		should_recalculate = true
	elif target_recalc_timer >= target_recalc_interval:
		target_recalc_timer = 0.0
		should_recalculate = true

	# AI movement
# In _physics_process, replace the AI movement block:
	if nav_agent and not nav_agent.is_navigation_finished():
		# Don't push forward if we already have enemies in attack range
		if enemies_in_attack_range.size() > 0 and not manual_override:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var next_pos = nav_agent.get_next_path_position()
			var direction = (next_pos - global_position).normalized()
			velocity.x = direction.x * (base_speed + speed_bonus)
			velocity.z = direction.z * (base_speed + speed_bonus)
			if is_on_floor():
				velocity.y = direction.y * (base_speed + speed_bonus)
			else:
				velocity.y -= GRAVITY * delta
		move_and_slide()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()

	# Handle attack / defend based on mode
	# OPTIMIZATION: Only recalculate targets periodically
	if should_recalculate:
		if mode == "Attack":
			handle_attack_mode()
		elif mode == "Defend":
			handle_defend_mode()
	else:
		# Still attack if we have a valid target in range
		_fast_attack_check()

# OPTIMIZATION: Separate cleanup function called less frequently
func _cleanup_dead_enemies():
	# Use array filtering but less frequently
	var i = detected_enemies.size() - 1
	while i >= 0:
		var e = detected_enemies[i]
		if not is_instance_valid(e) or e.health <= 0:
			detected_enemies.remove_at(i)
		i -= 1
	
	i = enemies_in_attack_range.size() - 1
	while i >= 0:
		var e = enemies_in_attack_range[i]
		if not is_instance_valid(e) or e.health <= 0:
			enemies_in_attack_range.remove_at(i)
		i -= 1
	
	i = enemies_in_defend_range.size() - 1
	while i >= 0:
		var e = enemies_in_defend_range[i]
		if not is_instance_valid(e) or e.health <= 0:
			enemies_in_defend_range.remove_at(i)
		i -= 1

# OPTIMIZATION: Fast attack check without target recalculation
func _fast_attack_check():
	if enemies_in_attack_range.size() > 0:
		# Attack first valid enemy without recalculating closest
		for enemy in enemies_in_attack_range:
			if is_instance_valid(enemy) and enemy.health > 0:
				attack_multiple()
				return

func attack_multiple():
	if attack_timer > 0:
		return

	# ✅ Choose correct range based on class
	var source_array = []
	if unit_class == "Ranged":
		source_array = detected_enemies
	else:
		source_array = enemies_in_attack_range
	if source_array.is_empty():
		return

	attack_timer = attack_cooldown

	var damage = get_damage()
	var hit_count = 0
	var targets = source_array.duplicate()
	targets.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		if enemy.health <= 0:
			continue

		enemy.take_damage(damage, self)
		emit_signal("attacked", enemy)
		hit_count += 1
		if hit_count >= attack_count:
			break

func stop_moving():
	if nav_agent:
		nav_agent.target_position = global_position
		nav_agent.set_velocity(Vector3.ZERO)
	velocity.x = 0.0
	velocity.z = 0.0
	manual_override = false

func handle_attack_mode():
	# Ranged units attack from ranged distance
	if unit_class == "Ranged" and detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			current_target = target
			attack_multiple()
		return

	# Melee units: attack if in range, otherwise move towards detected enemies
	if enemies_in_attack_range.size() > 0:
		var target = get_closest_enemy(enemies_in_attack_range)
		stop_moving()
		if target:
			current_target = target
			attack_multiple()
	elif detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			current_target = target
			move_to(target.global_position)

func handle_defend_mode():
	# Ranged units still attack from range in defend mode
	if unit_class == "Ranged" and detected_enemies.size() > 0:
		var target = get_closest_enemy(detected_enemies)
		if target:
			current_target = target
			attack_multiple()
		return

	# Attack if in attack range
	if enemies_in_attack_range.size() > 0:
		var target = get_closest_enemy(enemies_in_attack_range)
		stop_moving()
		if target:
			current_target = target
			attack_multiple()
	# Melee units: only charge if enemy enters defend range
	elif enemies_in_defend_range.size() > 0:
		var target = get_closest_enemy(enemies_in_defend_range)
		if target:
			current_target = target
			move_to(target.global_position)

# OPTIMIZATION: Use distance_squared_to to avoid sqrt calculations
func get_closest_enemy(from_array: Array) -> Node:
	if from_array.is_empty():
		return null
	
	var closest = null
	var closest_dist_sq = INF  # Use squared distance
	var my_pos = global_position  # Cache position
	
	for enemy in from_array:
		if not is_instance_valid(enemy):
			continue
		if enemy.health <= 0:
			continue
		var dist_sq = my_pos.distance_squared_to(enemy.global_position)
		if dist_sq < closest_dist_sq:
			closest = enemy
			closest_dist_sq = dist_sq
	
	return closest

func take_damage(amount: int, attacker: Node = null, is_reflect: bool = false):
	if spawn_timer > 0:
		return
	if health <= 0:
		return

	var armor = get_armor()

	# Exponential damage reduction (always takes damage)
	var damage_multiplier = 100.0 / (100.0 + armor)
	var reduced = int(amount * damage_multiplier)

	reduced = max(reduced, 1)

	health -= reduced

	if not is_reflect:
		emit_signal("damaged", reduced, attacker)

	if health <= 0:
		die()

func die():
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
