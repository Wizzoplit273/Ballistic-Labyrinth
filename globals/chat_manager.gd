extends Node

var chat_history: Array[Dictionary] = []
var MAX_HISTORY: int = 100

func send_message(text: String, channel: String = "global") -> void:
	if NetworkManager.is_online and not multiplayer.is_server():
		rpc_id(1, "process_message", text, channel)
		return
	process_message(text, channel)

@rpc("authority", "reliable")
func update_chat_history(history: Array[Dictionary]) -> void:
	chat_history.clear()
	chat_history.assign(history)
	update_local_chat_ui.emit()

signal update_local_chat_ui()
@rpc("any_peer", "reliable", "call_local")
func process_message(text: String, channel: String = "global") -> void:
	if NetworkManager.is_online and not multiplayer.is_server(): return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0 and NetworkManager.is_online: sender_id = 1
	var final_text: String = text.strip_edges()
	var message: Dictionary = {
		"sender_sid": sender_id,
		"sender_name": SessionManager.data.get(sender_id).get("name"),
		"text": final_text,
		"timestamp": Time.get_time_string_from_unix_time(Time.get_unix_time_from_system()),
		"channel": channel
	}
	chat_history.append(message)
	while chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	if NetworkManager.is_online: rpc("update_chat_history", chat_history)
	update_local_chat_ui.emit()
