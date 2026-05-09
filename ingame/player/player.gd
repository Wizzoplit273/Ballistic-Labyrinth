extends RigidBody2D

const LINEAR_SPEED: float = 200.0
const ANGULAR_SPEED: float = 300.0

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
