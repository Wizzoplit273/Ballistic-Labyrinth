extends Control

var is_blocked: bool = false

func toggle_visibility() -> void:
	%Texture.visible = not %Texture.visible

func move_window() -> void:
	if not %Texture.visible: return
	var mouse_pos: Vector2 = DisplayServer.mouse_get_position()
	$Window.position = mouse_pos - ($Window.size / 2.0)

func toggle_chat_resize() -> void:
	$Window.borderless = not $Window.borderless

func _ready() -> void:
	ChatManager.connect(&"update_local_chat_ui", update_chat)

func update_chat(new_messages: Array[Dictionary]) -> void:
	for message: Dictionary in new_messages:
		add_message(message)

func add_message(message: Dictionary) -> void:
	var readable_sid: String = SessionManager.encode_session_id(message.get("sender_sid"))
	%ChatText.text += str(message.get("timestamp")) + " "
	if message.get("channel") == "global":
		%ChatText.text += message.get("sender_name")
		%ChatText.text += "(" + readable_sid + "): "
	elif message.get("channel") == "system":
		%ChatText.text += "***: "
	%ChatText.text += message.get("text") + "\n"

func _input(event: InputEvent) -> void:
	UIManager._input(event)

func _on_chat_input_text_submitted(raw: String) -> void:
	%ChatInput.clear()
	ChatManager.send_message(raw)

func _on_chat_input_focus_entered() -> void:
	is_blocked = true

func _on_chat_input_focus_exited() -> void:
	is_blocked = false

func _on_focus_entered() -> void:
	is_blocked = false
