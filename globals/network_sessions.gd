extends Node

var data: Dictionary = {}
var profile_data: Dictionary = {}

func is_bot(session_id: int) -> bool:
	return session_id < 0

func _enter_tree() -> void:
	create_profile()

func clear_registry() -> void:
	data.clear()
	data[1] = profile_data

func create_profile() -> void:
	if data.has(1): return
	profile_data = {
		"name": "unnamed",
		"color": Color(1.0, 1.0, 1.0, 1.0),
		"kills": 0,
		"score": 0
	}
	data[1] = profile_data

func add_session(session_id: int, profile: Dictionary) -> void:
	data[session_id] = profile

func set_profile_name(name_string: String) -> void:
	profile_data["name"] = name_string
	request_profile_update.rpc_id(1, profile_data)

func set_profile_color(color: Color) -> void:
	profile_data["color"] = color
	request_profile_update.rpc_id(1, profile_data)

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
	update_registry.rpc(data)
