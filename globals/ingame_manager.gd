extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame_node: Node = null

var is_ingame_configured: bool = false

@rpc("any_peer", "reliable")
func start_game():
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	start_ingame()

@rpc("any_peer", "reliable")
func end_game():
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	end_ingame()

@rpc("authority", "reliable")
func start_ingame() -> void:
	if not NetworkManager.is_online: return
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	create_ingame()
	if multiplayer.is_server: start_ingame.rpc()

func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	scene_root.add_child(ingame_node)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()
	is_ingame_configured = true

@rpc("authority", "reliable")
func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()
	is_ingame_configured = false

@rpc("authority", "reliable")
func end_ingame() -> void:
	delete_ingame()
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(true)
	if not NetworkManager.is_online: return
	if multiplayer.is_server: end_ingame.rpc()

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()
