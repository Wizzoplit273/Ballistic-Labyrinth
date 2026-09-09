extends Node

const ICE_SERVERS: Array[Dictionary] = [
	{ "urls": ["stun:stun.l.google.com:19302"] },
	{ "urls": ["stun:openrelay.metered.ca:80"] },
	{ 
		"urls": ["turn:openrelay.metered.ca:80"],
		"username": "openrelayproject",
		"credential": "openrelayproject"
	},
	{ 
		"urls": ["turn:openrelay.metered.ca:443"],
		"username": "openrelayproject",
		"credential": "openrelayproject"
	}
]

const SIGNALING_PORT: int = 9080

var signaling_peer: WebSocketMultiplayerPeer
var rtc_peer: WebRTCMultiplayerPeer
var rtc_connections: Dictionary = {} # peer_id -> WebRTCPeerConnection
var url: String = "ws://localhost:" + str(SIGNALING_PORT)

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
	#print(text)
	ChatManager.process_message(text, "global", 0)
	ClientDebugManager.log_to_file("***: " + text)

func print_error(text: String) -> void:
	ChatManager.process_message(text, "shell_error", 0)
	ClientDebugManager.log_to_file("E: " + text)
	push_error(text)
	printerr(text)
	print_debug()

func master_enter_tree() -> void:
	if OS.has_feature("server") or DisplayServer.get_name() == "headless":
		is_dedicated_server = true
	if is_dedicated_server: start_server()
	else: set_local_online_status(false, false)

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

var rtc_offer_sent: bool = false
func _process(_delta: float) -> void:
	if not signaling_peer: return
	signaling_peer.poll()
	if signaling_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return
	while signaling_peer.get_available_packet_count() > 0:
		var sender_id = signaling_peer.get_packet_peer()
		var packet = signaling_peer.get_packet()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		_handle_signaling_data(sender_id, data)

func _initiate_webrtc_offer() -> void:
	ClientDebugManager.log_to_file("L: _initiate_webrtc_offer() executed")
	rtc_offer_sent = true
	if rtc_connections.has(1):
		rtc_connections[1].create_offer()

func setup_signaling_server() -> bool:
	signaling_peer = WebSocketMultiplayerPeer.new()
	var signaling_error: Error = signaling_peer.create_server(SIGNALING_PORT)
	if signaling_error != OK:
		print_error("NETWORK ERROR: cannot host signaling server: " + str(signaling_error))
		return false
	signaling_peer.peer_connected.connect(_on_signaling_peer_connected)
	signaling_peer.peer_disconnected.connect(_on_signaling_peer_disconnected)
	return true

func _on_signaling_peer_connected(id: int) -> void:
	if not is_server: return
	_send_signal(id, {"type": "id", "id": id})
	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": ICE_SERVERS })
	conn.session_description_created.connect(_on_sdp_created.bind(id))
	conn.ice_candidate_created.connect(_on_ice_created.bind(id))
	rtc_peer.add_peer(conn, id)
	rtc_connections[id] = conn

func _on_sdp_created(type: String, sdp: String, id: int) -> void:
	var conn: WebRTCPeerConnection = rtc_connections[id]
	conn.set_local_description(type, sdp)
	_send_signal(id, {"type": "sdp", "sdp_type": type, "sdp": sdp})

func _on_ice_created(media: String, index: int, ice_name: String, id: int) -> void:
	_send_signal(id, {"type": "ice", "media": media, "index": index, "name": ice_name})

func _send_signal(id: int, data: Dictionary) -> void:
	if not signaling_peer: return
	var packet = JSON.stringify(data).to_utf8_buffer()
	signaling_peer.set_target_peer(id)
	signaling_peer.put_packet(packet)

func _handle_signaling_data(id: int, data: Dictionary) -> void:
	if data.type == "id" and not is_server:
		ClientDebugManager.log_to_file("_handle_signaling_data() executed on client-side")
		_initialize_webrtc_client(int(data.id))
		return
	if not rtc_connections.has(id): return
	var conn: WebRTCPeerConnection = rtc_connections[id]
	if data.type == "sdp":
		conn.set_remote_description(data.sdp_type, data.sdp)
	elif data.type == "ice":
		conn.add_ice_candidate(data.media, data.index, data.name)

func _initialize_webrtc_client(my_id: int) -> void:
	rtc_peer = WebRTCMultiplayerPeer.new()
	var rtc_error: Error = rtc_peer.create_client(my_id)
	if rtc_error != OK:
		print_error("NETWORK ERROR: rtc client creation failed: " + str(rtc_error))
		return
	ClientDebugManager.log_to_file("_initialize_webrtc_client() success(rtc_error == OK)")
	multiplayer.set_multiplayer_peer(rtc_peer)
	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": ICE_SERVERS })
	conn.session_description_created.connect(_on_sdp_created.bind(1))
	conn.ice_candidate_created.connect(_on_ice_created.bind(1))
	rtc_peer.add_peer(conn, 1)
	rtc_connections[1] = conn
	conn.create_offer()

func _on_signaling_peer_disconnected(id: int) -> void:
	print_local("Signaling WebSocket disconnected for peer " + SessionManager.encode_session_id(id))
	#if rtc_connections.has(id):
		#var conn: WebRTCPeerConnection = rtc_connections[id]
		#if conn.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED: return
		#conn.close()
		#rtc_connections.erase(id)
	#if rtc_peer and rtc_peer.has_peer(id):
		#rtc_peer.remove_peer(id)

func setup_rtc_server() -> bool:
	rtc_peer = WebRTCMultiplayerPeer.new()
	var rtc_error: Error = rtc_peer.create_server()
	if rtc_error != OK:
		print_error("NETWORK ERROR: cannot host rtc peer: " + str(rtc_error))
		return false
	multiplayer.set_multiplayer_peer(rtc_peer)
	return true

func start_server() -> void:
	if is_online: return
	if not setup_signaling_server(): return
	if not setup_rtc_server(): return
	IngameManager.current_is_animated_generation = true
	print_local("Server is up! Waiting for players...")
	set_local_online_status(true, true)

func setup_signaling_client() -> bool:
	print_local("Trying to connect to URL = " + url)
	rtc_offer_sent = false
	signaling_peer = WebSocketMultiplayerPeer.new()
	var error: Error = signaling_peer.create_client(url)
	if error != OK:
		print_error("NETWORK ERROR: signaling connection failed: " + str(error))
		return false
	ClientDebugManager.log_to_file("L: setup_signaling_client() returns true")
	return true

func setup_rtc_client_peer() -> bool:
	rtc_peer = WebRTCMultiplayerPeer.new()
	var random_id: int = abs(randi_range(2, INT32_MAX))
	var rtc_error: Error = rtc_peer.create_client(random_id)
	if rtc_error != OK:
		print_error("NETWORK ERROR: rtc client creation failed: " + str(rtc_error))
		return false
	multiplayer.set_multiplayer_peer(rtc_peer)
	ClientDebugManager.log_to_file("L: setup_rtc_client_peer() returns true")
	return true

func setup_rtc_client_connection() -> void:
	ClientDebugManager.log_to_file("setup_rtc_client_connection() executed")
	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": ICE_SERVERS })
	conn.session_description_created.connect(_on_sdp_created.bind(1))
	conn.ice_candidate_created.connect(_on_ice_created.bind(1))
	rtc_peer.add_peer(conn, 1)
	rtc_connections[1] = conn

func start_client() -> void:
	if is_online: return
	if not setup_signaling_client(): return
	#if not setup_rtc_client_peer(): return
	#setup_rtc_client_connection()
	IngameManager.current_is_animated_generation = false
	set_local_online_status(true, false)

func peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	_close_peer_signaling(peer_id)
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Player connected with peer id = " + encoded_pid, "global", peer_id)
	MasterManager.play_server_sound(MasterManager.sounds.get_node(^"PlayerJoin"))
	if IngameManager.current_state == IngameManager.State.STOPPED:
		IngameManager.set_maze_animation_to_true.rpc_id(peer_id)
	else: UIManager.confirm_spectating.rpc_id(peer_id)

func peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	ConsoleManager.print_output("Player disconnected with peer id = " + encoded_pid, "global", peer_id)
	MasterManager.play_server_sound(MasterManager.sounds.get_node(^"PlayerLeave"))
	IngameManager.delete_player(peer_id)
	SessionManager.data.erase(peer_id)
	UIManager.update_lobby_register()
	SessionManager.update_registry.rpc(SessionManager.data)

## called on clients
func connected_to_server() -> void:
	var encoded_pid: String = SessionManager.encode_session_id(multiplayer.get_unique_id())
	print_local("Successfully joined with peer id = " + encoded_pid)
	_close_client_signaling()
	SessionManager.request_profile_update.rpc_id(1, SessionManager.profile_data)

func _close_client_signaling() -> void:
	ClientDebugManager.log_to_file("_close_client_signaling() executed by code commented out")
	#if not signaling_peer: return
	#signaling_peer.close()
	#signaling_peer = null
	#print("Signaling WebSocket closed gracefully after WebRTC connection")

func _close_peer_signaling(_peer_id: int) -> void:
	pass
	#if not signaling_peer: return
	#if signaling_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return
	#if not signaling_peer.has_peer(peer_id): return
	#signaling_peer.disconnect_peer(peer_id)

## called on clients
func connection_failed() -> void:
	print_error("Connection failed")

func disconnect_client(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	if peer_id <= 1:
		print_error("NETWORK ERROR: can't disconnect client with id " + encoded_pid + ": should be > 1")
		return
	_on_signaling_peer_disconnected(peer_id)
	if signaling_peer: signaling_peer.disconnect_peer(peer_id)
	set_local_online_status.rpc_id(peer_id, false, false)
	print_local("Kicked peer with id " + encoded_pid)

func end_signaling_and_rtc() -> void:
	if not multiplayer.is_server(): ClientDebugManager.log_to_file("end_signaling_and_rtc() executed")
	if signaling_peer:
		signaling_peer.close()
		signaling_peer = null
	if rtc_peer:
		rtc_peer.close()
		rtc_peer = null
	rtc_connections.clear()
	multiplayer.multiplayer_peer = null

func disconnect_from_server() -> void:
	if multiplayer.is_server(): return
	ClientDebugManager.log_to_file("disconnect_from_server() executed")
	SessionManager.clear_registry()
	await get_tree().process_frame
	end_signaling_and_rtc()
	IngameManager.set_current_state(IngameManager.State.STOPPED)
	set_local_online_status(false, false)
	ChatManager.process_message("Successfully disconnected from server", "global", 0)

const CLOSE_SERVER_NOTIFY_DELAY: float = 0.2
func close_server() -> void:
	if not is_online or not multiplayer.is_server(): return
	print_local("Shutting down server...")
	IngameManager.end_ingame(true)
	#await get_tree().create_timer(1.0).timeout
	if multiplayer.get_peers().size() > 0:
		notify_server_shutdown.rpc()
		await get_tree().create_timer(CLOSE_SERVER_NOTIFY_DELAY).timeout
	end_signaling_and_rtc()
	SessionManager.clear_registry()
	set_local_online_status(false, false)
	print_local("Server successfully closed: local machine is no longer a server")

@rpc("authority", "reliable")
func notify_server_shutdown() -> void:
	if multiplayer.is_server(): return
	SessionManager.clear_registry()
	set_local_online_status(false, false)
	print_local("Server is closing")
	
