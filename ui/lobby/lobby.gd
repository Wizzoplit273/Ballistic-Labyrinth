extends CanvasLayer

const LOBBY_WIDGET_FILE: String = "res://ui/lobby/lobby_widget.tscn"

const EXIT_SERVER_LABEL: String = "Leave Server"
const EXIT_GAME_LABEL: String = "Exit Game"
const CLOSE_SERVER_LABEL: String = "Close Server"
const EXIT_SERVER_CONFIRM: String = "Are you sure you want to leave the server?"
const EXIT_GAME_CONFIRM: String = "Are you sure you want to exit the game?"
const CLOSE_SERVER_CONFIRM: String = "Are you sure you want to close this server?"

func toggle_spectate_window(value: bool) -> void:
	if value == false:
		$SpectateWindow.visible = false
		return
	$SpectateWindow/Animation.play(&"spectate_window")

func update_lobby_register() -> void:
	if not NetworkManager.is_online:
		for lobby_widget: Node in %SessionsList.get_children():
			lobby_widget.queue_free()
		return
	var sid_ui: int
	var temp_registry: Dictionary = SessionManager.data.duplicate(true)
	for lobby_widget: Node in %SessionsList.get_children():
		sid_ui = lobby_widget.get_session_id()
		if sid_ui == 0:
			lobby_widget.queue_free()
			continue
		if temp_registry.has(sid_ui):
			lobby_widget.update(sid_ui)
			temp_registry.erase(sid_ui)
		else: lobby_widget.queue_free()
	for profile_key: int in temp_registry.keys():
		create_lobby_widget(profile_key)

func create_lobby_widget(profile_key: int) -> void:
	if profile_key == 0 and NetworkManager.is_online: return
	var lobby_widget: Control = load(LOBBY_WIDGET_FILE).instantiate()
	lobby_widget.update(profile_key)
	%SessionsList.add_child(lobby_widget)

func update_online_status() -> void:
	if not NetworkManager.is_online:
		%LeaveGameButton.text = EXIT_GAME_LABEL
		%ConfirmLeaveGameTitle.text = EXIT_GAME_CONFIRM
		update_lobby_register()
	elif not NetworkManager.is_server:
		%LeaveGameButton.text = EXIT_SERVER_LABEL
		%ConfirmLeaveGameTitle.text = EXIT_SERVER_CONFIRM
	else:
		%LeaveGameButton.text = CLOSE_SERVER_LABEL
		%ConfirmLeaveGameTitle.text = CLOSE_SERVER_CONFIRM
		oneshot_update_lobby_register()

func oneshot_update_lobby_register() -> void:
	if NetworkManager.is_online and multiplayer.is_server():
		if %SessionsList.get_child_count() == 0:
			create_lobby_widget(1)
			return
		%SessionsList.get_child(0).update(1)
		return

func write_version_text() -> void:
	$Frame/Version.text = "Version " + ProjectSettings.get_setting("application/config/version")

func activate(value: bool) -> void:
	unfocus()
	visible = value
	$SpectateWindow.visible = false
	if IngameManager.current_state != IngameManager.State.STOPPED: return
	if value:
		$Soundtrack.play()
	else: $Soundtrack.stop()

func unfocus() -> void:
	$Background.focus_mode = Control.FOCUS_ALL
	$Background.grab_focus()
	$Background.focus_mode = Control.FOCUS_NONE

func _on_confirm_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false
	if not NetworkManager.is_online:
		get_tree().quit()
	elif not multiplayer.is_server():
		NetworkManager.disconnect_from_server()
	else:
		NetworkManager.close_server()

func _on_discard_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_join_game_button_pressed() -> void:
	NetworkManager.start_client()

func _on_exit_game_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = true

func _on_username_edit_text_submitted(new_text: String) -> void:
	var username: String = new_text.strip_edges()
	%UsernameEdit.text = username
	SessionManager.set_profile_name(username)

func _on_player_color_picker_color_changed(color: Color) -> void:
	%PlayerColorTest.modulate = color
	SessionManager.set_profile_color(color)
