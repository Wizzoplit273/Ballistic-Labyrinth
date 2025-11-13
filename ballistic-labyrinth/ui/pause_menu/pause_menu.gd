extends CanvasLayer

func _input(_event: InputEvent) -> void:
	if $"..".current_level == null: return
	if Input.is_action_just_pressed("Pause"):
		visible = not visible
		get_tree().paused = not get_tree().paused

func _on_resume_button_pressed() -> void:
	$"../MainMenu".unfocus()
	visible = false
	get_tree().paused = false

func _on_back_to_main_menu_button_pressed() -> void:
	$"../MainMenu".unfocus()
	visible = false
	get_tree().paused = false
	$"..".stop_level()
