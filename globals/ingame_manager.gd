extends Node

## updated once by origin node, remains constant
var scene_root: Node = null

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame_node: Node = null

func create_ingame() -> void:
	if ingame_node != null: return
	ingame_node = load(INGAME_FILE).instantiate()
	
	add_child(ingame_node)
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	ingame_node.connect("_on_next_round", _on_ingame_next_round)
	ingame_node.modified_ready()

func delete_ingame() -> void:
	if ingame_node == null: return
	ingame_node.queue_free()

func end_ingame() -> void:
	delete_ingame()
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(true)

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame()
