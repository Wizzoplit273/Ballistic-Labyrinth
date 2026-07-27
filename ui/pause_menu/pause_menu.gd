extends CanvasLayer

func _input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed("Pause"): return
	if get_parent().lobby_node.visible and get_parent().ingame_node == null: return
	visible = not visible
	get_tree().paused = not get_tree().paused

func _on_resume_button_pressed() -> void:
	get_parent().lobby_node.unfocus()
	visible = false
	get_tree().paused = false

func _on_end_game_button_pressed() -> void:
	get_parent().lobby_node.unfocus()
	visible = false
	get_tree().paused = false
	get_parent().end_ingame()
