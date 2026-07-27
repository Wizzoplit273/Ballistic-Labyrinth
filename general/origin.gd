extends Node

const INGAME_FILE: String = "res://ingame/ingame.tscn"
const LOBBY_FILE: String = "res://ui/lobby/lobby.tscn"
const PAUSE_MENU_FILE: String = "res://ui/pause_menu/pause_menu.tscn"
var ingame_node: Node = null
var lobby_node: CanvasLayer = null
var pause_menu_node: CanvasLayer = null

func _ready() -> void:
	initialize_ui()

func initialize_ui() -> void:
	create_lobby()
	lobby_node.activate(true)
	create_pause_menu()

func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	
	add_child(ingame_node)
	if lobby_node != null: lobby_node.activate(false)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()

func create_lobby() -> void:
	if lobby_node != null: return
	lobby_node = load(LOBBY_FILE).instantiate()
	add_child(lobby_node)

func create_pause_menu() -> void:
	if pause_menu_node != null: return
	pause_menu_node = load(PAUSE_MENU_FILE).instantiate()
	add_child(pause_menu_node)

func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()

func delete_lobby() -> void:
	if lobby_node == null: return
	lobby_node.queue_free()

func end_ingame() -> void:
	delete_ingame()
	lobby_node.activate(true)

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()
