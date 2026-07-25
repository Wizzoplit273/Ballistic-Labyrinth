extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const MAX_CLIENTS: int = 32
const COMPRESSION: ENetConnection.CompressionMode = ENetConnection.CompressionMode.COMPRESS_FASTLZ

var peer: ENetMultiplayerPeer

func print_console(text: String) -> void:
	print(text)

func print_error(text: String) -> void:
	push_error(text)
	printerr(text)
	print_debug()

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		print_error("NETWORK ERROR: cannot host: " + str(error))
		return
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	print_console("Server is up! Waiting for players...")

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(IP_ADDRESS, PORT)
	if error != OK: return
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)

func peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	print_console("Player connected with peer id = " + str(peer_id))

func peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	print_console("Player disconnected with peer id = " + str(peer_id))
	NetworkSessions.data.erase(peer_id)
	NetworkSessions.update_registry.rpc(NetworkSessions.data)

## called on clients
func connected_to_server() -> void:
	print_console("Successfully joined with peer id = " + str(multiplayer.get_unique_id()))
	NetworkSessions.request_profile_update.rpc_id(1, NetworkSessions.profile_data)

## called on clients
func connection_failed() -> void:
	print_error("Connection failed")

func disconnect_client(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if peer_id <= 1:
		print_error("NETWORK ERROR: can't disconnect client with id " + str(peer_id) + ": should be > 1")
		return
	var target_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not target_peer:
		print_error("NETWORK ERROR: can't disconnect client with id " + str(peer_id) + ": null peer object")
		return
	if target_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		print_error("NETWORK ERROR: can't disconnect client with id " + str(peer_id) + ": already disconnected")
		return
	print_console("Kicked peer with id " + str(peer_id))
	peer.disconnect_peer(peer_id)

func disconnect_from_server() -> void:
	if multiplayer.is_server(): return
	NetworkSessions.clear_registry()
	await get_tree().process_frame
	multiplayer.multiplayer_peer.close()
	print_console("Successfully disconnected from server")

func close_server() -> void:
	if not multiplayer.is_server(): return
	print_console("Shutting down server...")
	if multiplayer.get_peers().size() > 0:
		notify_server_shutdown.rpc()
		await get_tree().create_timer(0.1).timeout
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkSessions.clear_registry()
	print_console("Server successfully closed: local machine is no longer a server")

@rpc("authority", "reliable")
func notify_server_shutdown() -> void:
	if multiplayer.is_server(): return
	NetworkSessions.clear_registry()
	print_console("Server is closing")
