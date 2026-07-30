extends CanvasLayer

const EXIT_SERVER_LABEL: String = "Leave Server"
const EXIT_GAME_LABEL: String = "Exit Game"
const CLOSE_SERVER_LABEL: String = "Close Server"
const EXIT_SERVER_CONFIRM: String = "Are you sure you want to leave the server?"
const EXIT_GAME_CONFIRM: String = "Are you sure you want to exit the game?"
const CLOSE_SERVER_CONFIRM: String = "Are you sure you want to close this server?"

func update_online_status() -> void:
	if not NetworkManager.is_online:
		%LeaveGameButton.text = EXIT_GAME_LABEL
		%ConfirmLeaveGameTitle.text = EXIT_GAME_CONFIRM
	elif not NetworkManager.is_server:
		%LeaveGameButton.text = EXIT_SERVER_LABEL
		%ConfirmLeaveGameTitle.text = EXIT_SERVER_CONFIRM
	else:
		%LeaveGameButton.text = CLOSE_SERVER_LABEL
		%ConfirmLeaveGameTitle.text = CLOSE_SERVER_CONFIRM

func _ready() -> void:
	$Frame/Version.text = "Version " + ProjectSettings.get_setting("application/config/version")

func _input(input: InputEvent) -> void:
	if not IngameManager.is_ingame_configured: return
	if not input.is_action_pressed(&"ToggleLobby"): return
	activate(not visible)
	
func activate(value: bool) -> void:
	unfocus()
	visible = value
	if IngameManager.is_ingame_configured: return
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
	elif not NetworkManager.is_server:
		NetworkManager.disconnect_from_server()
	else:
		NetworkManager.close_server()

func _on_discard_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_join_game_button_pressed() -> void:
	var ip_address: String = %IPEdit.text.strip_edges()
	NetworkManager.start_client(ip_address)

func _on_exit_game_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = true

func _on_host_button_pressed() -> void:
	NetworkManager.start_server()

func _on_start_game_button_pressed() -> void:
	pass
	#activate(false)
	#IngameManager.start_ingame()
