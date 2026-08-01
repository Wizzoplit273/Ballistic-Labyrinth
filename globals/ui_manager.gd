extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

const LOBBY_FILE: String = "res://ui/lobby/lobby.tscn"
const PAUSE_MENU_FILE: String = "res://ui/pause_menu/pause_menu.tscn"
const CHAT_MENU_FILE: String = "res://ui/chat_menu/chat_menu.tscn"
var lobby_node: CanvasLayer = null
var pause_menu_node: CanvasLayer = null
var chat_menu_node: Window = null

var is_ui_configured: bool = false

func update_lobby_register() -> void:
	if not is_ui_configured: return
	lobby_node.update_lobby_register()

func update_online_status() -> void:
	if not is_ui_configured: return
	lobby_node.update_online_status()

func _input(event: InputEvent) -> void:
	if not is_ui_configured: return # could work for dedicated server console as well so idk
	if event.is_action_pressed(&"HideChat"):
		chat_menu_node.get_node("Texture").visible = not chat_menu_node.get_node("Texture").visible
		return
	if event.is_action(&"MoveWindow"):
		if not chat_menu_node.get_node("Texture").visible: return
		var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
		chat_menu_node.position = mouse_pos - (chat_menu_node.size / 2.0)
	if event.is_action_pressed(&"ToggleChatResize"):
		chat_menu_node.borderless = not chat_menu_node.borderless

func master_enter_tree() -> void:
	if OS.has_feature("server") or DisplayServer.get_name() == "headless": return
	initialize_ui()
	is_ui_configured = true

func initialize_ui() -> void:
	create_lobby()
	lobby_node.activate(true)
	create_pause_menu()
	create_chat_menu()

func create_lobby() -> void:
	if lobby_node != null: return
	lobby_node = load(LOBBY_FILE).instantiate()
	add_child(lobby_node)

func create_pause_menu() -> void:
	if pause_menu_node != null: return
	pause_menu_node = load(PAUSE_MENU_FILE).instantiate()
	add_child(pause_menu_node)

func create_chat_menu() -> void:
	if chat_menu_node != null: return
	chat_menu_node = load(CHAT_MENU_FILE).instantiate()
	add_child(chat_menu_node)

func delete_lobby() -> void:
	if lobby_node == null: return
	lobby_node.queue_free()
