extends Node

## player skin colour(corresponds to the player texture's modulation)
var player_color: Color = Color.WHITE

func _ready() -> void:
	main_menu()

func free_room_container() -> void:
	for node: Node in $RoomContainer.get_children():
		$RoomContainer.remove_child(node)
		node.queue_free()

func toggle_main_menu(value: bool) -> void:
	$MainMenu.activate(value)
	$MenusBackground.visible = value

const ROOM_FILE: String = "res://ingame/room.tscn"
func load_room() -> void:
	var room: Node = load(ROOM_FILE).instantiate()
	$PauseMenu.NEXT_ROUND_TIMER = room.get_node("Timers/NextRoundDelay")
	$RoomContainer.add_child(room)

func play() -> void:
	free_room_container()
	toggle_main_menu(false)
	load_room()
	$RoomContainer.get_child(0).modified_ready()

func main_menu() -> void:
	free_room_container()
	toggle_main_menu(true)
