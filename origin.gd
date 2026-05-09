extends Node

func _ready() -> void:
	$MainMenu.activate(true)

var DEBUG_is_checking_maze: bool = false
func _process(_delta: float) -> void:
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Toggle_Maze_Generation"):
		DEBUG_is_checking_maze = not DEBUG_is_checking_maze
		if current_level != null: current_level.DEBUG_is_checking_maze = DEBUG_is_checking_maze
		$DEBUG_MazeCheck.visible = DEBUG_is_checking_maze
		if DEBUG_is_checking_maze:
			push_warning("DEBUG_Toggle_Maze_Generation is now ON")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now ON")
		else:
			push_warning("DEBUG_Toggle_Maze_Generation is now OFF")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now OFF")

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
	current_level.DEBUG_is_checking_maze = DEBUG_is_checking_maze
	$CurrentLevelContainer.add_child(current_level)
