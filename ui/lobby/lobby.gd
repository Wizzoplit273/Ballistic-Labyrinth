extends CanvasLayer

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

func _on_start_mission_button_pressed() -> void:
	activate(false)
	IngameManager.start_ingame()

func _on_exit_game_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = true

func _on_discard_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_confirm_button_pressed() -> void:
	get_tree().quit()
