extends Node

func _ready() -> void:
	$MainMenu.activate(true)

func stop_level() -> void:
	play_level(-1)

var current_level: Node = null
var unlocked_level_id: int = 0
var current_level_id: int = unlocked_level_id
const LEVEL_FILE_PREFIX: String = "res://ingame/levels/mission_levels/level_"
func play_level(id: int) -> void:
	if id == -1:
		$MainMenu.activate(true)
		if $CurrentLevelContainer.get_child_count() > 0 and current_level != null:
			current_level.queue_free()
		return
	current_level_id = id
	if id > unlocked_level_id: unlocked_level_id = id
	if $CurrentLevelContainer.get_child_count() > 0 and current_level != null:
		current_level.queue_free()
	current_level = load(LEVEL_FILE_PREFIX + str(id + 1) + ".tscn").instantiate()
	$CurrentLevelContainer.add_child(current_level)
