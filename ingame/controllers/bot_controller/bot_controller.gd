extends Node2D

var sid: int = 0
var pawn: Node2D = null

func set_sid(id: int) -> void:
	if id >= 0: return
	sid = id

func set_pawn() -> void:
	if pawn == null: return

## if < 0 move backwards
## if = 0 idle
## if > 0 move forwards
var linear_input: int = 0

## if < 0 rotate counterclockwise
## if = 0 idle
## if > 0 rotate clockwise
var angular_input: int = 0

var is_drifting: bool = false

var target: Node2D = null
var is_adjacent_wall_to_target: bool = false ## determined by IngameManager.ingame
var is_dodging_bullets: bool = false

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server(): return
	if pawn == null: return
	global_position = pawn.global_position
	rotation = pawn.rotation
	if not pawn.get_node(^"Rest").visible: return
	determine_target()
	check_nearby_bullets()
	configure_patrol()
	if target == self: return
	point_to_target_if_seen()
	configure_process_mode()
	configure_debug()
	configure_reversing()
	if ($NavAgent.is_target_reached() and is_adjacent_wall_to_target):
		if not target is StaticBody2D: $NavAgent.target_desired_distance = 1000.0
	elif target is StaticBody2D:
		$NavAgent.target_desired_distance = CRATE_DESIRED_DISTANCE
	else: $NavAgent.target_desired_distance = TARGET_DESIRED_DISTANCE
	if $NavAgent.is_navigation_finished() and not is_adjacent_wall_to_target and not is_dodging_bullets:
		if not target is Area2D:
			var was_patroling: bool = is_patrol_set
			is_patrol_set = false
			if not target.get_node("Rest").visible: return
			var auxiliary: float = rotation
			var direction_to_player: float
			look_at(target.position)
			direction_to_player = rotation
			rotation = auxiliary
			var direction_deviation: float = randf_range(-DIRECTION_DEVIATION, DIRECTION_DEVIATION)
			rotation = lerp_angle(rotation, direction_to_player+direction_deviation, ROTATION_INTERPOLATION_WEIGHT * 2)
			if abs(rotation - direction_to_player) <= MAX_SHOOT_ANGLE_DIFFERENCE and $ShootingCooldown.is_stopped():
				if not was_patroling:
					$ShootingCooldown.start()
					direction_deviation = randf_range(-DIRECTION_DEVIATION, DIRECTION_DEVIATION)
					rotation += direction_deviation
					shoot.emit(self, weapon_type)
			return
	var next_point: Vector2 = $NavAgent.get_next_path_position()
	var direction: Vector2 = (next_point - global_position).normalized()
	if target.get_node("Rest").visible:
		rotation = lerp_angle(rotation, direction.angle(), ROTATION_INTERPOLATION_WEIGHT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if target.get_node("Rest").visible or is_dodging_bullets:
		rotation += rng.randf_range(-ANGLE_DILATION, ANGLE_DILATION)
		linear_velocity = Vector2.RIGHT.rotated(rotation) * LINEAR_SPEED * (1 - int(is_reversing) * 2)
	#if position.distance_to($NavAgent.get_next_path_position()) <= PATH_STUCK_DISTANCE:
	if not $PathStuckDelay.is_stopped():
		initial_path_stuck_distance = position.distance_to($NavAgent.get_next_path_position())
		$PathStuckDelay.start()
	previous_position = position
	previous_rotation = rotation

#func _ready() -> void:
	#$NavAgent.max_speed = LINEAR_SPEED

@onready var TARGET_DESIRED_DISTANCE: float = $NavAgent.target_desired_distance
const CRATE_DESIRED_DISTANCE: float = 5.0
const TARGET_PATROL_DISTANCE: float = 300.0

const MAX_STUCK_POSITION_CHANGE: float = 2.0
const MAX_STUCK_ROTATION_CHANGE: float = 0.1
const MAX_SHOOT_ANGLE_DIFFERENCE: float = 0.4

var previous_position: Vector2 = Vector2.ZERO
var previous_rotation: float = 0.0

func point_to_target_if_seen() -> void:
	if target == self: return
	for ray: RayCast2D in $Rest/PlayerDetectors.get_children():
		if ray.get_collider() != target: continue
		$NavAgent.target_position = target.global_position
		if position.distance_to(target.global_position) >= FLANK_RADIUS:
			is_patrol_set = true
		else: is_patrol_set = false
		return

var FLANK_RESET: float = 1100.0
var FLANK_RADIUS: float = 300.0
var FLANK_MIN_INTERVAL: float = 100.0
var FLANK_MAX_INTERVAL: float = 400.0
var FLANK_FRONT_DISTANCE: float = 400.0
const DIRECTION_DEVIATION: float = PI/180*10
var is_patrol_set: bool = false
var is_reversing: bool = false

func determine_target() -> void:
	target = null
	for tank: RigidBody2D in IngameManager.ingame.get_node(^"TankPawns").get_children():
		if tank == pawn: continue
		if tank.get_node("Rest").visible == false: continue
		if position.distance_to(tank.position) < position.distance_to(target.position):
			target = tank
	for crate: Area2D in IngameManager.ingame.get_node(^"Crates").get_children():
		if crate.type == "trap": continue # temporary
		if position.distance_to(crate.position) < position.distance_to(target.position):
			target = crate
	if target == null: return # may need some more code at this if statement
	if is_patrol_set: return
	if target.get_meta("entity_type", "null") == "crate":
		$NavAgent.target_desired_distance = CRATE_DESIRED_DISTANCE
	else: $NavAgent.target_desired_distance = TARGET_DESIRED_DISTANCE

var is_path_stuck: bool = false
func configure_patrol() -> void:
	if target == null:
		$NavAgent.target_position = position
		is_patrol_set = false
		return
	if is_path_stuck:
		is_path_stuck = false
		$NavAgent.target_position = target.position
		is_patrol_set = true
		return
	if position.distance_to(target.global_position) >= FLANK_RESET:
		$NavAgent.target_position = target.global_position
		is_patrol_set = false
	elif position.distance_to(target.global_position) >= FLANK_RADIUS:
		if is_patrol_set: return ## ensures that this block only executes once when it detects a change in radius
		var random_sign: float
		var random_x: float = randf_range(FLANK_MIN_INTERVAL, FLANK_MAX_INTERVAL)
		random_sign = sign(randi_range(0,1))*2-1
		random_x *= random_sign
		var random_y: float = randf_range(FLANK_MIN_INTERVAL, FLANK_MAX_INTERVAL)
		random_sign = sign(randi_range(0,1))*2-1
		random_y *= random_sign
		var random_offset: Vector2 = Vector2(random_x, random_y)
		$NavAgent.target_position = target.global_position + random_offset
		if target.linear_velocity.length() >= 0.1:
			var offset: Vector2 = Vector2(FLANK_FRONT_DISTANCE, 0)
			$NavAgent.target_position += offset * target.linear_velocity.angle()
		is_patrol_set = true
	else:
		$NavAgent.target_position = target.global_position
		is_patrol_set = false
	if is_patrol_set: $NavAgent.target_desired_distance = TARGET_PATROL_DISTANCE
	else: $NavAgent.target_desired_distance = TARGET_DESIRED_DISTANCE

func configure_reversing() -> void:
	var is_velocity_stuck: bool = (previous_position - position).length() <= MAX_STUCK_POSITION_CHANGE
	var is_angle_stuck: bool = abs(previous_rotation - rotation) <= MAX_STUCK_ROTATION_CHANGE
	var is_stuck: bool = is_velocity_stuck and is_angle_stuck
	if not is_reversing and not $NavAgent.is_target_reached() and is_stuck:
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

func configure_nav_agent_process() -> void:
	if target == null: $NavAgent.process_mode = Node.PROCESS_MODE_DISABLED
	else: $NavAgent.process_mode = Node.PROCESS_MODE_INHERIT

func check_nearby_bullets() -> void:
	is_dodging_bullets = false
	for bullet: CollisionObject2D in $BulletDetectionArea.get_overlapping_bodies():
		if not is_bullet_dangerous(bullet): return
		is_dodging_bullets = true
		dodge_bullet(bullet)

@export var BULLET_DANGER_SENSITIVITY: float = 0.3
#@export var DODGE_SPEED: float = 200.0
func is_bullet_dangerous(bullet: RigidBody2D) -> bool:
	if bullet == null: return false
	if bullet.get_meta("entity_type", "NULL") != "bullet": return false
	if (previous_position - position).length() == 0.0:
		#if not bullet.has_node("VelocityRaycast"): return false
		var is_raycast_hitting_bot: bool = bullet.get_node(^"Rest/VelocityRaycast1").get_collider() == self
		is_raycast_hitting_bot = is_raycast_hitting_bot or bullet.get_node(^"Rest/VelocityRaycast2").get_collider() == self
		is_raycast_hitting_bot = is_raycast_hitting_bot or bullet.get_node(^"Rest/VelocityRaycast3").get_collider() == self
		if not is_raycast_hitting_bot: return false
	var distance_to_bot: Vector2 = global_position - bullet.global_position
	var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	## dot product is positive if bullet is moving towards the bot
	return distance_to_bot.normalized().dot(bullet_velocity_direction) > BULLET_DANGER_SENSITIVITY

## whether it's a bullet is verified by the is_bullet_dangerous() function
const PERPENDICULAR_VELOCITY_DOT_OFFSET: float = 75.0
#const MAX_BULLET_STOP_DISTANCE: float = 20.0
func dodge_bullet(bullet: RigidBody2D) -> void:
	var bullet_velocity_direction: Vector2 = bullet.linear_velocity.normalized()
	var left_bullet_dot: Vector2 = bullet.global_position
	var right_bullet_dot: Vector2 = bullet.global_position
	var left_offset_vector: Vector2 = Vector2(PERPENDICULAR_VELOCITY_DOT_OFFSET, 0).rotated(bullet_velocity_direction.angle() - PI/2)
	left_bullet_dot += left_offset_vector
	right_bullet_dot -= left_offset_vector
	var chosen_direction: Vector2
	
	$NavAgent.target_desired_distance = 0.0
	## left bullet dot navigation distance
	$NavAgent.target_position = left_bullet_dot
	var navigation_path: PackedVector2Array = $NavAgent.get_current_navigation_path()
	var navigation_distance_to_left: float = 0.0
	for i: int in range(navigation_path.size() - 1):
		navigation_distance_to_left += navigation_path[i].distance_to(navigation_path[i + 1])
	## right bullet dot navigation distance
	$NavAgent.target_position = right_bullet_dot
	navigation_path = $NavAgent.get_current_navigation_path()
	var navigation_distance_to_right: float = 0.0
	for i: int in range(navigation_path.size() - 1):
		navigation_distance_to_right += navigation_path[i].distance_to(navigation_path[i + 1])
	## final navigation distance
	$NavAgent.target_position = target.global_position
	var left_is_closer_than_right_navigation: bool = navigation_distance_to_left < navigation_distance_to_right
	var left_is_closer_than_right_euclidean: bool = global_position.distance_to(left_bullet_dot) < global_position.distance_to(right_bullet_dot)
	#var is_bullet_area_hitting_bot: bool = false
	#for body: CollisionObject2D in bullet.get_node("EnemyDodgeRadius").get_overlapping_bodies():
		#if body == self: is_bullet_area_hitting_bot = true
	#if not is_bullet_area_hitting_bot: return
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
