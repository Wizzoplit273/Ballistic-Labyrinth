extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

const LOBBY_FILE: String = "res://ui/lobby/lobby.tscn"
const PAUSE_MENU_FILE: String = "res://ui/pause_menu/pause_menu.tscn"
var lobby_node: CanvasLayer = null
var pause_menu_node: CanvasLayer = null

var is_ui_configured: bool = false

func _enter_tree() -> void:
	if OS.has_feature("server") or DisplayServer.get_name() == "headless": return
	initialize_ui()
	is_ui_configured = true

func initialize_ui() -> void:
	create_lobby()
	lobby_node.activate(true)
	create_pause_menu()

func create_lobby() -> void:
	if lobby_node != null: return
	lobby_node = load(LOBBY_FILE).instantiate()
	add_child(lobby_node)

func create_pause_menu() -> void:
	if pause_menu_node != null: return
	pause_menu_node = load(PAUSE_MENU_FILE).instantiate()
	add_child(pause_menu_node)

func delete_lobby() -> void:
	if lobby_node == null: return
	lobby_node.queue_free()
