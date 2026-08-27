extends Node

const PORT: int = 42069
const MAX_CLIENTS: int = 32
const COMPRESSION: ENetConnection.CompressionMode = ENetConnection.CompressionMode.COMPRESS_FASTLZ

var peer: ENetMultiplayerPeer
var ip_address: String = "localhost"

var is_online: bool = false
var is_server: bool = false

func set_local_online_status(value_online: bool, value_server: bool) -> void:
	is_online = value_online
	is_server = value_server
	if is_online and is_server: SessionManager.turn_local_to_online_profile()
	UIManager.toggle_admin_options(value_server)
	UIManager.update_online_status()

func print_local(text: String) -> void:
	print(text)
	if not UIManager.is_ui_configured: return
	ChatManager.process_message(text, "global", 0)

func print_error(text: String) -> void:
	push_error(text)
	printerr(text)
	print_debug()

func master_enter_tree() -> void:
	set_local_online_status(false, false)

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

func start_server() -> void:
	if is_online: return
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		print_error("NETWORK ERROR: cannot host: " + str(error))
		return
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	print_local("Server is up! Waiting for players...")
	set_local_online_status(true, true)

func start_client(ip: String) -> void:
	if is_online: return
	print_local("Trying to connect to ip = " + ip)
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip, PORT)
	if error != OK: return
	ip_address = ip
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	set_local_online_status(true, false)

func peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Player connected with peer id = " + encoded_pid, "global", peer_id)
	if not IngameManager.is_ingame_finished and IngameManager.is_ingame_configured:
		UIManager.confirm_spectating.rpc_id(peer_id)

func peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Player disconnected with peer id = " + encoded_pid, "global", peer_id)
	SessionManager.data.erase(peer_id)
	UIManager.update_lobby_register()
	SessionManager.update_registry.rpc(SessionManager.data)

## called on clients
func connected_to_server() -> void:
	var encoded_pid: String = SessionManager.encode_session_id(multiplayer.get_unique_id())
	print_local("Successfully joined with peer id = " + encoded_pid)
	SessionManager.request_profile_update.rpc_id(1, SessionManager.profile_data)

## called on clients
func connection_failed() -> void:
	print_error("Connection failed")

func disconnect_client(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	if peer_id <= 1:
		print_error("NETWORK ERROR: can't disconnect client with id " + encoded_pid + ": should be > 1")
		return
	var target_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not target_peer:
		print_error("NETWORK ERROR: can't disconnect client with id " + encoded_pid + ": null peer object")
		return
	if target_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		print_error("NETWORK ERROR: can't disconnect client with id " + encoded_pid + ": already disconnected")
		return
	set_local_online_status.rpc_id(peer_id, false, false)
	peer.disconnect_peer(peer_id)
	print_local("Kicked peer with id " + encoded_pid)

func disconnect_from_server() -> void:
	if multiplayer.is_server(): return
	SessionManager.clear_registry()
	await get_tree().process_frame
	multiplayer.multiplayer_peer.close()
	set_local_online_status(false, false)
	ChatManager.process_message("Successfully disconnected from server", "global", 0)

func close_server() -> void:
	if not is_online: return
	if not multiplayer.is_server(): return
	print_local("Shutting down server...")
	if multiplayer.get_peers().size() > 0:
		notify_server_shutdown.rpc()
		await get_tree().create_timer(0.1).timeout
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	SessionManager.clear_registry()
	set_local_online_status(false, false)
	print_local("Server successfully closed: local machine is no longer a server")

@rpc("authority", "reliable")
func notify_server_shutdown() -> void:
	if multiplayer.is_server(): return
	SessionManager.clear_registry()
	set_local_online_status(false, false)
	print_local("Server is closing")
