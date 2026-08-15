extends RigidBody2D

var controller: Node = null

var linear_speed: float = 200.0
var angular_speed: float = 6.0

func toggle(value: bool) -> void:
	if value:
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED

func _ready() -> void:
	$Sync.set_multiplayer_authority(1)
	if not multiplayer.is_server(): set_physics_process(false)

func _physics_process(_delta: float) -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if not controller: return
	angular_velocity = controller.angular_input * angular_speed
	var forward_direction := Vector2.RIGHT.rotated(rotation)
	linear_velocity = forward_direction * controller.linear_input * linear_speed
