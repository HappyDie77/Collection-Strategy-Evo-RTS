extends Passive

@onready var shield_ani: Node3D = $Shield_Ani
@onready var animation_player: AnimationPlayer = $Shield_Ani/AnimationPlayer

@export var shield_cooldown: float = 5.0
@export var shield_amount: int = 30

var shield_active: bool = true
var cooldown_timer: float = 0.0

func _ready():
	unit.damaged.connect(_on_damaged)
	shield_ani.visible = false

func _process(delta: float) -> void:
	if not shield_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			shield_active = true
			#print("[", unit.name, "] Shield recharged!")

func _on_damaged(amount: int, attacker):
	if not shield_active:
		return

	shield_ani.visible = true
	var mesh = unit.mesh_instance.mesh
	if mesh is CapsuleMesh:
		shield_ani.scale = Vector3.ONE * (mesh.height - 0.9)

	# Block up to shield_amount of the REAL damage
	var blocked = min(shield_amount, amount)
	unit.add_shield(10)
	animation_player.play("Shield_break/Shield_brek")

	unit.health += blocked

	shield_active = false
	cooldown_timer = shield_cooldown

	print("[", unit.name, "] Shield blocked ", blocked, " damage!")
