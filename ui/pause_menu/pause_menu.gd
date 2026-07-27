extends CanvasLayer

## determined by loaded room
var NEXT_ROUND_TIMER: Timer

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("Pause"):
		visible = not visible
		get_tree().paused = not get_tree().paused

func _on_resume_button_pressed() -> void:
	$"../Lobby".unfocus()
	visible = false
	get_tree().paused = false

func _on_end_game_button_pressed() -> void:
	$"../Lobby".unfocus()
	visible = false
	get_tree().paused = false
	$"..".end_ingame()
