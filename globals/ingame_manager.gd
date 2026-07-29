extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame_node: Node = null

var is_ingame_configured: bool = false

func start_ingame() -> void:
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	create_ingame()

func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	
	add_child(ingame_node)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()
	is_ingame_configured = true

func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()
	is_ingame_configured = false

func end_ingame() -> void:
	delete_ingame()
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(true)

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()
