extends CharacterBody2D

const LINEAR_SPEED: float = 0.2
const ANGULAR_SPEED: float = 4.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("MoveForward"):
		position += (Vector2.RIGHT * LINEAR_SPEED).rotated(rotation)
	elif Input.is_action_pressed("MoveBackward"):
		position -= (Vector2.RIGHT * LINEAR_SPEED).rotated(rotation)
	if Input.is_action_pressed("RotateClockwise"):
		rotation += ANGULAR_SPEED * delta
	if Input.is_action_pressed("RotateCounterclockwise"):
		rotation -= ANGULAR_SPEED * delta
