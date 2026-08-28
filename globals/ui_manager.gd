extends Control

const LOBBY_FILE: String = "res://ui/lobby/lobby.tscn"
const PAUSE_MENU_FILE: String = "res://ui/pause_menu/pause_menu.tscn"
const CHAT_MENU_FILE: String = "res://ui/chat_menu/chat_menu.tscn"
var lobby_node: CanvasLayer = null
var pause_menu_node: CanvasLayer = null
var chat_menu_node: CanvasLayer = null

var is_ui_configured: bool = false

func update_lobby_register() -> void:
	if not is_ui_configured: return
	lobby_node.update_lobby_register()

func update_online_status() -> void:
	if not is_ui_configured: return
	lobby_node.update_online_status()

## global handler for making line inputs unfocus when clicking outside them
func _input(event: InputEvent) -> void:
	if not is_ui_configured: return
	if not event is InputEventMouseButton and not event.is_action_pressed(&"UnfocusChat"): return
	if not event.is_pressed(): return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
	var focused_node: Control = get_viewport().gui_get_focus_owner()
	if focused_node == null: return
	var mouse_pos: Vector2 = focused_node.get_global_mouse_position()
	var control_rect := Rect2(Vector2.ZERO, focused_node.size)
	if control_rect.has_point(mouse_pos): return
	focused_node.release_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not is_ui_configured: return # could work for dedicated server console as well so idk
	if event.is_action_pressed(&"FocusChat"):
		chat_menu_node.focus_chat()
	if event.is_action_pressed(&"Pause"):
		if lobby_node.visible and not IngameManager.is_ingame_configured: return
		if SessionManager.data[multiplayer.get_unique_id()].get("admin") != true: return
		MasterManager.set_pause.rpc_id(1, not pause_menu_node.visible)
	if event.is_action_pressed(&"MoveWindow"):
		chat_menu_node.toggle_move_window()
	if event.is_action_pressed(&"ResizeWindow"):
		chat_menu_node.toggle_resize_window()
	if event.is_action_pressed(&"ToggleLobby"):
		lobby_node.activate(not lobby_node.visible)
	if event.is_action_pressed(&"HideChat"):
		chat_menu_node.toggle_visibility()
		return

func master_enter_tree() -> void:
	if NetworkManager.is_dedicated_server: return
	process_mode = Node.PROCESS_MODE_ALWAYS
	initialize_ui()
	is_ui_configured = true

func initialize_ui() -> void:
	create_lobby()
	lobby_node.activate(true)
	create_pause_menu()
	create_chat_menu()
	lobby_node.write_version_text()
	chat_menu_node.connect_signal()

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

func toggle_admin_options(is_admin: bool) -> void:
	if not is_ui_configured: return
	pause_menu_node.toggle_admin_options(is_admin)

@rpc("authority", "reliable")
func confirm_spectating() -> void:
	if lobby_node == null: return
	lobby_node.toggle_spectate_window(true)
