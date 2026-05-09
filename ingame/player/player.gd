extends RigidBody2D

signal shoot

const LINEAR_SPEED: float = 200.0
const ANGULAR_SPEED: float = 300.0
const BULLET_SPAWN_OFFSET: float = 30.0
const BULLET_SPEED: float = 350.0
const MAX_BULLET_COUNT: int = 5

## updated by the parent level scene
var bullet_count: int = 0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not visible: return
	if OS.is_debug_build() and Input.is_action_just_pressed("DEBUG_Teleport_Player"):
		state.transform.origin = get_global_mouse_position()

func _physics_process(delta: float) -> void:
	if not visible: return
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if Input.is_action_pressed("MoveForward"):
		apply_central_impulse((Vector2.RIGHT * LINEAR_SPEED).rotated(rotation))
	elif Input.is_action_pressed("MoveBackward"):
		apply_central_impulse(-(Vector2.RIGHT * LINEAR_SPEED).rotated(rotation))
	if Input.is_action_pressed("RotateClockwise"):
		angular_velocity = ANGULAR_SPEED * delta
	if Input.is_action_pressed("RotateCounterclockwise"):
		angular_velocity = -ANGULAR_SPEED * delta
	
	if Input.is_action_just_pressed("Shoot"):
		shoot.emit()

## called by bullet scenes that hit the player
func die() -> void:
	visible = false
