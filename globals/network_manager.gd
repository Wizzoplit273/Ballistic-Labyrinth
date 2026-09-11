extends Node

const SERVER_PORT: int = 7777

var server: ENetConnection = null
var is_online: bool = false
var is_server: bool = false
var is_dedicated_server: bool = false

func set_local_online_status(value_online: bool, value_server: bool) -> void:
	is_online = value_online
	is_server = value_server
	if is_online and is_server: SessionManager.turn_local_to_online_profile()
	UIManager.toggle_admin_options(value_server)
	UIManager.update_online_status()

func print_local(text: String) -> void:
	ChatManager.process_message(text, "global", 0)

func print_error(text: String) -> void:
	ChatManager.process_message(text, "shell_error", 0)
	push_error(text)
	printerr(text)

func master_enter_tree() -> void:
	if OS.has_feature("server") or DisplayServer.get_name() == "headless":
		is_dedicated_server = true
	if is_dedicated_server: start_server()
	else: set_local_online_status(false, false)

func _process(_delta: float) -> void:
	if not is_server or not server: return
	
	# Manually poll the low-level ENet host for events (connect, disconnect, packet)
	var event: Array = server.service(0)
	if event.is_empty(): return
	
	var event_type: int = event[0]
	var peer: ENetPacketPeer = event[1]
	var _channel: int = event[2] # Will match data forwarded from your WebTransport proxy
	
	match event_type:
		ENetConnection.EVENT_CONNECT:
			_on_enet_peer_connected(peer)
		ENetConnection.EVENT_DISCONNECT:
			_on_enet_peer_disconnected(peer)
		ENetConnection.EVENT_RECEIVE:
			var packet_data: PackedByteArray = event[3]
			_on_enet_packet_received(peer, packet_data)

func start_server() -> void:
	if is_online: return
	server = ENetConnection.new()
	var error: Error = server.create_host_bound("0.0.0.0", SERVER_PORT, 32, 2)
	if error != OK:
		print_error("NETWORK ERROR: cannot host: " + str(error))
		server = null
		return
	IngameManager.current_is_animated_generation = true
	print_local("Low-level ENet Server is up! Waiting for WebTransport proxy...")
	set_local_online_status(true, true)

func _on_enet_peer_connected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_peer_id()
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Proxy tunnel established for client ID = " + encoded_pid, "global", peer_id)
	MasterManager.play_server_sound(MasterManager.sounds.get_node(^"PlayerJoin"))

func _on_enet_peer_disconnected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_peer_id()
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Client disconnected ID = " + encoded_pid, "global", peer_id)
	MasterManager.play_server_sound(MasterManager.sounds.get_node(^"PlayerLeave"))
	IngameManager.delete_player(peer_id)
	SessionManager.data.erase(peer_id)
	UIManager.update_lobby_register()

func _on_enet_packet_received(peer: ENetPacketPeer, packet_data: PackedByteArray) -> void:
	# Parse raw bytes coming from the proxy as a UTF-8 JSON string
	var json_string: String = packet_data.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print_error("JSON Parse Error: " + json.get_error_message())
		return
	
	var packet: Dictionary = json.get_data()
	handle_client_json_packet(peer.get_peer_id(), packet)

func handle_client_json_packet(peer_id: int, packet: Dictionary) -> void:
	# Route your custom JSON actions here instead of using Godot RPCs
	var action: String = packet.get("action", "")
	match action:
		"update_profile":
			SessionManager.data[peer_id] = packet.get("data", {})
			UIManager.update_lobby_register()
		_:
			print_error("Unknown action received: " + action)

func broadcast_json(packet: Dictionary) -> void:
	if not server: return
	var json_string: String = JSON.stringify(packet)
	var buffer: PackedByteArray = json_string.to_utf8_buffer()
	# Broadcast raw JSON payload to all connected proxy tunnels across channel 0
	server.broadcast(0, buffer, ENetPacketPeer.FLAG_RELIABLE)

func close_server() -> void:
	if not is_online: return
	print_local("Shutting down low-level server...")
	IngameManager.end_ingame(true)
	if server:
		server.destroy()
		server = null
	SessionManager.clear_registry()
	set_local_online_status(false, false)
	print_local("Server successfully closed")
