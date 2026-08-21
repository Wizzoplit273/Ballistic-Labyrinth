extends CanvasLayer

func _input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed("Pause"): return
	if UIManager.lobby_node.visible and not IngameManager.is_ingame_configured: return
	if SessionManager.data[multiplayer.get_unique_id()].get("admin") != true: return
	MasterManager.set_pause.rpc_id(1, not visible)

func _on_resume_button_pressed() -> void:
	MasterManager.set_pause.rpc_id(1, false)

func _on_end_game_button_pressed() -> void:
	IngameManager.request_end_ingame.rpc_id(1)

func toggle_admin_options(is_admin: bool) -> void:
	%ResumeButton.visible = is_admin
	%EndGameButton.visible = is_admin
