extends RigidBody2D

signal shoot

const LINEAR_SPEED: float = 150.0
const ANGULAR_SPEED: float = 300.0
const BULLET_SPAWN_OFFSET: float = 30.0
const BULLET_SPEED: float = 350.0
const MAX_BULLET_COUNT: int = 5
const ROTATION_INTERPOLATION_WEIGHT: float = 0.1
@onready var TARGET_DESIRED_DISTANCE: float = $NavigationAgent.target_desired_distance

## updated by the parent level scene
var bullet_count: int = 0
var player_node: RigidBody2D
var is_adjacent_wall_to_player: bool = false

func _ready() -> void:
	$NavigationAgent.max_speed = LINEAR_SPEED

const MAX_STUCK_POSITION_CHANGE: float = 0.7
var previous_position: Vector2 = Vector2.ZERO
var is_reversing: bool = false
func _physics_process(_delta: float) -> void:
	if not visible: return
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	$NavigationAgent.target_position = player_node.global_position
	if not $NavigationAgent.is_target_reached() and (previous_position - position).length() <= MAX_STUCK_POSITION_CHANGE:
		is_reversing = true
	else: is_reversing = false
	if $NavigationAgent.is_target_reached() and is_adjacent_wall_to_player:
		$NavigationAgent.target_desired_distance = 0.0
	else: $NavigationAgent.target_desired_distance = TARGET_DESIRED_DISTANCE
	if $NavigationAgent.is_navigation_finished() and not is_adjacent_wall_to_player:
		var auxiliary: float = rotation
		var direction_to_player: float
		look_at(player_node.position)
		direction_to_player = rotation
		rotation = auxiliary
		rotation = lerp_angle(rotation, direction_to_player, ROTATION_INTERPOLATION_WEIGHT * 2)
		return
	var next_point: Vector2 = $NavigationAgent.get_next_path_position()
	var direction: Vector2 = (next_point - global_position).normalized()
	rotation = lerp_angle(rotation, direction.angle(), ROTATION_INTERPOLATION_WEIGHT)
	linear_velocity = Vector2.RIGHT.rotated(rotation) * LINEAR_SPEED * (1 - int(is_reversing) * 2)
	previous_position = position

## called by bullet scenes that hit the enemy
func die() -> void:
	visible = false
