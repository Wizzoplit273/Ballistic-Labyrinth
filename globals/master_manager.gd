extends Node

func _enter_tree() -> void:
	SessionManager.master_enter_tree()
	UIManager.master_enter_tree()
	NetworkManager.master_enter_tree()

func play_server_sound(player: Node, pid: int = 0) -> void:
	if not multiplayer.is_server(): return
	if pid < 0: return
	if pid == 0: receive_server_sound.rpc(player.get_path())
	else: receive_server_sound.rpc_id(pid, player.get_path())

@rpc("authority", "unreliable", "call_local")
func receive_server_sound(player_path: NodePath) -> void:
	var player = get_node_or_null(player_path)
	if not player:
		push_error("CUSTOM ERROR: can't play server sound: null audio player path")
		return
	if player.has_method("play"): player.play()
