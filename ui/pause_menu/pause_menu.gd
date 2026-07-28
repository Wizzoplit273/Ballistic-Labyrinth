extends CanvasLayer

func _input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed("Pause"): return
	if UIManager.lobby_node.visible and UIManager.ingame_node == null: return
	visible = not visible
	get_tree().paused = not get_tree().paused

func _on_resume_button_pressed() -> void:
	UIManager.lobby_node.unfocus()
	visible = false
	get_tree().paused = false

func _on_end_game_button_pressed() -> void:
	UIManager.lobby_node.unfocus()
	visible = false
	get_tree().paused = false
	IngameManager.end_ingame()
