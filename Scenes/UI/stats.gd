extends Control

@onready var intro: Label = $CanvasLayer/Stats/Intro
@onready var info: Label = $CanvasLayer/Stats/Info
@onready var health: Label = $"CanvasLayer/Stats/Main Stats/Health"
@onready var damage: Label = $"CanvasLayer/Stats/Main Stats/Damage"
@onready var defence: Label = $"CanvasLayer/Stats/Main Stats/Defence"
@onready var speed: Label = $"CanvasLayer/Stats/Main Stats/Speed"
@onready var vitality: Label = $"CanvasLayer/Stats/Main Attributes/Vitality"
@onready var strength: Label = $"CanvasLayer/Stats/Main Attributes/Strength"
@onready var intelligence: Label = $"CanvasLayer/Stats/Main Attributes/Intelligence"
@onready var dexterity: Label = $"CanvasLayer/Stats/Main Attributes/Dexterity"
@onready var health_bar: ProgressBar = $CanvasLayer/Stats/HealthBar


var current_unit: Node = null
var update_timer: float = 0.0
var update_interval: float = 0.1  # Update stats 10 times per second

func _ready():
	clear_stats()

func _process(delta: float) -> void:
	if current_unit and is_instance_valid(current_unit):
		update_timer += delta
		if update_timer >= update_interval:
			update_timer = 0.0
			update_stats()
	else:
		# Unit died or became invalid
		if current_unit:
			clear_stats()
			current_unit = null

# Called by Camera when a unit is selected
func set_unit(unit: Node) -> void:
	current_unit = unit
	if unit and is_instance_valid(unit):
		update_stats()
	else:
		clear_stats()

# Update all stats from current unit
func update_stats() -> void:
	if not current_unit or not is_instance_valid(current_unit):
		clear_stats()
		return
	
	# Basic info
	intro.text = current_unit.name
	info.text = "%s | %s | %s Mode" % [
		current_unit.team,
		current_unit.unit_class,
		current_unit.mode
	]
	
	# Main Stats
	var hp = current_unit.health
	var max_hp = current_unit.data.max_health
	health.text = "Hp: %d/%d" % [current_unit.health, current_unit.data.max_health]
	damage.text = "Dmg: %d" % (current_unit.damage + current_unit.damage_bonus)
	defence.text = "Defe: %d" % 0  # Not implemented yet
	speed.text = "Spa: %.1f" % current_unit.attack_cooldown

	# Update health bar
	if max_hp > 0:
		var health_percent = float(hp) / float(max_hp) * 100.0
		health_bar.value = health_percent

		# Color-coded health text
		if health_percent > 75:
			health.add_theme_color_override("font_color", Color.WEB_GREEN)
		elif health_percent > 50:
			health.add_theme_color_override("font_color", Color.YELLOW)
		elif health_percent > 25:
			health.add_theme_color_override("font_color", Color.DARK_ORANGE)
		else:
			health.add_theme_color_override("font_color", Color.DARK_RED)
	else:
		health_bar.value = 0
		health.add_theme_color_override("font_color", Color.DIM_GRAY)

	# Calculate attributes from stats (you can customize this formula)
	var vitality_val = int(current_unit.data.max_health / 10.0)
	var strength_val = int(current_unit.damage / 2.0)
	var intelligence_val = 0  # For future magic/special abilities
	var dexterity_val = int(current_unit.attack_cooldown * 2.0)
	
	vitality.text = "Vit: %d" % vitality_val
	strength.text = "Str: %d" % strength_val
	intelligence.text = "Int: %d" % intelligence_val
	dexterity.text = "Dex: %d" % dexterity_val

# Clear stats when no unit is selected
func clear_stats() -> void:
	intro.text = "No Unit Selected"
	info.text = ""
	health.text = "Hp: --"
	damage.text = "Dmg: --"
	defence.text = "Def: --"
	speed.text = "Spa: --"
	vitality.text = "Vit: --"
	strength.text = "Str: --"
	intelligence.text = "Int: --"
	dexterity.text = "Dex: --"
	health_bar.value = 0
	health.add_theme_color_override("font_color", Color.WHITE)
