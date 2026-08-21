extends MultiplayerSpawner

## this node will have every controller node as a child node so they're easier to access

## updated once by origin node, remains constant
var scene_root: Node = null

var current_seed: int = 0
var current_maze_dimensions: Vector2i = Vector2i(20, 12) ## first entry is width, second is height

const INGAME_FILE: String = "res://ingame/ingame.tscn"
var ingame: Node = null

var is_ingame_configured: bool = false

var finished_clients: Array = []

var alive_tanks_count: int = 0

func _enter_tree() -> void:
	spawn_path = get_path()
	spawn_function = _custom_spawn

func create_controller(sid: int) -> void:
	if sid == 0: return
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	spawn(sid)

const NEW_PLAYER_CONTROLLER_FILE: String = "res://ingame/controllers/player_controller/player_controller.tscn"
const NEW_BOT_CONTROLLER_FILE: String = "res://ingame/controllers/bot_controller/bot_controller.tscn"
func _custom_spawn(sid: int) -> Node:
	if sid == 0: return null
	var controller: Node
	if sid >= 1: controller = load(NEW_PLAYER_CONTROLLER_FILE).instantiate()
	if sid <= -1: controller = load(NEW_BOT_CONTROLLER_FILE).instantiate()
	controller.set_sid(sid)
	return controller

func create_controllers() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	for sid: int in SessionManager.data: create_controller(sid)

func delete_controllers() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	for controller: Node in get_children(): controller.queue_free()

@rpc("any_peer", "reliable", "call_local")
func start_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	current_seed = randi()
	start_ingame.rpc(current_seed, current_maze_dimensions, true)

@rpc("any_peer", "reliable")
func end_game() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	if pid != 0 and SessionManager.data[pid].get("admin") == false: return
	end_ingame()

@rpc("authority", "reliable", "call_local")
func start_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool = false) -> void:
	if not NetworkManager.is_online: return
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(false)
	current_seed = maze_seed
	current_maze_dimensions = maze_dimensions
	create_controllers()
	create_ingame(is_animated)

func create_ingame(is_animated: bool = false) -> void:
	if ingame != null: return
	ingame = load(INGAME_FILE).instantiate()
	scene_root.add_child(ingame)
	ingame.connect("_on_next_round", _on_ingame_next_round)
	is_ingame_configured = true
	ingame.modified_ready(is_animated)

@rpc("authority", "reliable")
func restart_ingame(maze_seed: int, maze_dimensions: Vector2i, is_animated: bool = false) -> void:
	delete_ingame()
	await get_tree().process_frame
	start_ingame(maze_seed, maze_dimensions, is_animated)

func delete_ingame() -> void:
	if not multiplayer.is_server(): return
	if ingame == null: return
	for spawner: Node in ingame.get_children():
		if not spawner is MultiplayerSpawner: continue
		for instance: Node in spawner.get_children():
			instance.free()
	client_delete_ingame.rpc()

@rpc("authority", "reliable", "call_local")
func client_delete_ingame() -> void:
	ingame.queue_free()
	is_ingame_configured = false

@rpc("authority", "reliable")
func end_ingame() -> void:
	delete_ingame()
	if UIManager.is_ui_configured: UIManager.lobby_node.activate(true)
	if not NetworkManager.is_online: return
	if multiplayer.is_server(): end_ingame.rpc()

@rpc("any_peer", "reliable", "call_local")
func request_end_ingame() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	if pid == 0: return
	if SessionManager.data[pid].get("admin") != true: return
	MasterManager.set_pause(false)
	end_ingame()

func _on_ingame_next_round() -> void:
	delete_ingame()
	await get_tree().process_frame
	create_ingame(true)

func finish_network_maze_generation() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	for pid: int in multiplayer.get_peers():
		if pid in finished_clients: continue
		restart_ingame.rpc_id(pid, current_seed, current_maze_dimensions, false)
	place_pawns()
	ingame.toggle_pawns.rpc(true)
	ingame.activate_crate_spawn_timer()

@rpc("any_peer", "reliable")
func add_finished_generation() -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if pid <= 1: return
	finished_clients.append(pid)

const FINISH_GENERATION_DELAY: float = 1.0
func broadcast_generation_finish() -> void:
	if multiplayer.is_server():
		await get_tree().create_timer(FINISH_GENERATION_DELAY).timeout
		finish_network_maze_generation()
		return
	add_finished_generation.rpc_id(1)

const NEW_TANK_PAWN_PATH: String = "res://ingame/entities/tank_pawn/tank_pawn.tscn"
func place_pawns() -> void:
	if not NetworkManager.is_online: return
	if not multiplayer.is_server(): return
	var tank_pawn: RigidBody2D = null
	for sid: int in SessionManager.data.keys():
		if sid == 0: continue
		tank_pawn = load(NEW_TANK_PAWN_PATH).instantiate()
		var target_controller: Node = null
		for controller: Node in get_children():
			if controller.sid != sid: continue
			target_controller = controller
			break
		if target_controller == null: continue # normally shouldn't happen
		target_controller.pawn = tank_pawn
		tank_pawn.controller = target_controller
		tank_pawn.get_node("Rest/Image").modulate = SessionManager.data[sid]["color"]
		tank_pawn.label_node.text = SessionManager.data[sid]["name"]
		var selected_cell: Vector2i = ingame.maze_cells.get(ingame.SEEDED_RNG.randi_range(0, ingame.maze_cells.size() - 1))
		tank_pawn.global_position = ingame.maze_cell_to_world(selected_cell)
		tank_pawn.rotation = ingame.SEEDED_RNG.randf_range(0, PI * 2)
		tank_pawn.connect("shoot_bullet", _on_shoot_bullet)
		ingame.get_node("TankPawns").add_child(tank_pawn, true)
		alive_tanks_count += 1

func _on_shoot_bullet(weapon_type: String, tank: RigidBody2D) -> void:
	if tank == null: return
	if weapon_type != "regular":
		if multiplayer.is_server(): tank.equip_weapon.rpc("regular")
		else: tank.equip_weapon("regular")
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
		payload["initial_velocity_speed"] = 0.0
		payload["type"] = "trap"
	payload["owner"] = tank.get_path()
	payload["initial_velocity_direction"] = tank.rotation
	payload["position"] = tank.position + Vector2(bullet_offset, 0).rotated(tank.rotation)
	if weapon_type == "regular": tank.fired_bullet_count += 1
	ingame.get_node("Bullets").spawn(payload)

const NEW_BULLET_FILE := "res://ingame/entities/projectiles/bullet.tscn"
func spawn_bullet(payload: Dictionary) -> Node:
	var bullet: RigidBody2D = load(NEW_BULLET_FILE).instantiate()
	bullet.position = payload["position"]
	bullet.initial_velocity_speed = payload["initial_velocity_speed"]
	if payload.has("lifespan"): bullet.get_node("LifespanTimer").wait_time = payload["lifespan"]
	bullet.type = payload["type"]
	bullet.initial_velocity_direction = payload["initial_velocity_direction"]
	bullet.owner_node = get_node(payload["owner"])
	if bullet.type == "regular": ingame.get_node("Sounds/NormalShootNoise").play()
	if bullet.type == "laser": ingame.get_node("Sounds/LaserShootNoise").play()
	if bullet.type == "rocket": ingame.get_node("Sounds/RocketShootNoise").play()
	if bullet.type == "trap": ingame.get_node("Sounds/TrapPlaceNoise").play()
	return bullet

### connected to each bullet's despawn signal
#func on_bullet_despawn(bullet: RigidBody2D) -> void:
	#if bullet.type == "regular": bullet.owner_node.fired_bullet_count -= 1
