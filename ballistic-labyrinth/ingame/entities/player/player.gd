extends RigidBody2D

const LINEAR_SPEED: float = 200.0
const ANGULAR_SPEED: float = 300.0
const BULLET_SPAWN_OFFSET: float = 30.0
const MAX_BULLET_COUNT: int = 5

var weapon_type: String = "regular"

## updated by the parent level scene
var bullet_count: int = 0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not visible: return
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Teleport_Player"):
		state.transform.origin = get_global_mouse_position()

signal shoot(player: RigidBody2D, weapon_type: String)
var server_delta: float
var move_vector: Vector2i = Vector2i.ZERO
func _physics_process(delta: float) -> void:
	server_delta = delta
	if not visible: return
	$Rest/FixedRotation.rotation = -rotation
	if multiplayer.is_server():
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0 
		apply_central_impulse((Vector2.RIGHT * LINEAR_SPEED * move_vector.x).rotated(rotation))
		angular_velocity = ANGULAR_SPEED * move_vector.y * delta
	#if multiplayer.is_server(): linear_velocity = Vector2.ZERO
	#elif not is_pressing_linear: linear_velocity = Vector2.ZERO
	#if multiplayer.is_server(): angular_velocity = 0.0
	#elif not is_pressing_angular: angular_velocity = 0.0
	if get_meta("server_id", -1) != multiplayer.get_unique_id(): return
	if Input.is_action_pressed("MoveForward"): set_linear_input(1)
	elif Input.is_action_pressed("MoveBackward"): set_linear_input(-1)
	else: set_linear_input(0)
	if Input.is_action_pressed("RotateClockwise"): set_angular_input(1)
	elif Input.is_action_pressed("RotateCounterclockwise"): set_angular_input(-1)
	else: set_angular_input(0)
	if Input.is_action_just_pressed("Shoot") and $ShootCooldown.is_stopped():
		do_shoot()
		$ShootCooldown.start()

@rpc("reliable", "any_peer")
func set_linear_input(input: int) -> void:
	if not multiplayer.is_server():
		set_linear_input.rpc_id(1, input)
		return
	move_vector.x = input
@rpc("reliable", "any_peer")
func set_angular_input(input: int) -> void:
	if not multiplayer.is_server():
		set_angular_input.rpc_id(1, input)
		return
	move_vector.y = input
@rpc("reliable", "any_peer")
func do_shoot() -> void:
	if not multiplayer.is_server():
		do_shoot.rpc_id(1)
		return
	shoot.emit(self, weapon_type)

const SKIN_PATH_PREFIX: String = "res://ingame/entities/player/player_"
const SKIN_EXTENSION: String = ".png"
@rpc("reliable", "any_peer")
func equip_weapon(type: String) -> void:
	if multiplayer.is_server(): rpc("equip_weapon", type)
	if type == "regular":    
		weapon_type = type
		$Rest/Image.texture = load(SKIN_PATH_PREFIX + type + SKIN_EXTENSION)
		return
	if type == "laser":
		weapon_type = type
		$Rest/Image.texture = load(SKIN_PATH_PREFIX + type + SKIN_EXTENSION)
		return
	if type == "rocket":
		weapon_type = type
		$Rest/Image.texture = load(SKIN_PATH_PREFIX + type + SKIN_EXTENSION)
		return
	if type == "trap":
		weapon_type = type
		$Rest/Image.texture = load(SKIN_PATH_PREFIX + type + SKIN_EXTENSION)
		return

signal level_die
## called by bullet scenes that hit the player
@rpc("reliable", "any_peer")
func die() -> void:
	if multiplayer.is_server(): rpc("die")
	$Rest.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	$DeathParticles.restart()
	if multiplayer.is_server(): level_die.emit()
