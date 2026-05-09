extends RigidBody2D

signal shoot

const LINEAR_SPEED: float = 150.0
const ANGULAR_SPEED: float = 300.0
const BULLET_SPAWN_OFFSET: float = 30.0
const BULLET_SPEED: float = 350.0
const MAX_BULLET_COUNT: int = 5
const ROTATION_INTERPOLATION_WEIGHT: float = 0.05
@onready var TARGET_DESIRED_DISTANCE: float = $NavigationAgent.target_desired_distance

## updated by the parent level scene
var bullet_count: int = 0
var player_node: RigidBody2D
var is_adjacent_wall_to_player: bool = false

func _ready() -> void:
	$NavigationAgent.max_speed = LINEAR_SPEED

func _physics_process(_delta: float) -> void:
	if not visible: return
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	if $NavigationAgent.is_target_reached() and is_adjacent_wall_to_player:
		$NavigationAgent.target_desired_distance = 0.0
	else: $NavigationAgent.target_desired_distance = TARGET_DESIRED_DISTANCE
	$NavigationAgent.target_position = player_node.global_position
	if $NavigationAgent.is_navigation_finished(): return
	var next_point: Vector2 = $NavigationAgent.get_next_path_position()
	var direction: Vector2 = (next_point - global_position).normalized()
	rotation = lerp_angle(rotation, direction.angle(), ROTATION_INTERPOLATION_WEIGHT)
	linear_velocity = Vector2.RIGHT.rotated(rotation) * LINEAR_SPEED

## called by bullet scenes that hit the enemy
func die() -> void:
	queue_free()
