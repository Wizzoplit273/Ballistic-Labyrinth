extends Control

func unfocus() -> void:
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	%VersionLabel.text = "Version " + ProjectSettings.get_setting("application/config/version")

func activate(value: bool) -> void:
	unfocus()
	visible = value

var is_on_exiting_game: bool = false
func activate_confirm_dialog(is_exiting_game: bool) -> void:
	is_on_exiting_game = is_exiting_game
	$ExitConfirmDialog.visible = true
	%ExitConfirmDialogTitle.text = "Are you sure you want to "
	if is_exiting_game: %ExitConfirmDialogTitle.text += "quit the game?"
	else: %ExitConfirmDialogTitle.text += "leave this room?"
	if multiplayer.is_server(): %ExitConfirmDialogTitle.text += " Exiting as host will close the room."

func _on_start_mission_button_pressed() -> void:
	$"..".play_level.rpc()

func _on_exit_room_button_pressed() -> void:
	unfocus()
	activate_confirm_dialog(false)

func _on_exit_game_button_pressed() -> void:
	unfocus()
	activate_confirm_dialog(true)

func _on_discard_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_confirm_button_pressed() -> void:
	if multiplayer.is_server(): $"..".remove_server()
	else: $"..".disconnect_from_server()
	if is_on_exiting_game: get_tree().quit()
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_settings_button_pressed() -> void:
	unfocus()
	activate(false)
	$"../SettingsMenu".visible = true

func _on_host_button_pressed() -> void:
	$"..".initialize_server()

func _on_join_button_pressed() -> void:
	$"..".initialize_client()

func _on_player_color_picker_color_changed(color: Color) -> void:
	$"..".player_color = color
	%PlayerColorTest.modulate = color
	if $"..".peer == null: return
	if multiplayer.is_server():
		$"..".update_player_information(1, false, "", color, -1, -1, -1)
		return
	$"..".update_player_information.rpc_id(1, multiplayer.get_unique_id(), false, "", color, -1, -1, -1)

const MAX_NAME_LENGTH: int = 50
func _on_player_name_edit_text_changed(new_text: String) -> void:
	if new_text.length() > MAX_NAME_LENGTH: return
	$"..".peer_username = new_text
	if $"..".peer == null: return
	if multiplayer.is_server():
		$"..".update_player_information(1, false, new_text, Color.TRANSPARENT, -1, -1, -1)
		return
	$"..".update_player_information.rpc_id(1, multiplayer.get_unique_id(), false, new_text, Color.TRANSPARENT, -1, -1, -1)

func _on_add_bot_button_pressed() -> void:
	$"..".create_bot()
