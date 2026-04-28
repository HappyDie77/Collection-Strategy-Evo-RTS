extends CharacterBody3D
class_name Unit

@export var data: UnitData
@export var team: String = "Team1"  # "Team1" or "Team2"

# ─── Nodes ────────────────────────────────────────────────────────────────────
@onready var mesh_instance: MeshInstance3D  = $MeshInstance3D
@onready var nav_agent: NavigationAgent3D   = $NavigationAgent3D
@onready var passive_container              = $Passives
@onready var attack_area: Area3D            = $AttackRange
@onready var attack_shape: CollisionShape3D = $AttackRange/AttackShape
@onready var defend_area: Area3D            = $DefendRange
@onready var defend_shape: CollisionShape3D = $DefendRange/DefendShape
@onready var ranged_area: Area3D            = $RangedRange
@onready var ranged_shape: CollisionShape3D = $RangedRange/RangedShape

const GRAVITY = 9.8

# ─── State Machine ────────────────────────────────────────────────────────────
# IDLE      : no enemies nearby, standing still, AI evaluates each frame
# CHASING   : moving toward a detected enemy (AI-controlled)
# ATTACKING : enemy in attack range, unit stands still and fights
# MANUAL    : player-issued move command, AI fully suspended until arrival
#             → In Defend mode, MANUAL only repositions the defend_origin,
#               it does NOT physically move the unit while engaged.
enum CombatState { IDLE, CHASING, ATTACKING, MANUAL }
var combat_state: CombatState = CombatState.IDLE

# ─── Stats ────────────────────────────────────────────────────────────────────
var max_health: int
var base_damage: int
var base_speed: float
var base_armor: int
var base_physical_defence: int
var base_magical_defence: int
var health: int

var damage_bonus: int   = 0
var speed_bonus: float  = 0
var armor_bonus: int    = 0

var attack_cooldown: float
var attack_timer: float = 0.0
var attack_count: int

# ─── Ranges ───────────────────────────────────────────────────────────────────
# These three Area3D zones have fixed, permanent jobs regardless of mode/class:
#
#   AttackRange  (attack_shape)  — the actual swing/shoot radius; when an enemy
#                                  enters this the unit can deal damage.
#                                  Radius = attack_range (same for melee & ranged)
#
#   DefendRange  (defend_shape)  — the "alert" radius; enemies here trigger a
#                                  chase in Attack mode, or engage in Defend mode.
#                                  Radius = defend_range (larger than attack_range)
#
#   RangedRange  (ranged_shape)  — the outermost detection zone, only used by
#                                  Ranged units so they can start shooting before
#                                  the enemy closes to melee distance.
#                                  Radius = ranged_range (largest of the three)
#                                  Melee units: radius = 0 (disabled)
#
# The LOGIC (state machine) decides which array to act on based on mode & class.
var attack_range: float
var defend_range: float
var ranged_range: float
var proximity_dist_sq: float = 0.0  # (attack_range + 0.6)^2, set in _ready

# ─── Unit Identity ────────────────────────────────────────────────────────────
var mode: String        # "Attack" or "Defend" — changeable mid-game via set_mode()
var unit_class: String  # "Melee"  or "Ranged" — fixed at spawn
var enemy_team: String  # cached

# ─── Enemy Tracking ───────────────────────────────────────────────────────────
# enemies_in_attack_range : entered AttackRange  — unit CAN deal damage now
# enemies_in_defend_range : entered DefendRange  — unit DETECTS / starts engaging
# enemies_in_ranged_range : entered RangedRange  — ranged units start shooting
#
# All three arrays are always populated by their Area3D signals.
# Which array the logic reads from depends on class and mode (see helpers below).
var enemies_in_attack_range: Array = []
var enemies_in_defend_range: Array = []
var enemies_in_ranged_range: Array = []
var current_target: Node = null
var forced_target: Node = null

# ─── Defend Mode State ────────────────────────────────────────────────────────
# defend_origin   : the point the unit guards; set to spawn pos, updated on click
# leash_distance  : how far from origin the unit will chase before turning back
# return_distance : how close to origin counts as "returned"
var defend_origin: Vector3
var leash_distance: float  = 12.0
var return_distance: float = 2.0

# ─── Timers ───────────────────────────────────────────────────────────────────
var spawn_invulnerable_time := 0.5
var spawn_timer   := 0.0
var bonus_timer:        float = 0.0
var bonus_interval:     float = 0.25
var cleanup_timer:      float = 0.0
var cleanup_interval:   float = 0.5
var target_recalc_timer:    float = 0.0
var target_recalc_interval: float = 0.2

# ─── Visuals ──────────────────────────────────────────────────────────────────
var highlight_material: StandardMaterial3D
var original_color: Color
var tween: Tween

# ─── Signals ──────────────────────────────────────────────────────────────────
signal damaged(amount, attacker)
signal attacked(target)

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready():
	add_to_group(team)
	enemy_team   = "Team2" if team == "Team1" else "Team1"
	spawn_timer  = spawn_invulnerable_time
	defend_origin = global_position   # default guard point is spawn position

	# Material
	if mesh_instance:
		var base_mat: Material = mesh_instance.get_active_material(0)
		if base_mat == null and mesh_instance.mesh:
			base_mat = mesh_instance.mesh.surface_get_material(0)
		if base_mat is StandardMaterial3D:
			highlight_material = base_mat.duplicate()
			mesh_instance.set_surface_override_material(0, highlight_material)
			original_color = highlight_material.albedo_color

	# Stats
	if data:
		max_health            = data.max_health
		health                = max_health
		base_damage           = data.damage
		base_speed            = data.move_speed
		base_armor            = data.armor
		base_physical_defence = data.physical_defence
		base_magical_defence  = data.magical_defence
		attack_range          = data.attack_range
		defend_range          = data.defend_range
		ranged_range          = data.ranged_range
		attack_cooldown       = data.attack_cooldown
		mode                  = data.default_mode
		unit_class            = data.unit_class
		attack_count          = data.attack_count
		load_passives()

	_apply_zone_radii()

	proximity_dist_sq = (attack_range + 0.6) * (attack_range + 0.6)

	if nav_agent:
		nav_agent.path_desired_distance   = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance       = 3.0
		call_deferred("_setup_navigation")

## Sets Area3D shape radii. Called once at spawn; unit_class never changes.
##
##   AttackRange  → always attack_range      (both classes)
##   DefendRange  → always defend_range      (both classes)
##   RangedRange  → ranged_range if Ranged,  0.01 (disabled) if Melee
##
## Mode does NOT affect radii — only the logic changes which array to read.
func _apply_zone_radii():
	attack_shape.shape.radius = attack_range
	defend_shape.shape.radius = defend_range
	if unit_class == "Ranged":
		ranged_shape.shape.radius = ranged_range
	else:
		ranged_shape.shape.radius = 0.01  # effectively disabled for melee

func _setup_navigation():
	await get_tree().physics_frame
	if nav_agent:
		nav_agent.set_velocity(Vector3.ZERO)

# ─────────────────────────────────────────────────────────────────────────────
#  STAT GETTERS
# ─────────────────────────────────────────────────────────────────────────────
func get_damage() -> int:           return base_damage + damage_bonus
func get_speed() -> float:          return base_speed  + speed_bonus
func get_armor() -> int:            return base_armor  + armor_bonus
func get_physical_defence() -> int: return base_physical_defence
func get_magical_defence() -> int:  return base_magical_defence

# ─────────────────────────────────────────────────────────────────────────────
#  MODE SWITCHING  (safe to call mid-game at any time)
# ─────────────────────────────────────────────────────────────────────────────
## Call this from your UI / input system when the player flips the mode toggle.
## Resets stale state so the unit re-evaluates cleanly from IDLE.
func set_mode(new_mode: String):
	if mode == new_mode:
		return
	mode = new_mode

	# Reset defend origin to current position when switching TO Defend
	if mode == "Defend":
		defend_origin = global_position

	# Cancel any ongoing chase/attack and let IDLE re-evaluate
	current_target = null
	_halt_nav()
	_transition(CombatState.IDLE)

# ─────────────────────────────────────────────────────────────────────────────
#  AREA3D CALLBACKS  (always populate all three arrays — logic decides usage)
# ─────────────────────────────────────────────────────────────────────────────
func is_enemy(body: Node) -> bool:
	if body == self: return false
	if body is Unit: return body.team == enemy_team
	return body.is_in_group(enemy_team)

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

func _on_ranged_range_body_entered(body: Node3D):
	if is_enemy(body) and body not in enemies_in_ranged_range:
		enemies_in_ranged_range.append(body)

func _on_ranged_range_body_exited(body: Node3D):
	enemies_in_ranged_range.erase(body)

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN LOOP
# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta):
	if spawn_timer > 0:
		spawn_timer -= delta

	attack_timer        -= delta
	cleanup_timer       += delta
	bonus_timer         += delta
	target_recalc_timer += delta

	if cleanup_timer >= cleanup_interval:
		cleanup_timer = 0.0
		_cleanup_dead_enemies()

	if bonus_timer >= bonus_interval:
		bonus_timer = 0.0
		update_bonuses()

	match combat_state:
		CombatState.MANUAL:    _state_manual(delta)
		CombatState.ATTACKING: _state_attacking(delta)
		CombatState.CHASING:   _state_chasing(delta)
		CombatState.IDLE:      _state_idle(delta)

# ─────────────────────────────────────────────────────────────────────────────
#  STATE: MANUAL
#  Player clicked a destination. AI is suspended.
#  Defend mode: repositions defend_origin, does NOT move the unit if engaged.
#  Attack mode: unit walks to destination, then AI resumes from IDLE.
# ─────────────────────────────────────────────────────────────────────────────
func _state_manual(delta):
	if nav_agent == null:
		_transition(CombatState.IDLE)
		return

	if nav_agent.is_navigation_finished():
		current_target = null
		_transition(CombatState.IDLE)
		return

	_apply_nav_velocity(delta)
	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────
#  STATE: ATTACKING
#  An enemy is within attack range. Unit stands still and deals damage.
#  Transitions out when no valid attack target remains.
#  Defend mode: also leashes — if the unit drifted too far from defend_origin
#               it stops attacking and returns (enemy kited it out).
# ─────────────────────────────────────────────────────────────────────────────
func _state_attacking(delta):
	if forced_target:
		if not is_instance_valid(forced_target) or forced_target.health <= 0:
			forced_target = null
	else:
		if not _can_attack():
			current_target = null
			_transition(CombatState.IDLE)
			return

	# Defend leash: if enemy kited us too far, break off and return
	if mode == "Defend":
		if global_position.distance_to(defend_origin) > leash_distance:
			current_target = null
			_transition(CombatState.IDLE)
			return

	# Stand still while attacking
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if target_recalc_timer >= target_recalc_interval:
		target_recalc_timer = 0.0

		if forced_target == null:
			current_target = _pick_attack_target()
		else:
			current_target = forced_target

	_try_attack()

# ─────────────────────────────────────────────────────────────────────────────
#  STATE: CHASING
#  Unit is moving toward a detected enemy.
#  Attack mode : chases freely until in attack range.
#  Defend mode : chases only within leash_distance from defend_origin;
#                turns back if the enemy leads it too far out.
# ─────────────────────────────────────────────────────────────────────────────
func _state_chasing(delta):
	# Transition to ATTACKING the moment an enemy enters attack range
	if _can_attack():
		_halt_nav()
		_transition(CombatState.ATTACKING)
		return

	# No more detectable enemies — give up and go idle
	if not _has_detectable_enemy():
		_halt_nav()
		current_target = null
		_transition(CombatState.IDLE)
		return

	# Defend leash: if we've drifted too far from the guard point, return
	if mode == "Defend":
		if global_position.distance_to(defend_origin) > leash_distance:
			current_target = null
			if nav_agent:
				nav_agent.target_position = defend_origin
			_apply_nav_velocity(delta)
			move_and_slide()
			return

	# Refresh chase target every recalc tick.
	# IMPORTANT: always update nav_agent.target_position even when the target
	# node hasn't changed — the enemy is MOVING, so its world position changes
	# every frame. Without this update the unit only steers toward where the
	# enemy WAS when the chase started, not where they are now.
	if target_recalc_timer >= target_recalc_interval:
		target_recalc_timer = 0.0
		if forced_target:
			current_target = forced_target
		else:
			var new_target = _pick_chase_target()
			if new_target:
				current_target = new_target
		if current_target and is_instance_valid(current_target) and nav_agent:
			nav_agent.target_position = current_target.global_position

	_apply_nav_velocity(delta)
	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────
#  STATE: IDLE
#  No active orders. Evaluates every frame and transitions as soon as anything
#  is detected. In Defend mode, returns to defend_origin if not already there.
# ─────────────────────────────────────────────────────────────────────────────
func _state_idle(delta):
	# Immediate attack if something walked into attack range
	if _can_attack():
		_transition(CombatState.ATTACKING)
		return

	# Start chasing if we detect something worth chasing
	if _has_detectable_enemy():
		current_target = _pick_chase_target()
		if current_target and nav_agent:
			nav_agent.target_position = current_target.global_position
		_transition(CombatState.CHASING)
		return

	# Defend mode: drift back to guard point if we've wandered
	if mode == "Defend":
		if global_position.distance_to(defend_origin) > return_distance:
			if nav_agent:
				nav_agent.target_position = defend_origin
			_apply_nav_velocity(delta)
			move_and_slide()
			return

	# Truly idle
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────
#  TRANSITION
# ─────────────────────────────────────────────────────────────────────────────
func _transition(new_state: CombatState):
	combat_state = new_state

# ─────────────────────────────────────────────────────────────────────────────
#  DETECTION & TARGETING HELPERS
#
#  Zone → array mapping (fixed, never changes):
#    AttackRange → enemies_in_attack_range   (both classes)
#    DefendRange → enemies_in_defend_range   (both classes)
#    RangedRange → enemies_in_ranged_range   (Ranged only; disabled on Melee)
#
#  What each class/mode reads:
#
#  Melee + Attack  : detect via DefendRange → chase; attack via AttackRange + proximity
#  Melee + Defend  : detect via DefendRange → engage within leash; attack via AttackRange + proximity
#  Ranged + Attack : detect + attack via RangedRange (shoot from afar)
#  Ranged + Defend : detect + attack via RangedRange; leash applies
# ─────────────────────────────────────────────────────────────────────────────

## Returns true if the unit can deal damage to something RIGHT NOW.
func _can_attack() -> bool:
	if unit_class == "Ranged":
		# Ranged shoots anything in their ranged zone
		return _first_valid(enemies_in_ranged_range) != null

	# Melee: AttackRange Area3D OR proximity fallback
	if _first_valid(enemies_in_attack_range) != null:
		return true
	# Proximity fallback: catches collision-blocked cases where Area3D lags
	return _proximity_enemy_exists(enemies_in_defend_range)

## Returns true if there is an enemy worth CHASING (not necessarily in attack range yet).
func _has_detectable_enemy() -> bool:
	if forced_target and is_instance_valid(forced_target) and forced_target.health > 0:
		return true

	if unit_class == "Ranged":
		# Ranged detects via their wide ranged zone
		return _first_valid(enemies_in_ranged_range) != null

	# Melee detects via DefendRange regardless of mode
	# (mode affects WHAT WE DO with the detection, not whether we see them)
	return _first_valid(enemies_in_defend_range) != null

## Picks the best target to attack (called during ATTACKING state).
func _pick_attack_target() -> Node:
	if forced_target and is_instance_valid(forced_target) and forced_target.health > 0:
		print("got")
		return forced_target

	if unit_class == "Ranged":
		return get_closest_enemy(enemies_in_ranged_range)

	var from_area = get_closest_enemy(enemies_in_attack_range)
	if from_area:
		return from_area
	return _closest_in_proximity(enemies_in_defend_range)

## Picks the best target to chase toward (called when entering CHASING state).
## Both Attack and Defend mode use DefendRange for melee detection;
## Defend mode additionally enforces the leash in _state_chasing.
func _pick_chase_target() -> Node:
	if forced_target and is_instance_valid(forced_target) and forced_target.health > 0:
		return forced_target
	
	if unit_class == "Ranged":
		return get_closest_enemy(enemies_in_ranged_range)
	return get_closest_enemy(enemies_in_defend_range)

# ─────────────────────────────────────────────────────────────────────────────
#  ATTACK EXECUTION
# ─────────────────────────────────────────────────────────────────────────────
func _try_attack():
	if attack_timer > 0:
		return
	attack_timer = attack_cooldown

	# Build target pool
	var pool: Array = []
	if unit_class == "Ranged":
		pool = enemies_in_ranged_range.duplicate()
	else:
		pool = enemies_in_attack_range.duplicate()
		# Proximity fill: add any defend-zone enemy that is actually within attack distance
		for e in enemies_in_defend_range:
			if e not in pool and is_instance_valid(e) and e.health > 0:
				if global_position.distance_squared_to(e.global_position) <= proximity_dist_sq:
					pool.append(e)

	if pool.is_empty():
		return

	var my_pos = global_position
	pool.sort_custom(func(a, b):
		return my_pos.distance_squared_to(a.global_position) < my_pos.distance_squared_to(b.global_position)
	)

	var damage    = get_damage()
	var hit_count = 0
	for enemy in pool:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		enemy.take_damage(damage, self)
		emit_signal("attacked", enemy)
		hit_count += 1
		if hit_count >= attack_count:
			break

# ─────────────────────────────────────────────────────────────────────────────
#  MOVEMENT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _apply_nav_velocity(delta: float):
	if nav_agent == null or nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		return

	var next_pos  = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	var spd       = get_speed()
	velocity.x = direction.x * spd
	velocity.z = direction.z * spd
	if is_on_floor():
		velocity.y = direction.y * spd
	else:
		velocity.y -= GRAVITY * delta

func _halt_nav():
	if nav_agent:
		nav_agent.target_position = global_position
	velocity.x = 0.0
	velocity.z = 0.0

# ─────────────────────────────────────────────────────────────────────────────
#  PROXIMITY HELPERS  (melee fallback when Area3D lags due to collision)
# ─────────────────────────────────────────────────────────────────────────────
func _proximity_enemy_exists(arr: Array) -> bool:
	var my_pos = global_position
	for e in arr:
		if is_instance_valid(e) and e.health > 0:
			if my_pos.distance_squared_to(e.global_position) <= proximity_dist_sq:
				return true
	return false

func _closest_in_proximity(arr: Array) -> Node:
	var my_pos     = global_position
	var closest:   Node  = null
	var closest_sq: float = INF
	for e in arr:
		if not is_instance_valid(e) or e.health <= 0:
			continue
		var d = my_pos.distance_squared_to(e.global_position)
		if d <= proximity_dist_sq and d < closest_sq:
			closest    = e
			closest_sq = d
	return closest

# ─────────────────────────────────────────────────────────────────────────────
#  ARRAY HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _first_valid(arr: Array) -> Node:
	for e in arr:
		if is_instance_valid(e) and e.health > 0:
			return e
	return null

func get_closest_enemy(from_array: Array) -> Node:
	if from_array.is_empty():
		return null
	var closest: Node    = null
	var closest_dist_sq: float = INF
	var my_pos = global_position
	for enemy in from_array:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var d = my_pos.distance_squared_to(enemy.global_position)
		if d < closest_dist_sq:
			closest         = enemy
			closest_dist_sq = d
	return closest

# ─────────────────────────────────────────────────────────────────────────────
#  PERIODIC CLEANUP
# ─────────────────────────────────────────────────────────────────────────────
func _cleanup_dead_enemies():
	_filter_dead(enemies_in_attack_range)
	_filter_dead(enemies_in_defend_range)
	_filter_dead(enemies_in_ranged_range)

func _filter_dead(arr: Array):
	var i = arr.size() - 1
	while i >= 0:
		if not is_instance_valid(arr[i]) or arr[i].health <= 0:
			arr.remove_at(i)
		i -= 1

# ─────────────────────────────────────────────────────────────────────────────
#  BONUS UPDATE  (from passives)
# ─────────────────────────────────────────────────────────────────────────────
func update_bonuses():
	damage_bonus = 0
	speed_bonus  = 0
	armor_bonus  = 0
	for passive in passive_container.get_children():
		if passive.has_method("apply_bonus"):
			passive.apply_bonus(self)

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Player move command.
## Attack mode : unit physically walks to target_pos; AI resumes on arrival.
## Defend mode : repositions the guard point; unit does NOT move if ATTACKING
##               (you can't drag a unit away from a fight it's already in).
func move_to(target_pos: Vector3):
	if mode == "Defend":
		# Blocked while engaged — the unit is committed to the fight
		if combat_state == CombatState.ATTACKING:
			return
		defend_origin = target_pos
		if nav_agent:
			nav_agent.target_position = target_pos
		current_target = null
		_transition(CombatState.MANUAL)
	else:
		if nav_agent:
			nav_agent.target_position = target_pos
		current_target = null
		_transition(CombatState.MANUAL)

## Immediately cancel movement and let AI re-evaluate from IDLE.
func stop_moving():
	_halt_nav()
	velocity = Vector3.ZERO
	_transition(CombatState.IDLE)

func take_damage(amount: int, attacker: Node = null, is_reflect: bool = false):
	if spawn_timer > 0:
		return
	if health <= 0:
		return
	var armor              = get_armor()
	var damage_multiplier  = 100.0 / (100.0 + float(armor))
	var reduced            = max(int(amount * damage_multiplier), 1)
	health -= reduced
	if not is_reflect:
		emit_signal("damaged", reduced, attacker)
	if health <= 0:
		die()

## Force this unit to immediately chase and attack a specific target.
## Called by the camera when the player right-clicks an enemy unit.
func set_attack_target(target: Node):
	if not is_instance_valid(target) or not is_enemy(target):
		return
	forced_target = target
	current_target = target

	target_recalc_timer = target_recalc_interval
	attack_timer = 0.0
	
	if nav_agent:
		nav_agent.target_position = target.global_position
	_transition(CombatState.CHASING)

func die():
	if forced_target == self:
		forced_target = null
	queue_free()

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
	var target_color = original_color * (1.4 if active else 1.0)
	tween.tween_property(highlight_material, "albedo_color", target_color, 0.15)
