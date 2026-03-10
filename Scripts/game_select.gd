extends Control

#Map References
const MAIN = preload("uid://byt88txdkcalt")

@onready var gamemode: OptionButton = $VBoxContainer/Gamemode
@onready var map: OptionButton = $VBoxContainer/Map

var gamemode_id: int = 0
var map_id: int = 0

func _ready() -> void:
	if map_id == 0:
		MAIN
	if map_id == 1:
		pass
	if map_id == 2:
		pass

	#if gamemode_id == 0:
		#

func load_game():
	var scene_to_load
	var gamemode_to_append

	match map_id:
		0:
			scene_to_load = MAIN
		1:
			pass # add other maps
		2:
			pass
	
	#match gamemode_id:
		#0:
			#gamemode_to_append = pass
		#1:
			#gamemode_to_append =
		#3:
			#gamemode_to_append

	if scene_to_load:
		get_tree().change_scene_to_packed(scene_to_load)

func _on_start_pressed() -> void:
	load_game()

func _on_gamemode_item_selected(index: int) -> void:
	gamemode_id = index

func _on_map_item_selected(index: int) -> void:
	map_id = index
