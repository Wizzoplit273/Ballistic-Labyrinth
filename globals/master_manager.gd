extends Node

func _enter_tree() -> void:
	SessionManager.master_enter_tree()
	UIManager.master_enter_tree()
	NetworkManager.master_enter_tree()
