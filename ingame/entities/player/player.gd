extends RigidBody2D

## those variables are only used outside this script, in the level scene node
const BULLET_SPEED: float = 300.0

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

signal shoot(weapon_type: String)
func _physics_process(delta: float) -> void:
	if not visible: return
	if not Input.is_action_pressed("Drift"):
		linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if Input.is_action_pressed("MoveForward") and not Input.is_action_pressed("Drift"):
		apply_central_impulse((Vector2.RIGHT * LINEAR_SPEED).rotated(rotation))
	elif Input.is_action_pressed("MoveBackward") and not Input.is_action_pressed("Drift"):
		apply_central_impulse(-(Vector2.RIGHT * LINEAR_SPEED).rotated(rotation))
	if Input.is_action_pressed("RotateClockwise"):
		angular_velocity = ANGULAR_SPEED * delta
	if Input.is_action_pressed("RotateCounterclockwise"):
		angular_velocity = -ANGULAR_SPEED * delta
	
	if Input.is_action_just_pressed("Shoot") and $ShootCooldown.is_stopped():
		shoot.emit(weapon_type)
		$ShootCooldown.start()

const SKIN_PATH_PREFIX: String = "res://ingame/entities/player/player_"
const SKIN_EXTENSION: String = ".png"
func equip_weapon(type: String) -> void:
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
func die() -> void:
	$Rest.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	$DeathParticles.restart()
	level_die.emit()
