extends Node

var main_menu_node: Control = null
var ingame_node: Node = null

func _ready() -> void:
	create_main_menu()
	main_menu_node.activate(true)

const MAIN_MENU_FILE: String = "res://ui/main_menu/main_menu.tscn"
func create_main_menu() -> void:
	if main_menu_node != null: return
	main_menu_node = load(MAIN_MENU_FILE).instantiate()
	add_child(main_menu_node)

const INGAME_FILE: String = "res://ingame/ingame.tscn"
func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	$PauseMenu.NEXT_ROUND_TIMER = ingame_node.get_node("Timers/NextRoundDelay")
	
	add_child(ingame_node)
	if main_menu_node != null: main_menu_node.activate(false)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()

func delete_main_menu() -> void:
	if main_menu_node == null: return
	main_menu_node.queue_free()

func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()
