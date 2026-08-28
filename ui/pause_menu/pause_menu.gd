extends CanvasLayer

func _on_resume_button_pressed() -> void:
	MasterManager.set_pause.rpc_id(1, false)

func _on_end_game_button_pressed() -> void:
	IngameManager.request_end_ingame.rpc_id(1)

func toggle_admin_options(is_admin: bool) -> void:
	%ResumeButton.visible = is_admin
	%EndGameButton.visible = is_admin
