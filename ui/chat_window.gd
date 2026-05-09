extends TextureRect

func _on_chat_input_text_submitted(new_text: String) -> void:
	if new_text == "": return
	if $"..".peer == null: ## local messaging(self messaging, doesn't go to any peer)
		%ChatInput.text = ""
		%ChatNode.text += "(local): "
		var delimited_texts: PackedStringArray = new_text.split("\\")
		new_text = ""
		for delimited_text: String in delimited_texts:
			new_text += delimited_text
		%ChatNode.text += new_text + "\n"
		return
	## regular messaging
	var player_lobby_ui_instance: Control = null
	var id: int = multiplayer.get_unique_id()
	for scene: Control in %PlayerLobbyList.get_children():
		if not scene.has_node("Frame/IDLabel"):
			var ERROR: String = "CUSTOM ERROR: player lobby ui scene " + str(scene) + " doesn't have a proper ID label set"
			push_error(ERROR)
			print_debug(ERROR)
			continue
		if scene.get_node("Frame/IDLabel").text != "ID: " + str(id): continue
		player_lobby_ui_instance = scene
		break
		if player_lobby_ui_instance == null:
			const ERROR: String = "CUSTOM ERROR: selected player lobby ui scene is null for some reason"
			push_error(ERROR)
			print_debug(ERROR)
			return
	var client_name: String = player_lobby_ui_instance.get_node("Frame/NameLabel").text
	client_name = client_name.get_slice("Name: ", 1)
	%ChatInput.text = ""
	var delimited_texts: PackedStringArray = new_text.split("\\")
	new_text = ""
	for delimited_text: String in delimited_texts:
		new_text += delimited_text
	if multiplayer.is_server(): send_chat_message(id, client_name, new_text)
	else: send_chat_message.rpc_id(1, id, client_name, new_text)

@rpc("reliable", "any_peer")
func send_chat_message(id: int, given_name: String, message: String) -> void:
	var sending_message: String = "(" + str(id) + ") " + given_name + ": " + message + "\n"
	%ChatNode.text += sending_message
	if multiplayer.is_server(): rpc("send_chat_message", id, given_name, message)

@rpc("reliable", "any_peer")
func send_log_message(message: String) -> void:
	%ChatNode.text += message + "\n"
	if multiplayer.is_server(): rpc("send_log_message", message)
