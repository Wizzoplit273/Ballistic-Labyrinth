extends Node

var data: Dictionary = {}
var profile_data: Dictionary = {}

func is_bot(session_id: int) -> bool:
	return session_id < 0

func turn_local_to_online_profile() -> void:
	data.clear()
	profile_data["admin"] = true
	data[multiplayer.get_unique_id()] = profile_data
	#UIManager.update_lobby_register() # happens right after exiting this scope

func master_enter_tree() -> void:
	create_local_profile()

func create_local_profile() -> void:
	if data.has(0): return
	profile_data = {
		"name": "unnamed",
		"admin": false,
		"color": Color(1.0, 1.0, 1.0, 1.0),
		"kills": 0,
		"score": 0
	}
	data[0] = profile_data

func clear_registry() -> void:
	data.clear()
	data[0] = profile_data

@rpc("authority", "reliable")
func add_session(session_id: int, profile: Dictionary) -> void:
	if session_id == 0: return
	data[session_id] = profile
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	add_session.rpc(session_id, profile)

@rpc("authority", "reliable", "call_local")
func add_bot(count: int = 1) -> void:
	if count <= 0: return
	var new_sid: int = -1
	while count > 0:
		while data.has(new_sid): new_sid -= 1
		add_session(new_sid, {
			"name": "bot " + str(abs(new_sid)),
			"admin": false,
			"color": Color(1.0, 1.0, 1.0, 1.0),
			"kills": 0,
			"score": 0,
			"personality": {}
		})
		count -= 1
	UIManager.update_lobby_register()

@rpc("authority", "reliable")
func remove_bot_sid(sid: int) -> void:
	if sid >= 0: return
	if not data.has(sid): return
	data.erase(sid)
	UIManager.update_lobby_register()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	remove_bot_sid.rpc(sid)

@rpc("authority", "reliable")
func remove_bot_count(count: int = 1) -> void:
	if count <= 0: return
	for sid: int in data.keys():
		if count <= 0: break
		if sid >= 0: continue
		data.erase(sid)
		count -= 1
	UIManager.update_lobby_register()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	remove_bot_count.rpc(count)

func set_profile_name(name_string: String) -> void:
	profile_data["name"] = name_string
	wrap_request_profile_update()

func set_profile_color(color: Color) -> void:
	profile_data["color"] = color
	wrap_request_profile_update()

func set_admin(pid: int, is_admin: bool) -> void:
	data[pid]["admin"] = is_admin
	UIManager.toggle_admin_options(is_admin)

func increment_kill(sid: int) -> void:
	if sid == 0: return
	assign_from_str(sid, "kills", str(data[sid].get("kills") + 1))

func increment_score(sid: int) -> void:
	if sid == 0: return
	assign_from_str(sid, "score", str(data[sid].get("score") + 1))

## alpha channel isn't used, so every color is opaque by default
func color_to_string(color: Color) -> String:
	var result: String = "\"" + str(color.r) + " " + str(color.g) + " " + str(color.b) + "\""
	return result

func string_to_color(string: String) -> Color:
	string = string.replace("\"", "")
	var split: PackedStringArray = string.split(" ", false)
	if split.size() <= 2: return Color.WHITE
	var floats: PackedFloat32Array = []
	for i: int in range(0, 3):
		floats.append(float(split[i]))
		if floats[i] < 0: floats[i] = 0.0
		if floats[i] > 1.0: floats[i] = 1.0
	var color: Color = Color(floats[0], floats[1], floats[2])
	return color

@rpc("authority", "reliable")
func assign_from_str(sid: int, attribute: String, value: String) -> void:
	if sid == 0 and NetworkManager.is_online: sid = multiplayer.get_unique_id()
	if not data.has(sid): return
	if not data[sid].has(attribute): return
	if attribute == "color":
		data[sid][attribute] = string_to_color(value)
	else:
		if typeof(data[sid][attribute]) == TYPE_BOOL:
			if attribute == "admin": # stricter console set for admin permission
				if value == "true": set_admin(sid, true)
				else: set_admin(sid, false)
			else:
				if value == "false" or value == "0": data[sid][attribute] = false
				else: data[sid][attribute] = true
		if typeof(data[sid][attribute]) == TYPE_INT: data[sid][attribute] = int(value)
		if typeof(data[sid][attribute]) == TYPE_FLOAT: data[sid][attribute] = float(value)
		if typeof(data[sid][attribute]) == TYPE_STRING: data[sid][attribute] = value
		if sid == multiplayer.get_unique_id(): profile_data[attribute] = data[sid][attribute]
	UIManager.update_lobby_register()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	assign_from_str.rpc(sid, attribute, value)

@rpc("authority", "reliable")
func set_bot_trait_from_str(sid: int, attribute: String, value: String) -> void:
	if sid >= 0: return
	if not data.has(sid): return
	if not data[sid]["personality"].has(attribute): return
	if typeof(data[sid]["personality"][attribute]) == TYPE_BOOL:
		if value == "false" or value == "0": data[sid]["personality"][attribute] = false
		else: data[sid]["personality"][attribute] = true
	if typeof(data[sid]["personality"][attribute]) == TYPE_INT:
		data[sid]["personality"][attribute] = int(value)
	if typeof(data[sid]["personality"][attribute]) == TYPE_FLOAT:
		data[sid]["personality"][attribute] = float(value)
	if typeof(data[sid]["personality"][attribute]) == TYPE_STRING:
		data[sid]["personality"][attribute] = value
	UIManager.update_lobby_register()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	set_bot_trait_from_str.rpc(sid, attribute, value)

func add_crate(count: int, type: String) -> void:
	if not multiplayer.is_server(): return
	if type == "bulk" and count <= 0: return
	if IngameManager.ingame == null: return
	if not IngameManager.is_ingame_configured: return
	if type == "bulk":
		for i: int in range(0, count): IngameManager.ingame._on_crate_spawn_delay_timeout("bulk")
		return
	IngameManager.ingame._on_crate_spawn_delay_timeout(type)

func remove_crate(count: int) -> void:
	if not multiplayer.is_server(): return
	if count <= 0: return
	if IngameManager.ingame == null: return
	if not IngameManager.is_ingame_configured: return
	var crates_node: Node = IngameManager.ingame.get_node(^"Crates")
	var current_count: int = crates_node.get_child_count()
	if current_count < count: count = current_count
	while count > 0:
		crates_node.get_child(0).free()
		count -= 1

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

func get_profile_admin() -> bool:
	return profile_data.get("admin")

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
		"admin": profile.get("admin", false),
		"color": profile.get("color", Color(1.0, 1.0, 1.0, 1.0)),
		"kills": 0,
		"score": 0
	}
	data[sender_id] = new_session
	UIManager.update_lobby_register()
	update_registry.rpc(data)

const ENCODE_ALPHABET: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const ENCODE_BOT_PREFIX: String = "ai#"

func encode_session_id(session_id: int) -> String:
	if session_id == 0: return "0"
	var is_negative: bool = session_id < 0
	var num: int = abs(session_id)
	var result: String = ""
	var ENCODE_BASE: int = ENCODE_ALPHABET.length()
	while num > 0:
		var remainder: int = num % ENCODE_BASE
		result = ENCODE_ALPHABET[remainder] + result
		num /= ENCODE_BASE
	return ENCODE_BOT_PREFIX + result if is_negative else result

func decode_session_id(encoded_id: String) -> int:
	if encoded_id.is_empty(): return 0
	var is_negative: bool = encoded_id.begins_with(ENCODE_BOT_PREFIX)
	if is_negative: encoded_id = encoded_id.substr(ENCODE_BOT_PREFIX.length())
	var result: int = 0
	var ENCODE_BASE: int = ENCODE_ALPHABET.length()
	for i: int in range(encoded_id.length()):
		var character: String = encoded_id[i]
		var value: int = ENCODE_ALPHABET.find(character)
		if value == -1:
			push_error("CUSTOM ERROR in chat_manager.gd: Invalid character in encode string base")
			return 0
		result = result * ENCODE_BASE + value
	return -result if is_negative else result
