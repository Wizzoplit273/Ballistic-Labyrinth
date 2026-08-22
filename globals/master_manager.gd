extends Node

### $$$ PROBLEMS TO FIX
### when host changes invincibility using shift+i ingame, it shows message to intended staff,
### but when a client admin does the same, it shows a console message to every non-admin and
### host doesn't get message from "admin" channel

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

@rpc("any_peer", "reliable", "call_local")
func set_pause(is_paused: bool) -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server():
		if pid != 1: return
		get_tree().paused = is_paused
		if not UIManager.is_ui_configured: return
		UIManager.lobby_node.unfocus()
		var is_admin: bool = SessionManager.data[multiplayer.get_unique_id()].get("admin") == true
		UIManager.pause_menu_node.toggle_admin_options(is_admin)
		UIManager.pause_menu_node.visible = is_paused
		return
	if pid != 0 and SessionManager.data[pid].get("admin") != true: return
	get_tree().paused = is_paused
	if UIManager.is_ui_configured:
		UIManager.lobby_node.unfocus()
		UIManager.pause_menu_node.visible = is_paused
	for send: int in multiplayer.get_peers():
		if send <= 1: return
		set_pause.rpc_id(send, is_paused)
