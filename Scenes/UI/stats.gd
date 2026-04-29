extends Control

@onready var intro:             Label       = $CanvasLayer/Stats/Intro
@onready var info:              Label       = $CanvasLayer/Stats/Info
@onready var health: RichTextLabel = $"CanvasLayer/Stats/Main Stats/Health"
@onready var attack:            Label       = $"CanvasLayer/Stats/Main Stats/Attack"
@onready var armor:             Label       = $"CanvasLayer/Stats/Main Stats/Armor"
@onready var physical_defence:  Label       = $"CanvasLayer/Stats/Main Stats/PhysicalDefence"
@onready var magical_defence:   Label       = $"CanvasLayer/Stats/Main Stats/MagicalDefence"
@onready var attack_speed:      Label       = $"CanvasLayer/Stats/Main Stats/AttackSpeed"
@onready var attack_range:      Label       = $"CanvasLayer/Stats/Main Stats/AttackRange"
@onready var speed:             Label       = $"CanvasLayer/Stats/Main Stats/Speed"
@onready var mode_label:        Label       = $"CanvasLayer/Stats/mode_label"   # add this Label node in editor
@onready var health_bar:        ProgressBar = $CanvasLayer/Stats/HealthBar
@onready var shield_bar:        ProgressBar = $CanvasLayer/Stats/ShieldBar
@onready var stats:             Panel       = $CanvasLayer/Stats
@onready var skills:            Panel       = $CanvasLayer/Skills

var current_unit: Node = null
var update_timer:    float = 0.0
var update_interval: float = 0.1   # 10 times per second

func _ready():
	clear_stats()
	stats.visible = false
	health.bbcode_enabled = true

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

# Called by Camera when a unit is selected / deselected
func set_unit(unit: Node) -> void:
	current_unit = unit
	if unit and is_instance_valid(unit):
		update_stats()
		stats.visible = true
	else:
		clear_stats()
		stats.visible = false

func update_stats() -> void:
	if not current_unit or not is_instance_valid(current_unit):
		stats.visible = false
		clear_stats()
		return

	# ── Identity ──────────────────────────────────────────────────────────────
	intro.text = current_unit.name
	info.text  = "%s | %s" % [current_unit.team, current_unit.unit_class]

	# ── Mode label (updates live so V-key toggle is visible immediately) ──────
	var m: String = current_unit.mode if "mode" in current_unit else "?"
	mode_label.text = "Mode: %s" % m
	# Tint the label so the player can immediately tell which mode is active
	if m == "Attack":
		mode_label.add_theme_color_override("font_color", Color.TOMATO)
	else:
		mode_label.add_theme_color_override("font_color", Color.CORNFLOWER_BLUE)

	# ── Main Stats ────────────────────────────────────────────────────────────
	var hp     = current_unit.health
	var max_hp = current_unit.max_health
	var sh = current_unit.shield if "shield" in current_unit else 0

	health.text = "Health: %d/%d [color=cyan](+%d)[/color]" % [hp, max_hp, sh]
	attack.text           = "Attack: %d"              % current_unit.get_damage()
	armor.text            = "Armor: %d"               % current_unit.get_armor()
	physical_defence.text = "Physical Defence: %d"    % current_unit.get_physical_defence()
	magical_defence.text  = "Magical Defence: %d"     % current_unit.get_magical_defence()
	speed.text            = "Speed: %.1f"             % current_unit.get_speed()
	attack_range.text     = "Attack Range: %.1f"      % current_unit.attack_range
	attack_speed.text     = "Attack Speed: %.2f"      % current_unit.attack_cooldown

	# ── Health bar + colour ───────────────────────────────────────────────────
	if max_hp > 0:
		var pct = float(hp) / float(max_hp) * 100.0
		health_bar.value = pct
		if pct > 75:
			health.add_theme_color_override("font_color", Color.WEB_GREEN)
		elif pct > 50:
			health.add_theme_color_override("font_color", Color.YELLOW)
		elif pct > 25:
			health.add_theme_color_override("font_color", Color.DARK_ORANGE)
		else:
			health.add_theme_color_override("font_color", Color.DARK_RED)
	else:
		health_bar.value = 0
		health.add_theme_color_override("font_color", Color.DIM_GRAY)

	# ── SHIELD BAR ───────────────────────────────────────────────
	var msh = current_unit.max_shield if "max_shield" in current_unit else 0

	if msh > 0:
		shield_bar.visible = true

		# Ensure correct ProgressBar range
		shield_bar.min_value = 0
		shield_bar.max_value = msh

		# Direct value (NO percent math)
		shield_bar.value = sh
	else:
		shield_bar.visible = false
		shield_bar.value = 0

func clear_stats() -> void:
	intro.text            = "No Unit Selected"
	info.text             = ""
	health.text           = "Health: --"
	attack.text           = "Attack: --"
	physical_defence.text = "Physical Defence: --"
	magical_defence.text  = "Magical Defence: --"
	attack_speed.text     = "Attack Speed: --"
	attack_range.text     = "Attack Range: --"
	armor.text            = "Armor: --"
	speed.text            = "Speed: --"
	mode_label.text       = "Mode: --"
	health_bar.value      = 0
	shield_bar.value = 0
	shield_bar.visible = false
	health.add_theme_color_override("font_color", Color.WHITE)
	mode_label.add_theme_color_override("font_color", Color.WHITE)
