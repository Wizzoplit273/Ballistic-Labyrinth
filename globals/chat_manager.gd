extends Node

var chat_history: Array[Dictionary] = []
var MAX_HISTORY: int = 100

@rpc("authority", "reliable")
func send_local_message(text: String, channel: String = "global") -> void:
	if not UIManager.is_ui_configured: return
	process_message(text, channel)

func send_message(text: String, channel: String = "global") -> void:
	if NetworkManager.is_online and not multiplayer.is_server():
		rpc_id(1, "process_message", text, channel)
		return
	process_message(text, channel)

@rpc("authority", "reliable")
func update_chat_history(new_message: Dictionary) -> void:
	chat_history.append(new_message)
	while chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	var new_array: Array[Dictionary] = [new_message]
	update_local_chat_ui.emit(new_array)

signal update_local_chat_ui(messages: Array[Dictionary])
@rpc("any_peer", "reliable")
func process_message(text: String, channel: String = "global") -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var final_text: String = text.strip_edges()
	var message: Dictionary = {}
	var new_array: Array[Dictionary] = []
	if NetworkManager.is_online and not multiplayer.is_server():
		#if sender_id != 0: return
		message = {
			"sender_sid": sender_id,
			"sender_name": SessionManager.profile_data.get("name"),
			"text": final_text,
			"timestamp": Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system())),
			"channel": channel
		}
		chat_history.append(message)
		while chat_history.size() > MAX_HISTORY:
			chat_history.pop_front()
		new_array.append(message)
		update_local_chat_ui.emit(new_array)
		return
	if sender_id == 0 and NetworkManager.is_online: sender_id = 1
	if sender_id > 1: channel = "global"
	message = {
		"sender_sid": sender_id,
		"sender_name": SessionManager.data.get(sender_id).get("name"),
		"text": final_text,
		"timestamp": Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system())),
		"channel": channel
	}
	chat_history.append(message)
	while chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	if NetworkManager.is_online and multiplayer.is_server() and channel.contains("shell"):
		rpc("update_chat_history", message)
	new_array.append(message)
	update_local_chat_ui.emit(new_array)
