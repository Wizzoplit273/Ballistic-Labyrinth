extends CanvasLayer

@onready var NEXT_ROUND_TIMER: Timer = $"../Ingame/Timers/NextRoundDelay"

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("Pause"):
		visible = not visible
		get_tree().paused = not get_tree().paused
		if visible: NEXT_ROUND_TIMER.process_mode = Node.PROCESS_MODE_DISABLED
		else: NEXT_ROUND_TIMER.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_resume_button_pressed() -> void:
	$"../MainMenu".unfocus()
	visible = false
	get_tree().paused = false

func _on_back_to_main_menu_button_pressed() -> void:
	$"../MainMenu".unfocus()
	visible = false
	get_tree().paused = false
	$"..".main_menu()
