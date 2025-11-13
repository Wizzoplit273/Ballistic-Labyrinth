extends Node

## those variables may be changed by the player in the settings menu
## maze size(width first, then height)
var min_maze_size: Vector2i = Vector2i(12, 12)
var max_maze_size: Vector2i = Vector2i(16, 16)
## random wall remove(after generating internal visual walls)
var wall_remove_interval: Vector2i = Vector2i(0, 5)
## enemy count
var bot_count_interval: Vector2i = Vector2i(1, 3)
## friendly fire for enemies(i.e. enemies can kill themselves, but not necessarily individually)
var bot_friendly_fire: bool = true
## maze carve offset
var maze_carve_offset: Vector2i = Vector2i(0, 3)
## player skin colour(corresponds to the player texture's modulation)
var player_color: Color = Color.WHITE
## peer username(may be unique in the future)
var peer_username: String = "unnamed"

var player_score: int = 0
var bot_score: int = 0

func _ready() -> void:
	$MainMenu.activate(true)
	network_ready()

var DEBUG_is_checking_maze: bool = false
var DEBUG_is_showing_dodging: bool = false

func _process(_delta: float) -> void:
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Toggle_Maze_Generation"):
		DEBUG_is_checking_maze = not DEBUG_is_checking_maze
		if current_level != null: current_level.DEBUG_is_checking_maze = DEBUG_is_checking_maze
		$DEBUG_Screen/Frame/DEBUG_MazeCheck.visible = DEBUG_is_checking_maze
		if DEBUG_is_checking_maze:
			push_warning("DEBUG_Toggle_Maze_Generation is now ON")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now ON")
		else:
			push_warning("DEBUG_Toggle_Maze_Generation is now OFF")
			print("\t\t\tDEBUG_Toggle_Maze_Generation is now OFF")
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Show_Dodging"):
		DEBUG_is_showing_dodging = not DEBUG_is_showing_dodging
		if current_level != null: current_level.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
		$DEBUG_Screen/Frame/DEBUG_DodgeCheck.visible = DEBUG_is_showing_dodging
		if DEBUG_is_showing_dodging:
			print("\t\t\tDEBUG_Show_Dodging is now ON")
		else:
			print("\t\t\tDEBUG_Show_Dodging is now OFF")

func stop_level() -> void:
	$MainMenu.activate(true)
	if $CurrentLevelContainer.get_child_count() > 0 and current_level != null:
		current_level.queue_free()

var current_level: Node = null
const LEVEL_FILE: String = "res://ingame/level/level.tscn"
@rpc("any_peer", "call_local")
func play_level() -> void:
	$MainMenu.activate(false)
	if $CurrentLevelContainer.get_child_count() > 0 and current_level != null:
		current_level.queue_free()
	current_level = load(LEVEL_FILE).instantiate()
	current_level.connect("next_round", next_round)
	update_level_variables()
	$CurrentLevelContainer.add_child(current_level)
	current_level.modified_ready()

func update_level_variables() -> void:
	if current_level == null: return
	current_level.DEBUG_is_checking_maze = DEBUG_is_checking_maze
	current_level.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
	current_level.min_maze_size = min_maze_size
	current_level.max_maze_size = max_maze_size
	current_level.wall_remove_interval = wall_remove_interval
	current_level.bot_count_interval = bot_count_interval
	current_level.bot_friendly_fire = bot_friendly_fire
	current_level.player_score = player_score # deprecated
	current_level.bot_score = bot_score # deprecated
	current_level.maze_carve_offset = maze_carve_offset
	current_level.player_color = player_color
	current_level.peer_username = peer_username

func next_round(player_increment: int, enemy_increment: int) -> void:
	player_score = player_increment
	bot_score = enemy_increment
	play_level()

##
##
## 					MULTIPLAYER CONTROLLER CODE DOWN
##
##

@export var address: String = "127.0.0.1"
@export var port: int = 8910

const MAX_CLIENT_COUNT: int = 5

## called on server and clients
func peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var log_message: String = "LOG: Client with id=" + str(id)
		log_message += " has joined the room"
		$Chat.send_log_message(log_message)
	print("Player connected with id = " + str(id))

## called on server and clients
func peer_disconnected(id: int) -> void:
	print("Player disconnected with id = " + str(id))

const NEW_PLAYER_LOBBY_UI_FILE: String = "res://ui/player_lobby_ui/player_lobby_ui.tscn"
@rpc("reliable", "any_peer")
func update_player_information(id: int, is_bot: bool, given_name: String, modulation: Color, score: int, kills: int, players_count: int) -> void:
	## integer parameters will not send their respective updates if they're less than 0
	## only exception has id; if it's an invalid id(non-positive), then it throws an error
	## given_name will not send update if it's equal to "" (i.e. the empty string)
	## modulation will not send update if it's equal to Color.TRANSPARENT (i.e. Color(1, 1, 1, 0))
	if not is_bot and id <= 0:
		var ERROR: String = "CUSTOM ERROR: invalid id parameter equal to " + str(id) + ". Find the imposter..."
		push_error(ERROR)
		print_debug(ERROR)
		return
	var player_lobby_ui_instance: Control = null
	if (is_bot and GameManager.bots_list.has(id)) or (not is_bot and GameManager.humans_list.has(id)):
		for scene: Control in %PlayerLobbyList.get_children():
			if not scene.has_node("Frame/IDLabel"):
				var ERROR: String = "CUSTOM ERROR: player lobby ui scene " + str(scene) + " doesn't have a proper ID label set"
				push_error(ERROR)
				print_debug(ERROR)
				continue
			if is_bot:
				if scene.get_node("Frame/IDLabel").text != "ID: bot/" + str(id): continue
			else:
				if scene.get_node("Frame/IDLabel").text != "ID: " + str(id): continue
			player_lobby_ui_instance = scene
			break
		if player_lobby_ui_instance == null:
			const ERROR: String = "CUSTOM ERROR: selected player lobby ui scene is null for some reason"
			push_error(ERROR)
			print_debug(ERROR)
			return
	else: player_lobby_ui_instance = load(NEW_PLAYER_LOBBY_UI_FILE).instantiate()
	if is_bot: player_lobby_ui_instance.get_node("Frame/IDLabel").text = "ID: bot/" + str(id)
	else: player_lobby_ui_instance.get_node("Frame/IDLabel").text = "ID: " + str(id)
	if given_name == "" and modulation == Color.TRANSPARENT: ## if one other parameter is not changing, then change to unnamed
		given_name = "unnamed"
	if given_name != "" or modulation == Color.TRANSPARENT:
		player_lobby_ui_instance.get_node("Frame/NameLabel").text = "Name: " + given_name
	if modulation != Color.TRANSPARENT:
		player_lobby_ui_instance.get_node("Frame/TextureBox/TankTexture").modulate = modulation
	if (is_bot and GameManager.bots_list.has(id)) or (not is_bot and GameManager.humans_list.has(id)):
		if score >= 0:
			player_lobby_ui_instance.get_node("Frame/RestLabels/ScoreLabel").text = "Score: " + str(score)
		if kills >= 0:
			player_lobby_ui_instance.get_node("Frame/RestLabels/KillsLabel").text = "Kills: " + str(kills)
	else: ## a little safety check when it's just getting created
		player_lobby_ui_instance.get_node("Frame/RestLabels/ScoreLabel").text = "Score: 0"
		player_lobby_ui_instance.get_node("Frame/RestLabels/KillsLabel").text = "Kills: 0"
	if player_lobby_ui_instance.get_parent() == null:
		%PlayerLobbyList.add_child(player_lobby_ui_instance)
	if not multiplayer.is_server(): return
	if is_bot:
		if GameManager.bots_list.has(id):
			GameManager.bots_list[id] = {
				"lobby_instance": player_lobby_ui_instance,
				"is_bot": true,
				"name": given_name,
				"modulation": modulation,
				"score": score,
				"kills": kills
			}
		else:
			GameManager.bots_list[id] = {
				"lobby_instance": player_lobby_ui_instance,
				"is_bot": true,
				"name": given_name,
				"modulation": modulation,
				"score": 0,
				"kills": 0
			}
	else:
		if GameManager.humans_list.has(id):
			GameManager.humans_list[id] = {
				"lobby_instance": player_lobby_ui_instance,
				"is_bot": false,
				"name": given_name,
				"modulation": modulation,
				"score": score,
				"kills": kills
			}
		else: ## a little safety check when it's just getting created
			GameManager.humans_list[id] = {
				"lobby_instance": player_lobby_ui_instance,
				"is_bot": false,
				"name": given_name,
				"modulation": modulation,
				"score": 0,
				"kills": 0
			}
	players_count = GameManager.humans_list.keys().size() + GameManager.bots_list.keys().size()
	update_connected_peers_count(players_count, -2)
	if is_bot:
		update_player_information.rpc(id, true, given_name, modulation, score, kills, players_count)
	else:
		for human_id: int in GameManager.humans_list:
			var selected_name: String = GameManager.humans_list[human_id].name
			var selected_modulation: Color = GameManager.humans_list[human_id].modulation
			var selected_score: int = GameManager.humans_list[human_id].score
			var selected_kills: int = GameManager.humans_list[human_id].kills
			update_player_information.rpc(human_id, false, selected_name, selected_modulation, selected_score, selected_kills, players_count)

## adding excluded peer parameter to fix faulty packet send during peer disconnect
var players_count: int = 0
@rpc("reliable", "any_peer")
func update_connected_peers_count(count: int, excluded_peer: int) -> void:
	if multiplayer.is_server:
		for peer_id: int in multiplayer.get_peers():
			if peer_id == 1: continue
			if peer_id == excluded_peer: continue
			rpc_id(peer_id, "update_connected_peers_count", count, excluded_peer)
	%PlayerListCountLabel.text = "Player count: " + str(count)
	players_count = count

## called on clients
func connected_to_server() -> void:
	update_player_information.rpc_id(1, multiplayer.get_unique_id(), false, %PlayerNameEdit.text, %PlayerColorPicker.color, 0, 0, -1)
	%PeerModeLabel.text = CLIENT_PEER_TEXT + str(multiplayer.get_unique_id())
	print("Successfully connected to server")

## called on clients
func connection_failed() -> void:
	print("Connection failed")

## called on clients
func disconnect_from_server() -> void:
	if multiplayer.is_server(): return
	remove_client.rpc_id(1, multiplayer.get_unique_id())

## called on server
@rpc("reliable", "any_peer")
func remove_client(id: int) -> void:
	GameManager.humans_list.erase(id)
	var selected_scene: Control = null
	for scene: Control in %PlayerLobbyList.get_children():
		if not scene.has_node("Frame/IDLabel"):
			var ERROR: String = "CUSTOM ERROR: player lobby ui scene " + str(scene) + " doesn't have a proper ID label set"
			push_error(ERROR)
			print_debug(ERROR)
			continue
		if scene.get_node("Frame/IDLabel").text != "ID: " + str(id): continue
		selected_scene = scene
		break
	if selected_scene == null:
		const ERROR: String = "CUSTOM ERROR: selected player lobby ui scene is null for some reason"
		push_error(ERROR)
		print_debug(ERROR)
		return
	selected_scene.queue_free()
	if multiplayer.is_server():
		var client_name: String = selected_scene.get_node("Frame/NameLabel").text
		client_name = client_name.get_slice("Name: ", 1)
		var log_message: String = "LOG: Client with id=" + str(id)
		log_message += " and name=\"" + client_name + "\" has left the room"
		$Chat.send_log_message(log_message)
		update_connected_peers_count(players_count - 1, id)
		await get_tree().process_frame
		for peer_id: int in multiplayer.get_peers():
			if peer_id == 1: continue
			if peer_id == id: continue
			remove_client.rpc_id(peer_id, id)
		proceed_disconnecting_client.rpc_id(id)

## called on clients
@rpc("reliable", "any_peer")
func proceed_disconnecting_client() -> void:
	clear_client_side_data()
	await get_tree().process_frame
	multiplayer.multiplayer_peer.close()
	print("Successfully disconnected from server")

## called on clients
func clear_client_side_data() -> void:
	GameManager.humans_list.clear()
	GameManager.bots_list.clear()
	for scene: Control in %PlayerLobbyList.get_children():
		scene.queue_free()
	toggle_host_options(true)
	toggle_connection_options(true)
	%PeerModeLabel.text = UNCONFIGURED_PEER_TEXT
	%PlayerListCountLabel.text = "Player count: 0"

## called on server
func remove_server() -> void:
	if not multiplayer.is_server(): return
	remove_all_peers()
	print("Successfully disconnected clients and closed the server")

## called on server and clients
@rpc("reliable", "any_peer")
func remove_all_peers() -> void:
	if multiplayer.is_server(): rpc("remove_all_peers")
	GameManager.humans_list.clear()
	GameManager.bots_list.clear()
	for scene: Control in %PlayerLobbyList.get_children():
		scene.queue_free()
	toggle_host_options(true)
	toggle_connection_options(true)
	%PeerModeLabel.text = UNCONFIGURED_PEER_TEXT
	%PlayerListCountLabel.text = "Player count: 0"
	await get_tree().process_frame
	multiplayer.multiplayer_peer.close()

func network_ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

var peer: ENetMultiplayerPeer = null
const COMPRESSION: ENetConnection.CompressionMode = ENetConnection.CompressionMode.COMPRESS_FASTLZ
const UNCONFIGURED_PEER_TEXT: String = "You're not part of a room! Click \"Host\" to start hosting a room or \"Join\" to join a created room"
const CLIENT_PEER_TEXT: String = "You're now a client in a room with id = "
const SERVER_PEER_TEXT: String = "You're now the host of a room"

func initialize_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENT_COUNT)
	if error != OK:
		push_error("CUSTOM ERROR: cannot host: " + str(error))
		return
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for players...")
	update_player_information(1, false, %PlayerNameEdit.name, %PlayerColorPicker.color, 0, 0, -1)
	toggle_host_options(true)
	toggle_connection_options(false)
	%PeerModeLabel.text = SERVER_PEER_TEXT

func initialize_client() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	print("Player joined with id = ", address)
	toggle_host_options(false)
	toggle_connection_options(false)

var current_bot_id: int = 0
## called on server
func create_bot() -> void:
	if not multiplayer.is_server(): return
	update_player_information(current_bot_id, true, "BOT " + str(current_bot_id), Color.BROWN, 0, 0, -1)
	current_bot_id += 1

func toggle_host_options(toggle: bool) -> void:
	%StartMissionButton.disabled = not toggle
	%SettingsButton.disabled = not toggle
	%AddBotButton.disabled = not toggle

func toggle_connection_options(toggle: bool) -> void:
	%HostButton.disabled = not toggle
	%JoinButton.disabled = not toggle
	if toggle: %AddBotButton.disabled = true
