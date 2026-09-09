extends Node

const CLOSE_SERVER_NOTIFY_DELAY: float = 0.2

const ICE_SERVERS: Array[Dictionary] = [
	{ "urls": ["stun:stun.l.google.com:19302"] }
]
const SIGNALING_PORT: int = 9080

var my_rtc_id: int = 0
var signaling_peer: WebSocketPeer
var rtc_peer: WebRTCMultiplayerPeer
var rtc_connections: Dictionary = {} # peer_id -> WebRTCPeerConnection
var url: String = "ws://localhost:" + str(SIGNALING_PORT)
#var rtc_offer_sent: bool = false

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
		is_server = true
	if is_dedicated_server: start_server()
	else: set_local_online_status(false, false)

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

func _process(_delta: float) -> void:
	if signaling_peer and signaling_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		signaling_peer.poll()
		if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			while signaling_peer.get_available_packet_count() > 0:
				var packet := signaling_peer.get_packet()
				handle_signaling_message(packet.get_string_from_utf8())
	if rtc_peer: rtc_peer.poll()

func start_server() -> void:
	start_connection()

func start_client() -> void:
	start_connection()

func start_connection() -> void:
	if is_online: return
	end_signaling_and_rtc()
	signaling_peer = WebSocketPeer.new()
	rtc_peer = WebRTCMultiplayerPeer.new()
	var err := signaling_peer.connect_to_url(url)
	if err == OK: return
	print_error("Failed to connect with WebSocket: " + str(err))

func setup_rtc_peer(peer_id: int) -> WebRTCPeerConnection:
	if rtc_connections.has(peer_id): return rtc_connections[peer_id]
	var peer := WebRTCPeerConnection.new()
	peer.initialize({"iceServers": ICE_SERVERS})
	peer.session_description_created.connect(_on_session_description_created.bind(peer_id))
	peer.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_id))
	rtc_peer.add_peer(peer, peer_id)
	rtc_connections[peer_id] = peer
	return peer

func destroy_rtc_peer(peer_id: int) -> void:
	if not rtc_connections.has(peer_id): return
	rtc_connections[peer_id].close()
	rtc_connections.erase(peer_id)
	if not rtc_peer: return
	if not rtc_peer.has_peer(peer_id): return
	rtc_peer.remove_peer(peer_id)

func server_setup_success() -> void:
	if not is_server: return
	IngameManager.current_is_animated_generation = true
	print_local("Server is up! Waiting for players...")
	set_local_online_status(true, true)

func client_setup_success() -> void:
	if is_server: return
	IngameManager.current_is_animated_generation = false
	set_local_online_status(true, false)
	SessionManager.request_profile_update.rpc_id(1, SessionManager.profile_data)

## called on clients
func connected_to_server() -> void:
	var encoded_pid: String = SessionManager.encode_session_id(multiplayer.get_unique_id())
	print_local("Successfully joined with peer id = " + encoded_pid)

## called on clients
func connection_failed() -> void:
	print_error("Connection failed")

func handle_signaling_message(message: String) -> void:
	var json := JSON.new()
	if json.parse(message) != OK: return
	var data: Dictionary = json.data
	var type: String = data.get("type", "")
	var sender_id: int = data.get("sender_id", 0)
	if type == "id":
		if is_server:
			my_rtc_id = 1
			var error: Error = rtc_peer.create_server()
			if error != OK:
				print_error("NETWORK ERROR: webrtc server creation failed: " + str(error))
				end_signaling_and_rtc()
				set_local_online_status(false, false)
				return
			server_setup_success()
		else:
			my_rtc_id = data.get("id", 0)
			var error: Error = rtc_peer.create_client(my_rtc_id)
			if error != OK:
				print_error("NETWORK ERROR: webrtc client creation failed: " + str(error))
				end_signaling_and_rtc()
				set_local_online_status(false, false)
				return
			client_setup_success()
		multiplayer.multiplayer_peer = rtc_peer
		return
	if type == "user_connected":
		var new_peer_id: int = data.get("id", 0)
		if is_server:
			var peer := setup_rtc_peer(new_peer_id)
			peer.create_offer()
		elif (not is_server) and new_peer_id == 1:
			setup_rtc_peer(1)
		return
	if type == "user_disconnected":
		destroy_rtc_peer(data.get("id", 0))
		return
	if type == "offer":
		var peer := setup_rtc_peer(sender_id)
		peer.set_remote_description("offer", data.get("sdp", ""))
		return
	if type == "answer":
		if not rtc_connections.has(sender_id): return
		rtc_connections[sender_id].set_remote_description("answer", data.get("sdp", ""))
		return
	if type == "candidate":
		if not rtc_connections.has(sender_id): return
		rtc_connections[sender_id].add_ice_candidate(data.get("mid", ""), data.get("index", 0), data.get("sdp", ""))
		return

func _on_session_description_created(type: String, sdp: String, target_id: int) -> void:
	rtc_connections[target_id].set_local_description(type, sdp)
	_send_signal({
		"type": type,
		"target_id": target_id,
		"sender_id": my_rtc_id,
		"sdp": sdp
	})

func _on_ice_candidate_created(mid: String, index: int, sdp: String, target_id: int) -> void:
	_send_signal({
		"type": "candidate",
		"target_id": target_id,
		"sender_id": my_rtc_id,
		"mid": mid,
		"index": index,
		"sdp": sdp
	})

func _send_signal(dict: Dictionary) -> void:
	if not signaling_peer: return
	if signaling_peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	signaling_peer.send_text(JSON.stringify(dict))

func peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server(): return
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

func disconnect_client(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var encoded_pid: String = SessionManager.encode_session_id(peer_id)
	if peer_id <= 1:
		print_error("NETWORK ERROR: can't disconnect client with id " + encoded_pid + ": should be > 1")
		return
	set_local_online_status.rpc_id(peer_id, false, false)
	destroy_rtc_peer(peer_id)
	if multiplayer.multiplayer_peer: 
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	print_local("Kicked peer with id " + encoded_pid)

func end_signaling_and_rtc() -> void:
	if not multiplayer.is_server(): ClientDebugManager.log_to_file("end_signaling_and_rtc() executed")
	for peer_id: int in rtc_connections.keys():
		destroy_rtc_peer(peer_id)
	if rtc_peer:
		rtc_peer.close()
		rtc_peer = null
	if signaling_peer:
		signaling_peer.close()
		signaling_peer = null
	multiplayer.multiplayer_peer = null
	my_rtc_id = 0

func disconnect_from_server() -> void:
	if multiplayer.is_server(): return
	ClientDebugManager.log_to_file("disconnect_from_server() executed")
	end_signaling_and_rtc()
	SessionManager.clear_registry()
	IngameManager.set_current_state(IngameManager.State.STOPPED)
	set_local_online_status(false, false)
	ChatManager.process_message("Successfully disconnected from server", "global", 0)

func close_server() -> void:
	if not is_online or not multiplayer.is_server(): return
	print_local("Shutting down server...")
	IngameManager.end_ingame(true)
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
	end_signaling_and_rtc()
	SessionManager.clear_registry()
	IngameManager.set_current_state(IngameManager.State.STOPPED)
	set_local_online_status(false, false)
	print_local("Server is closing")

## UNCHANGED CODE FROM THIS LINE ONWARD

#func _initiate_webrtc_offer() -> void:
	#ClientDebugManager.log_to_file("L: _initiate_webrtc_offer() executed")
	#rtc_offer_sent = true
	#if rtc_connections.has(1):
		#rtc_connections[1].create_offer()

#func setup_signaling_server() -> bool:
	#signaling_peer = WebSocketPeer.new()
	#var signaling_error: Error = signaling_peer.create_server(SIGNALING_PORT)
	#if signaling_error != OK:
		#print_error("NETWORK ERROR: cannot host signaling server: " + str(signaling_error))
		#return false
	#signaling_peer.peer_connected.connect(_on_signaling_peer_connected)
	#signaling_peer.peer_disconnected.connect(_on_signaling_peer_disconnected)
	#return true

#func _on_signaling_peer_connected(id: int) -> void:
	#if not is_server: return
	#_send_signal(id, {"type": "id", "id": id})
	#var conn := WebRTCPeerConnection.new()
	#conn.initialize({ "iceServers": ICE_SERVERS })
	#conn.session_description_created.connect(_on_sdp_created.bind(id))
	#conn.ice_candidate_created.connect(_on_ice_created.bind(id))
	#rtc_peer.add_peer(conn, id)
	#rtc_connections[id] = conn

#func _initialize_webrtc_client(my_id: int) -> void:
	#rtc_peer = WebRTCMultiplayerPeer.new()
	#var rtc_error: Error = rtc_peer.create_client(my_id)
	#if rtc_error != OK:
		#print_error("NETWORK ERROR: rtc client creation failed: " + str(rtc_error))
		#return
	#ClientDebugManager.log_to_file("_initialize_webrtc_client() success(rtc_error == OK)")
	#multiplayer.set_multiplayer_peer(rtc_peer)
	#var conn := WebRTCPeerConnection.new()
	#conn.initialize({ "iceServers": ICE_SERVERS })
	#conn.session_description_created.connect(_on_sdp_created.bind(1))
	#conn.ice_candidate_created.connect(_on_ice_created.bind(1))
	#rtc_peer.add_peer(conn, 1)
	#rtc_connections[1] = conn
	#conn.create_offer()

#func _on_signaling_peer_disconnected(id: int) -> void:
	#print_local("Signaling WebSocket disconnected for peer " + SessionManager.encode_session_id(id))
	##if rtc_connections.has(id):
		##var conn: WebRTCPeerConnection = rtc_connections[id]
		##if conn.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED: return
		##conn.close()
		##rtc_connections.erase(id)
	##if rtc_peer and rtc_peer.has_peer(id):
		##rtc_peer.remove_peer(id)

#func setup_rtc_server() -> bool:
	#rtc_peer = WebRTCMultiplayerPeer.new()
	#var rtc_error: Error = rtc_peer.create_server()
	#if rtc_error != OK:
		#print_error("NETWORK ERROR: cannot host rtc peer: " + str(rtc_error))
		#return false
	#multiplayer.set_multiplayer_peer(rtc_peer)
	#return true

#func setup_signaling_client() -> bool:
	#print_local("Trying to connect to URL = " + url)
	#rtc_offer_sent = false
	#signaling_peer = WebSocketPeer.new()
	#var error: Error = signaling_peer.create_client(url)
	#if error != OK:
		#print_error("NETWORK ERROR: signaling connection failed: " + str(error))
		#return false
	#ClientDebugManager.log_to_file("L: setup_signaling_client() returns true")
	#return true

#func setup_rtc_client_peer() -> bool:
	#rtc_peer = WebRTCMultiplayerPeer.new()
	#var random_id: int = abs(randi_range(2, INT32_MAX))
	#var rtc_error: Error = rtc_peer.create_client(random_id)
	#if rtc_error != OK:
		#print_error("NETWORK ERROR: rtc client creation failed: " + str(rtc_error))
		#return false
	#multiplayer.set_multiplayer_peer(rtc_peer)
	#ClientDebugManager.log_to_file("L: setup_rtc_client_peer() returns true")
	#return true

#func setup_rtc_client_connection() -> void:
	#ClientDebugManager.log_to_file("setup_rtc_client_connection() executed")
	#var conn := WebRTCPeerConnection.new()
	#conn.initialize({ "iceServers": ICE_SERVERS })
	#conn.session_description_created.connect(_on_sdp_created.bind(1))
	#conn.ice_candidate_created.connect(_on_ice_created.bind(1))
	#rtc_peer.add_peer(conn, 1)
	#rtc_connections[1] = conn

#func _close_client_signaling() -> void:
	#ClientDebugManager.log_to_file("_close_client_signaling() executed by code commented out")
	##if not signaling_peer: return
	##signaling_peer.close()
	##signaling_peer = null
	##print("Signaling WebSocket closed gracefully after WebRTC connection")

#func _close_peer_signaling(_peer_id: int) -> void:
	#pass
	##if not signaling_peer: return
	##if signaling_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return
	##if not signaling_peer.has_peer(peer_id): return
	##signaling_peer.disconnect_peer(peer_id)
