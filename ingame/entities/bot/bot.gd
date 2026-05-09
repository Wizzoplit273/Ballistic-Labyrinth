extends RigidBody2D

## those variables are only used outside this script, in the level scene node
var bot_friendly_fire: bool = true

@export var LINEAR_SPEED: float = 200.0
@export var ANGULAR_SPEED: float = 320.0
@export var BULLET_SPAWN_OFFSET: float = 30.0
@export var MAX_BULLET_COUNT: int = 5
@export var ROTATION_INTERPOLATION_WEIGHT: float = 0.15
@export var ANGLE_DILATION: float = 0.1

@onready var TARGET_DESIRED_DISTANCE: float = $NavigationAgent.target_desired_distance

## updated by the parent level scene
var bullet_count: int = 0
var player_node: RigidBody2D = null
var is_adjacent_wall_to_player: bool = false
var is_dodging_bullets: bool = false
var DEBUG_is_showing_dodging: bool = false

signal shoot(owner_node: RigidBody2D)
func _ready() -> void:
	$NavigationAgent.max_speed = LINEAR_SPEED

const MAX_STUCK_POSITION_CHANGE: float = 2.0
const MAX_STUCK_ROTATION_CHANGE: float = 0.1
const MAX_SHOOT_ANGLE_DIFFERENCE: float = 0.4

#const BASE_WEIGHT: float = 1.0
#const ENEMY_WEIGHT: float = 2.0
#var current_navigation_region: RID = RID()

var previous_position: Vector2 = Vector2.ZERO
var previous_rotation: float = 0.0

var is_reversing: bool = false
func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server(): return
	if not visible: return
	$Rest/FixedRotation.rotation = -rotation
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	$NavigationAgent.target_position = player_node.global_position
	
	#if player_node.get_node("Rest").visible: $NavigationAgent.process_mode = Node.PROCESS_MODE_INHERIT
	#else: $NavigationAgent.process_mode = Node.PROCESS_MODE_DISABLED
	$Rest/DEBUGLeftBulletDot.visible = false
	$Rest/DEBUGRightBulletDot.visible = false
	check_nearby_bullets()
	var is_velocity_stuck: bool = (previous_position - position).length() <= MAX_STUCK_POSITION_CHANGE
	var is_angle_stuck: bool = abs(previous_rotation- rotation) <= MAX_STUCK_ROTATION_CHANGE
	var is_stuck: bool = is_velocity_stuck and is_angle_stuck
	if not is_reversing and not $NavigationAgent.is_target_reached() and is_stuck:
		is_stuck = false
		is_reversing = true
		$WallStuckCooldown.start()
	elif $WallStuckCooldown.is_stopped(): is_reversing = false
	if is_reversing and is_stuck:
		is_stuck = false
		is_reversing = false
		$WallStuckCooldown.stop()
	if is_dodging_bullets:
		is_reversing = false
		$WallStuckCooldown.stop()
	if $NavigationAgent.is_target_reached() and is_adjacent_wall_to_player:
		$NavigationAgent.target_desired_distance = 0.0
	else: $NavigationAgent.target_desired_distance = TARGET_DESIRED_DISTANCE
	if $NavigationAgent.is_navigation_finished() and not is_adjacent_wall_to_player and not is_dodging_bullets:
		if not player_node.get_node("Rest").visible: return
		var auxiliary: float = rotation
		var direction_to_player: float
		look_at(player_node.position)
		direction_to_player = rotation
		rotation = auxiliary
		rotation = lerp_angle(rotation, direction_to_player, ROTATION_INTERPOLATION_WEIGHT * 2)
		if abs(rotation - direction_to_player) <= MAX_SHOOT_ANGLE_DIFFERENCE and $ShootingCooldown.is_stopped():
			$ShootingCooldown.start()
			shoot.emit(self, "regular")
		return
	var next_point: Vector2 = $NavigationAgent.get_next_path_position()
	var direction: Vector2 = (next_point - global_position).normalized()
	if player_node.get_node("Rest").visible:
		rotation = lerp_angle(rotation, direction.angle(), ROTATION_INTERPOLATION_WEIGHT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if player_node.get_node("Rest").visible or is_dodging_bullets: 
		rotation += rng.randf_range(-ANGLE_DILATION, ANGLE_DILATION)
		linear_velocity = Vector2.RIGHT.rotated(rotation) * LINEAR_SPEED * (1 - int(is_reversing) * 2)
	previous_position = position
	previous_rotation = rotation

func check_nearby_bullets() -> void:
	is_dodging_bullets = false
	for bullet: CollisionObject2D in $Rest/BulletDetectionArea.get_overlapping_bodies():
		if is_bullet_dangerous(bullet):
			is_dodging_bullets = true
			dodge_bullet(bullet)

@export var BULLET_DANGER_SENSITIVITY: float = 0.4
#@export var DODGE_SPEED: float = 200.0
func is_bullet_dangerous(bullet: RigidBody2D) -> bool:
	if bullet == null: return false
	if bullet.get_meta("type", "NULL") != "bullet": return false
	if bullet.owner_node != self:
		if bullet.owner_node.get_meta("type", "NULL") == "enemy":
			if not bot_friendly_fire: return false
	if (previous_position - position).length() == 0.0:
		if not bullet.has_node("VelocityRaycast"): return false
		var is_raycast_hitting_enemy: bool = bullet.get_node("VelocityRaycast").get_collider() == self
		if not is_raycast_hitting_enemy: return false
	var distance_to_enemy: Vector2 = global_position - bullet.global_position
	var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	## dot product is positive if bullet is moving towards the enemy
	return distance_to_enemy.normalized().dot(bullet_velocity_direction) > BULLET_DANGER_SENSITIVITY

## whether it's a bullet is verified by the is_bullet_dangerous() function
const PERPENDICULAR_VELOCITY_DOT_OFFSET: float = 50.0
#const MAX_BULLET_STOP_DISTANCE: float = 20.0
func dodge_bullet(bullet: RigidBody2D) -> void:
	var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	var left_bullet_dot: Vector2 = bullet.global_position
	var right_bullet_dot: Vector2 = bullet.global_position
	var left_offset_vector: Vector2 = Vector2(PERPENDICULAR_VELOCITY_DOT_OFFSET, 0).rotated(bullet_velocity_direction.angle() - PI/2)
	left_bullet_dot += left_offset_vector
	right_bullet_dot -= left_offset_vector
	if DEBUG_is_showing_dodging:
		$Rest/DEBUGLeftBulletDot.global_position = left_bullet_dot
		$Rest/DEBUGRightBulletDot.global_position = right_bullet_dot
		$Rest/DEBUGLeftBulletDot.visible = true
		$Rest/DEBUGRightBulletDot.visible = true
	var chosen_direction: Vector2
	
	var navigation_path: PackedVector2Array
	$NavigationAgent.target_desired_distance = 0.0
	## left bullet dot navigation distance
	$NavigationAgent.target_position = left_bullet_dot
	navigation_path = $NavigationAgent.get_current_navigation_path()
	var navigation_distance_to_left: float = 0.0
	for i: int in range(navigation_path.size() - 1):
		navigation_distance_to_left += navigation_path[i].distance_to(navigation_path[i + 1])
	## right bullet dot navigation distance
	$NavigationAgent.target_position = right_bullet_dot
	navigation_path = $NavigationAgent.get_current_navigation_path()
	var navigation_distance_to_right: float = 0.0
	for i: int in range(navigation_path.size() - 1):
		navigation_distance_to_right += navigation_path[i].distance_to(navigation_path[i + 1])
	## final navigation distance
	$NavigationAgent.target_position = player_node.global_position
	var left_is_closer_than_right_navigation: bool = navigation_distance_to_left < navigation_distance_to_right
	var left_is_closer_than_right_euclidean: bool = global_position.distance_to(left_bullet_dot) < global_position.distance_to(right_bullet_dot)
	#var is_bullet_area_hitting_enemy: bool = false
	#for body: CollisionObject2D in bullet.get_node("EnemyDodgeRadius").get_overlapping_bodies():
		#if body == self: is_bullet_area_hitting_enemy = true
	#if not is_bullet_area_hitting_enemy: return
	#if abs(global_position - bullet.global_position).length() <= MAX_BULLET_STOP_DISTANCE: return
	if navigation_distance_to_left != navigation_distance_to_right:
		if left_is_closer_than_right_navigation:
			chosen_direction = left_bullet_dot
			#for body: CollisionObject2D in get_colliding_bodies():
				#if body.get_meta("id", "NULL") == "wall":
					#chosen_direction = right_bullet_dot
					#$WallDodgeEvadeCooldown.start()
			#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = right_bullet_dot
		else:
			chosen_direction = right_bullet_dot
			#for body: CollisionObject2D in get_colliding_bodies():
				#if body.get_meta("id", "NULL") == "wall":
					#chosen_direction = left_bullet_dot
					#$WallDodgeEvadeCooldown.start()
			#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = left_bullet_dot
	elif left_is_closer_than_right_euclidean:
		chosen_direction = left_bullet_dot
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = right_bullet_dot
				#$WallDodgeEvadeCooldown.start()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = right_bullet_dot
	else:
		chosen_direction = right_bullet_dot
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = left_bullet_dot
				#$WallDodgeEvadeCooldown.start()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = left_bullet_dot
	var auxiliary: float = rotation
	look_at(chosen_direction)
	var dodge_angle: float = rotation
	rotation = auxiliary
	rotation = lerp_angle(rotation, dodge_angle, ROTATION_INTERPOLATION_WEIGHT * 1.5)

# old dodge implementation number 2
### whether it's a bullet is verified by the is_bullet_dangerous() function
#const PERPENDICULAR_VELOCITY_DOT_OFFSET: float = 100.0
#func dodge_bullet(bullet: RigidBody2D) -> void:
	#var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	#var left_bullet_dot: Vector2 = bullet.global_position
	#var right_bullet_dot: Vector2 = bullet.global_position
	#var left_offset_vector: Vector2 = Vector2(PERPENDICULAR_VELOCITY_DOT_OFFSET, 0).rotated(bullet_velocity_direction.angle() - PI/2)
	#left_bullet_dot += left_offset_vector
	#right_bullet_dot -= left_offset_vector
	#if OS.is_debug_build() and Input.is_action_pressed("DEBUG_Show_Debug_Visuals"):
		#$Rest/DEBUGLeftBulletDot.global_position = left_bullet_dot
		#$Rest/DEBUGRightBulletDot.global_position = right_bullet_dot
		#$Rest/DEBUGLeftBulletDot.visible = true
		#$Rest/DEBUGRightBulletDot.visible = true
	#var chosen_direction: Vector2
	#var left_is_closer_than_right: bool = global_position.distance_to(left_bullet_dot) <= global_position.distance_to(right_bullet_dot)
	#var is_bullet_velocity_raycast_hitting_enemy: bool = bullet.get_node("VelocityRayCast").get_collider() == self
	#if left_is_closer_than_right:
		#chosen_direction = left_bullet_dot
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = right_bullet_dot
				#$WallDodgeEvadeCooldown.start()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = right_bullet_dot
	#else:
		#chosen_direction = right_bullet_dot
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = left_bullet_dot
				#$WallDodgeEvadeCooldown.start()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = left_bullet_dot
	#if is_bullet_velocity_raycast_hitting_enemy:
		#if chosen_direction == left_bullet_dot: chosen_direction = right_bullet_dot
		#elif chosen_direction == right_bullet_dot: chosen_direction = left_bullet_dot
	#var auxiliary: float = rotation
	#look_at(chosen_direction)
	#var dodge_angle: float = rotation
	#rotation = auxiliary
	#rotation = lerp_angle(rotation, dodge_angle, ROTATION_INTERPOLATION_WEIGHT)

# old dodge implementation number 1
### whether it's a bullet is verified by the is_bullet_dangerous() function
#const PERPENDICULAR_VELOCITY_DOT_OFFSET: float = 40.0
#func dodge_bullet(bullet: RigidBody2D) -> void:
	#var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	#var left_bullet_dot: Vector2 = bullet.global_position
	#var right_bullet_dot: Vector2 = bullet.global_position
	#var left_offset_vector: Vector2 = Vector2(PERPENDICULAR_VELOCITY_DOT_OFFSET, 0).rotated(bullet_velocity_direction.angle() - PI/2)
	#left_bullet_dot += left_offset_vector
	#right_bullet_dot -= left_offset_vector
	#if OS.is_debug_build() and Input.is_action_pressed("DEBUG_Show_Debug_Visuals"):
		#$Rest/DEBUGLeftBulletDot.global_position = left_bullet_dot
		#$Rest/DEBUGRightBulletDot.global_position = right_bullet_dot
		#$Rest/DEBUGLeftBulletDot.visible = true
		#$Rest/DEBUGRightBulletDot.visible = true
	#var dodge_left: Vector2 = Vector2(-bullet_velocity_direction.y, bullet_velocity_direction.x)
	#var dodge_right: Vector2 = Vector2(bullet_velocity_direction.y, -bullet_velocity_direction.x)
	#var chosen_direction: Vector2
	#if global_position.distance_to(left_bullet_dot) >= global_position.distance_to(right_bullet_dot):
		#chosen_direction = dodge_left
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = dodge_right
				#$WallDodgeEvadeCooldown.play()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = dodge_right
	#else:
		#chosen_direction = dodge_right
		#for body: CollisionObject2D in get_colliding_bodies():
			#if body.get_meta("id", "NULL") == "wall":
				#chosen_direction = dodge_left
				#$WallDodgeEvadeCooldown.play()
		#if not $WallDodgeEvadeCooldown.is_stopped(): chosen_direction = dodge_left
	#rotation = lerp_angle(rotation, chosen_direction.angle(), ROTATION_INTERPOLATION_WEIGHT)

signal level_die
## called by bullet scenes that hit the enemy
@rpc("reliable", "any_peer")
func die() -> void:
	if multiplayer.is_server(): rpc("die")
	$Rest.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	$DeathParticles.restart()
	if multiplayer.is_server(): level_die.emit()
