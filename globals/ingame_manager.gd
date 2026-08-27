extends Node

## this node will have every controller node as a child node so they're easier to access

## updated once by origin node, remains constant
var scene_root: Node = null

var current_seed: int = 0
var current_maze_dimensions: Vector2i = Vector2i(20, 12) ## first entry is width, second is height
var set_maze_dimensions: Vector4i = Vector4i(20, 20, 12, 12)
var current_is_animated_generation: bool = false

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame_container: MultiplayerSpawner = null
var controller_container: MultiplayerSpawner = null

var is_ingame_configured: bool = false
var is_ingame_finished: bool = false

#var finished_clients: Array = []

var alive_tanks_count: int = 0

func _enter_tree() -> void:
	setup_ingame_container()
	setup_controller_container()

func setup_ingame_container() -> void:
	ingame_container = MultiplayerSpawner.new()
	ingame_container.spawn_function = spawn_ingame
	add_child(ingame_container, true)
	ingame_container.name = "IngameContainer"
	ingame_container.spawn_path = ingame_container.get_path()

func setup_controller_container() -> void:
	controller_container = MultiplayerSpawner.new()
	controller_container.spawn_function = _custom_spawn
	add_child(controller_container, true)
	controller_container.name = "ControllerContainer"
	controller_container.spawn_path = controller_container.get_path()

@rpc("authority", "reliable", "call_local")
func set_maze_size(string: String) -> void:
	var result: Vector4i = SessionManager.string_to_vector4i(string)
	if result[0] <= 0 or result[1] <= 0 or result[2] <= 0 or result[3] <= 0: return
	if result[0] > result[1] or result[2] > result[3]: return
	set_maze_dimensions = result

func create_controller(sid: int) -> void:
	if sid == 0: return
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	controller_container.spawn(sid)

const NEW_PLAYER_CONTROLLER_FILE: String = "res://ingame/controllers/player_controller/player_controller.tscn"
const NEW_BOT_CONTROLLER_FILE: String = "res://ingame/controllers/bot_controller/bot_controller.tscn"
func _custom_spawn(sid: Variant) -> Node:
	sid = int(sid)
	if sid == 0: return null
	var controller: Node
	if sid >= 1: controller = load(NEW_PLAYER_CONTROLLER_FILE).instantiate()
	if sid <= -1: controller = load(NEW_BOT_CONTROLLER_FILE).instantiate()
	controller.set_sid(sid)
	return controller

func create_controllers() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	var already_has_controller: bool
	for sid: int in SessionManager.data:
		already_has_controller = false
		for controller: Node in controller_container.get_children():
			if controller.sid != sid: continue
			already_has_controller = true
			break
		if already_has_controller: continue
		create_controller(sid)

@rpc("authority", "reliable", "call_local")
func disable_client_controller(path: NodePath) -> void:
	get_node(path).set_multiplayer_authority(1)
	get_node(path).set_visibility_public(false)

func delete_controllers() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	for controller: Node in controller_container.get_children():
		if controller is MultiplayerSynchronizer:
			disable_client_controller.rpc_id(controller.sid, controller.get_path())
		await get_tree().process_frame
		controller.queue_free()

@rpc("any_peer", "reliable", "call_local")
func start_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	current_seed = randi()
	current_maze_dimensions.x = randi_range(set_maze_dimensions[0], set_maze_dimensions[1])
	current_maze_dimensions.y = randi_range(set_maze_dimensions[2], set_maze_dimensions[3])
	if current_maze_dimensions.y > current_maze_dimensions.x:
		var auxiliary: int = current_maze_dimensions.x
		current_maze_dimensions.x = current_maze_dimensions.y
		current_maze_dimensions.y = auxiliary
	start_ingame(current_seed, current_maze_dimensions, true)

@rpc("any_peer", "reliable")
func end_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	end_ingame()

const LATE_INGAME_SYNC_DELAY: float = 2.0
@rpc("authority", "reliable")
func late_sync_ingame(maze_seed: int, maze_dimensions: Vector2i) -> void:
	await get_tree().create_timer(LATE_INGAME_SYNC_DELAY).timeout
	start_ingame(maze_seed, maze_dimensions, false)

func start_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool) -> void:
	if not multiplayer.is_server(): return
	set_maze_properties.rpc(maze_seed, maze_dimensions, is_animated)
	create_controllers()
	create_ingame()

@rpc("authority", "reliable", "call_local")
func set_maze_properties(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool) -> void:
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	current_seed = maze_seed
	current_maze_dimensions = maze_dimensions
	current_is_animated_generation = is_animated

func create_ingame() -> void:
	if ingame_container.get_child_count() > 0: return
	var data: Dictionary = {
		"seed": current_seed,
		"dimensions": current_maze_dimensions
	}
	ingame_container.spawn(data)

var ingame_node: Node = null
func spawn_ingame(data: Variant) -> Node:
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	is_ingame_configured = true
	var ingame: Node = load(INGAME_FILE).instantiate()
	ingame_node = ingame
	current_seed = data["seed"]
	current_maze_dimensions = data["dimensions"]
	return ingame

@rpc("authority", "reliable")
func restart_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool = false) -> void:
	delete_ingame(false)
	await get_tree().process_frame
	start_ingame(maze_seed, maze_dimensions, is_animated)

func delete_ingame(is_deleting_controllers: bool) -> void:
	if not multiplayer.is_server(): return
	if ingame_container.get_child_count() == 0: return
	for spawner: Node in ingame_container.get_child(0).get_children():
		if not spawner is MultiplayerSpawner: continue
		for instance: Node in spawner.get_children():
			instance.free()
	if is_deleting_controllers: delete_controllers()
	ingame_container.get_child(0).queue_free()

@rpc("authority", "reliable")
func end_ingame() -> void:
	is_ingame_finished = false
	is_ingame_configured = false
	delete_ingame(true)
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(true)
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	MasterManager.set_pause(false)
	end_ingame.rpc()

@rpc("any_peer", "reliable", "call_local")
func request_end_ingame() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	if pid == 0: return
	if SessionManager.data[pid].get("admin") != true: return
	MasterManager.set_pause(false)
	end_ingame()

func _on_ingame_next_round() -> void:
	delete_ingame(false)
	await get_tree().process_frame
	start_game()

func finish_network_maze_generation() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	#for pid: int in multiplayer.get_peers():
		#if pid in finished_clients: continue
		#restart_ingame.rpc_id(pid, current_seed, current_maze_dimensions, false)
	place_pawns()
	ingame_node.toggle_pawns.rpc(true)
	ingame_node.activate_crate_spawn_timer()
	is_ingame_finished = true

#@rpc("any_peer", "reliable")
#func add_finished_generation() -> void:
	#var pid: int = multiplayer.get_remote_sender_id()
	#if pid <= 1: return
	#finished_clients.append(pid)

const FINISH_GENERATION_DELAY: float = 1.0
func broadcast_generation_finish() -> void:
	if not multiplayer.is_server(): return
	await get_tree().create_timer(FINISH_GENERATION_DELAY).timeout
	finish_network_maze_generation()
	#return
	#add_finished_generation.rpc_id(1)

const PAWN_LINEAR_STUCK_FACTOR: float = 200 / 3.2
const NEW_TANK_PAWN_PATH: String = "res://ingame/entities/tank_pawn/tank_pawn.tscn"
func place_pawns() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	alive_tanks_count = 0
	var tank_pawn: RigidBody2D = null
	for sid: int in SessionManager.data.keys():
		if sid == 0: continue
		tank_pawn = load(NEW_TANK_PAWN_PATH).instantiate()
		var target_controller: Node = null
		for controller: Node in controller_container.get_children():
			if controller.sid != sid: continue
			target_controller = controller
			break
		if target_controller == null: continue # normally shouldn't happen
		target_controller.pawn = tank_pawn
		if target_controller.get_meta("type", "null") == "bot":
			target_controller.MAX_STUCK_POSITION_CHANGE = tank_pawn.linear_speed / PAWN_LINEAR_STUCK_FACTOR
		tank_pawn.controller = target_controller
		tank_pawn.get_node(^"Rest/Image").modulate = SessionManager.data[sid]["color"]
		tank_pawn.get_node(^"DeathParticles").modulate = SessionManager.data[sid]["color"]
		tank_pawn.label_node.text = SessionManager.data[sid]["name"]
		var selected_cell: Vector2i = ingame_node.maze_cells.get(ingame_node.SEEDED_RNG.randi_range(0, ingame_node.maze_cells.size() - 1))
		tank_pawn.global_position = ingame_node.maze_cell_to_world(selected_cell)
		tank_pawn.rotation = ingame_node.SEEDED_RNG.randf_range(0, PI * 2)
		tank_pawn.connect("shoot_bullet", _on_shoot_bullet)
		ingame_node.get_node("TankPawns").add_child(tank_pawn, true)
		alive_tanks_count += 1

## directly called by destroyed tanks
func _on_tank_die() -> void:
	alive_tanks_count -= 1
	MasterManager.play_server_sound(ingame_node.get_node(^"Sounds/DeathNoise"))
	if alive_tanks_count <= 1: ingame_node.get_node(^"Timers/DeathDelay").start()

func _on_shoot_bullet(weapon_type: String, tank: RigidBody2D) -> void:
	if tank == null: return
	if weapon_type != "regular":
		tank.equip_weapon.rpc("regular")
	var payload: Dictionary = {}
	var bullet_offset: float
	if weapon_type == "regular":
		bullet_offset = tank.REGULAR_SPAWN_OFFSET
		payload["initial_velocity_speed"] = tank.regular_speed
		payload["type"] = "regular"
	if weapon_type == "laser":
		bullet_offset = tank.LASER_SPAWN_OFFSET
		payload["initial_velocity_speed"] = tank.laser_speed
		payload["lifespan"] = tank.laser_lifespan
		payload["type"] = "laser"
	if weapon_type == "rocket":
		bullet_offset = tank.ROCKET_SPAWN_OFFSET
		payload["initial_velocity_speed"] = tank.rocket_speed
		payload["lifespan"] = tank.rocket_lifespan
		payload["type"] = "rocket"
	if weapon_type == "trap":
		bullet_offset = tank.TRAP_SPAWN_OFFSET
		payload["initial_velocity_speed"] = tank.trap_speed
		payload["type"] = "trap"
	payload["owner"] = tank.get_path()
	payload["initial_velocity_direction"] = tank.rotation
	payload["position"] = tank.position + Vector2(bullet_offset, 0).rotated(tank.rotation)
	if weapon_type == "regular": tank.fired_bullet_count += 1
	ingame_node.get_node("Bullets").spawn(payload)

const NEW_BULLET_FILE := "res://ingame/entities/projectiles/bullet.tscn"
func spawn_bullet(payload: Dictionary) -> Node:
	var bullet: RigidBody2D = load(NEW_BULLET_FILE).instantiate()
	bullet.position = payload["position"]
	bullet.initial_velocity_speed = payload["initial_velocity_speed"]
	if payload.has("lifespan"): bullet.get_node("LifespanTimer").wait_time = payload["lifespan"]
	bullet.type = payload["type"]
	bullet.initial_velocity_direction = payload["initial_velocity_direction"]
	bullet.owner_node = get_node(payload["owner"])
	if bullet.type == "regular": ingame_node.get_node("Sounds/NormalShootNoise").play()
	if bullet.type == "laser": ingame_node.get_node("Sounds/LaserShootNoise").play()
	if bullet.type == "rocket": ingame_node.get_node("Sounds/RocketShootNoise").play()
	if bullet.type == "trap": ingame_node.get_node("Sounds/TrapPlaceNoise").play()
	return bullet

@rpc("any_peer", "reliable", "call_local")
func teleport_tank(pos: Vector2) -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	if SessionManager.data[pid].get("admin") != true: return
	var pawn: Node2D = null
	for controller: Node in controller_container.get_children():
		if controller.sid != pid: continue
		if controller.pawn == null: return
		pawn = controller.pawn
		break
	if pawn == null: return
	pawn.global_position = pos

@rpc("any_peer", "reliable", "call_local")
func change_invincibility() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	if SessionManager.data[pid].get("admin") != true: return
	var pawn: Node2D = null
	for controller: Node in controller_container.get_children():
		if controller.sid != pid: continue
		if controller.pawn == null: return
		pawn = controller.pawn
		break
	if pawn == null: return
	pawn.is_invincible = not pawn.is_invincible
	var text: String = "invincibility set to "
	if pawn.is_invincible: text += "true "
	else: text += "false "
	text += "for pid = " + SessionManager.encode_session_id(pid)
	ConsoleManager.print_output(text, "admin", 0)

### connected to each bullet's despawn signal
#func on_bullet_despawn(bullet: RigidBody2D) -> void:
	#if bullet.type == "regular": bullet.owner_node.fired_bullet_count -= 1
