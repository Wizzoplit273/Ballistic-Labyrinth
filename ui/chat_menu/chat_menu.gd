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

const NO_TIMESTAMP_CHANNELS: PackedStringArray = ["shell_input", "shell_error", "shell_output"]
func add_message(message: Dictionary) -> void:
	var readable_sid: String = SessionManager.encode_session_id(message.get("sender_sid"))
	if not NetworkManager.is_online: readable_sid = "#OFFLINE"
	if not message.get("channel") in NO_TIMESTAMP_CHANNELS:
		%ChatText.text += str(message.get("timestamp")) + " "
	if message.get("channel") == "peer":
		%ChatText.text += message.get("sender_name")
		%ChatText.text += "(" + readable_sid + "): "
	elif message.get("channel") == "shell_input":
		%ChatText.text += ":: "
	elif message.get("channel") == "shell_output":
		%ChatText.text += "/: "
	elif message.get("channel") == "shell_error":
		%ChatText.text += "E: "
	elif message.get("channel") == "admin":
		%ChatText.text += "ADMIN: "
	elif message.get("channel") == "target":
		%ChatText.text += "!!!: "
	elif message.get("channel") == "global":
		%ChatText.text += "***: "
	%ChatText.text += message.get("text") + "\n"

func _input(event: InputEvent) -> void:
	UIManager._input(event)

func _on_chat_input_text_submitted(raw: String) -> void:
	%ChatInput.clear()
	if raw.begins_with("/"): ConsoleManager.execute_raw_string(raw)
	else: ChatManager.send_message(raw, "peer", 0)

func _on_chat_input_focus_entered() -> void:
	is_blocked = true

func _on_chat_input_focus_exited() -> void:
	is_blocked = false

func _on_focus_entered() -> void:
	is_blocked = false

func set_font_size(value: int) -> void:
	%ChatText.add_theme_font_size_override(&"normal_font_size", value)
