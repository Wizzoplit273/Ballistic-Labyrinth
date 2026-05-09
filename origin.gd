extends Node

## those variables may be changed by the player in the settings menu
## maze size(width first, then height)
var min_maze_size: Vector2i = Vector2i(6, 6)
var max_maze_size: Vector2i = Vector2i(16, 16)
## random wall remove(after generating internal visual walls)
var wall_remove_interval: Vector2i = Vector2i(0, 5)
## enemy count
var enemy_count_interval: Vector2i = Vector2i(1, 3)
## friendly fire for enemies(i.e. enemies can kill themselves, but not necessarily individually)
var enemy_friendly_fire: bool = true

var player_score: int = 0
var enemy_score: int = 0

func _ready() -> void:
	$MainMenu.activate(true)

var DEBUG_is_checking_maze: bool = false
var DEBUG_is_showing_dodging: bool = false

func _process(_delta: float) -> void:
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Toggle_Maze_Generation"):
		DEBUG_is_checking_maze = not DEBUG_is_checking_maze
		if current_level != null: current_level.DEBUG_is_checking_maze = DEBUG_is_checking_maze
		$DEBUG_Screen/Frame/DEBUG_MazeCheck.visible = DEBUG_is_checking_maze
		if DEBUG_is_checking_maze:
			push_warning("DEBUG_Toggle_Maze_Generation is now ON")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now ON")
		else:
			push_warning("DEBUG_Toggle_Maze_Generation is now OFF")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now OFF")
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Show_Dodging"):
		DEBUG_is_showing_dodging = not DEBUG_is_showing_dodging
		if current_level != null: current_level.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
		$DEBUG_Screen/Frame/DEBUG_DodgeCheck.visible = DEBUG_is_showing_dodging
		if DEBUG_is_showing_dodging:
			print("\t\t\tDEBUG_Show_Dodging is now ON")
		else:
			print("\t\t\tDEBUG_Show_Dodging is now OFF")

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
	current_level.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
	current_level.connect("next_round", next_round)
	current_level.min_maze_size = min_maze_size
	current_level.max_maze_size = max_maze_size
	current_level.wall_remove_interval = wall_remove_interval
	current_level.enemy_count_interval = enemy_count_interval
	current_level.enemy_friendly_fire = enemy_friendly_fire
	current_level.player_score = player_score
	current_level.enemy_score = enemy_score
	$CurrentLevelContainer.add_child(current_level)
	current_level.modified_ready()

func next_round(player_increment: int, enemy_increment: int) -> void:
	player_score = player_increment
	enemy_score = enemy_increment
	play_level(0)
