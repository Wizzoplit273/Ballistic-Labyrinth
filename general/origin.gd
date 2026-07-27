extends Node

var lobby_node: Control = null
var ingame_node: Node = null

func _ready() -> void:
	create_lobby()
	lobby_node.activate(true)

const LOBBY_FILE: String = "res://ui/lobby/lobby.tscn"
func create_lobby() -> void:
	if lobby_node != null: return
	lobby_node = load(LOBBY_FILE).instantiate()
	add_child(lobby_node)

const INGAME_FILE: String = "res://ingame/ingame.tscn"
func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	$PauseMenu.NEXT_ROUND_TIMER = ingame_node.get_node("Timers/NextRoundDelay")
	
	add_child(ingame_node)
	if lobby_node != null: lobby_node.activate(false)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()

func end_ingame() -> void:
	delete_ingame()
	lobby_node.activate(true)

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()

func delete_lobby() -> void:
	if lobby_node == null: return
	lobby_node.queue_free()

func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()
