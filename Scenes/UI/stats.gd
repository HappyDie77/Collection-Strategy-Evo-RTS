extends Control

@onready var intro: Label = $CanvasLayer/Stats/Intro
@onready var info: Label = $CanvasLayer/Stats/Info
@onready var health: Label = $"CanvasLayer/Stats/Main Stats/Health"
@onready var attack: Label = $"CanvasLayer/Stats/Main Stats/Attack"
@onready var armor: Label = $"CanvasLayer/Stats/Main Stats/Armor"
@onready var physical_defence: Label = $"CanvasLayer/Stats/Main Stats/PhysicalDefence"
@onready var magical_defence: Label = $"CanvasLayer/Stats/Main Stats/MagicalDefence"
@onready var attack_speed: Label = $"CanvasLayer/Stats/Main Stats/AttackSpeed"
@onready var attack_range: Label = $"CanvasLayer/Stats/Main Stats/AttackRange"
@onready var speed: Label = $"CanvasLayer/Stats/Main Stats/Speed"

@onready var health_bar: ProgressBar = $CanvasLayer/Stats/HealthBar
@onready var shield_bar: ProgressBar = $CanvasLayer/Stats/ShieldBar

@onready var stats: Panel = $CanvasLayer/Stats
@onready var skills: Panel = $CanvasLayer/Skills

var current_unit: Node = null
var update_timer: float = 0.0
var update_interval: float = 0.1  # Update stats 10 times per second

func _ready():
	clear_stats()
	stats.visible = false

func _process(delta: float) -> void:
	if current_unit and is_instance_valid(current_unit):
		update_timer += delta
		if update_timer >= update_interval:
			update_timer = 0.0
			update_stats()
	else:
		stats.visible = false
		clear_stats()
		current_unit = null

# Called by Camera when a unit is selected
func set_unit(unit: Node) -> void:
	current_unit = unit
	if unit and is_instance_valid(unit):
		update_stats()
		stats.visible = true
	else:
		clear_stats()
		stats.visible = false

# Update all stats from current unit
func update_stats() -> void:
	if not current_unit or not is_instance_valid(current_unit):
		stats.visible = false
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
	var max_hp = current_unit.max_health
	health.text = "Health: %d/%d" % [hp, max_hp]
	attack.text = "Attack: %d" % current_unit.get_damage()
	armor.text = "Armor: %d" % current_unit.get_armor()
	physical_defence.text = "Physical Defence: %d" % current_unit.get_physical_defence()
	magical_defence.text = "Magical Defence: %d" % current_unit.get_magical_defence()
	speed.text = "Speed: %.1f" % current_unit.get_speed()
	attack_range.text = "Attack Range: %.1f" % current_unit.attack_range
	attack_speed.text = "Attack Speed: %.2f" % current_unit.attack_cooldown

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

# Clear stats when no unit is selected
func clear_stats() -> void:
	intro.text = "No Unit Selected"
	info.text = ""
	health.text = "Health: --"
	attack.text = "Attack: --"
	physical_defence.text = "Physical Defence: --"
	magical_defence.text = "Magical Defence: --"
	attack_speed.text = "Attack Speed: --"
	attack_range.text = "Attack Range: --"
	armor.text = "Armor: --"
	speed.text = "Speed: --"
	health_bar.value = 0
	shield_bar.value = 0
	health.add_theme_color_override("font_color", Color.WHITE)
