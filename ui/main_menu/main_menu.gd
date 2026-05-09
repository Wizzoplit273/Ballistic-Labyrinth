extends Control

func _ready() -> void:
	$Frame/Version.text = "Version " + ProjectSettings.get_setting("application/config/version")

func activate(value: bool) -> void:
	unfocus()
	visible = value

func unfocus() -> void:
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	focus_mode = Control.FOCUS_NONE

func _on_start_mission_button_pressed() -> void:
	activate(false)
	$"..".play()

func _on_exit_game_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = true

func _on_discard_button_pressed() -> void:
	unfocus()
	$ExitConfirmDialog.visible = false

func _on_confirm_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	unfocus()
	activate(false)
	$"../SettingsMenu".visible = true
