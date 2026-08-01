extends Node

var data: Dictionary = {}
var profile_data: Dictionary = {}

func is_bot(session_id: int) -> bool:
	return session_id < 0

func turn_local_to_online_profile() -> void:
	data.clear()
	data[multiplayer.get_unique_id()] = profile_data
	#UIManager.update_lobby_register() # happens right after exiting this scope

func master_enter_tree() -> void:
	create_local_profile()

func create_local_profile() -> void:
	if data.has(0): return
	profile_data = {
		"name": "unnamed",
		"color": Color(1.0, 1.0, 1.0, 1.0),
		"kills": 0,
		"score": 0
	}
	data[0] = profile_data

func clear_registry() -> void:
	data.clear()
	data[0] = profile_data

func add_session(session_id: int, profile: Dictionary) -> void:
	if session_id == 0: return
	data[session_id] = profile

func set_profile_name(name_string: String) -> void:
	profile_data["name"] = name_string
	wrap_request_profile_update()

func set_profile_color(color: Color) -> void:
	profile_data["color"] = color
	wrap_request_profile_update()

func wrap_request_profile_update() -> void:
	if not NetworkManager.is_online:
		UIManager.update_lobby_register()
		return
	if multiplayer.is_server():
		request_profile_update(profile_data)
	else: request_profile_update.rpc_id(1, profile_data)

func get_profile_name() -> String:
	return profile_data.get("name")

func get_profile_color() -> Color:
	return profile_data.get("color")

func get_profile_kills() -> int:
	return profile_data.get("kills")

func get_profile_score() -> int:
	return profile_data.get("score")

@rpc("authority", "reliable")
func update_registry(server_data: Dictionary) -> void:
	data.clear()
	data.assign(server_data)
	UIManager.update_lobby_register()

@rpc("any_peer", "reliable")
func request_profile_update(profile: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var clean_name: String = profile.get("name", "unnamed").strip_edges()
	if clean_name.is_empty(): clean_name = "Player " + str(sender_id)
	var new_session: Dictionary = {
		"name": clean_name,
		"color": profile.get("color", Color(1.0, 1.0, 1.0, 1.0)),
		"kills": 0,
		"score": 0
	}
	data[sender_id] = new_session
	UIManager.update_lobby_register()
	update_registry.rpc(data)
