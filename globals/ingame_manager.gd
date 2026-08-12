extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

var current_seed: int = 0
var current_maze_dimensions: Vector2i = Vector2i(20, 12) ## first entry is width, second is height

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame_node: Node = null

var is_ingame_configured: bool = false

var finished_clients: Array = []

const NEW_PLAYER_CONTROLLER_FILE: String = "res://ingame/controllers/player_controller/player_controller.tscn"
func create_player_controller(sid: int) -> void:
	if sid <= 0: return
	var control: Node = load(NEW_PLAYER_CONTROLLER_FILE).instantiate()
	scene_root.get_node("Controllers").add_child(control)
	control.sid = sid
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	rpc_id

const NEW_BOT_CONTROLLER_FILE: String = "res://ingame/controllers/bot_controller/bot_controller.tscn"
func create_bot_controller(sid: int) -> void:
	if sid >= 0: return

func create_controllers() -> void:
	if not multiplayer.is_server(): return
	for sid: int in SessionManager.data:
		if sid >= 1: create_player_controller(sid)
		elif sid == 0: continue
		else: create_bot_controller(sid)

func delete_controllers() -> void:
	if not multiplayer.is_server(): return

@rpc("any_peer", "reliable")
func start_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	current_seed = randi()
	start_ingame.rpc(current_seed, current_maze_dimensions, true)

@rpc("any_peer", "reliable")
func end_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	end_ingame()

@rpc("authority", "reliable", "call_local")
func start_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool = false) -> void:
	if not NetworkManager.is_online: return
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	current_seed = maze_seed
	current_maze_dimensions = maze_dimensions
	create_ingame(is_animated)

func create_ingame(is_animated: bool = false) -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	scene_root.add_child(ingame_node)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	is_ingame_configured = true
	ingame_node.modified_ready(is_animated)

@rpc("authority", "reliable")
func restart_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool = false) -> void:
	delete_ingame()
	await get_tree().process_frame
	start_ingame(maze_seed, maze_dimensions, is_animated)

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
	create_ingame(true)

func finish_network_maze_generation() -> void:
	if not multiplayer.is_server(): return
	for pid: int in multiplayer.get_peers():
		if pid in finished_clients: continue
		restart_ingame.rpc_id(pid, current_seed, current_maze_dimensions, false)

@rpc("any_peer", "reliable")
func add_finished_generation() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if pid <= 1: return
	finished_clients.append(pid)

const FINISH_GENERATION_DELAY: float = 1.0
func broadcast_generation_finish() -> void:
	if multiplayer.is_server():
		await get_tree().create_timer(FINISH_GENERATION_DELAY).timeout
		finish_network_maze_generation()
		return
	add_finished_generation.rpc_id(1)
