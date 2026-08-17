extends RigidBody2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## initialised by parent level node right after instantiation:
## used for correcting the position of the bullet when it touches a wall in the first frame, in order
##		to prevent wall tunneling
var initial_velocity_direction: float
var initial_velocity_speed: float
var owner_node: RigidBody2D = null

var room_node: Node2D = null

var target: Node2D = null

var type: String

const ROCKET_TEXTURE_PATH: String = "res://ingame/entities/projectiles/bullet_rocket.png"
const ROCKET_SCALE_MODIFIER_TEXTURE: float = 4.2
const ROCKET_SCALE_MODIFIER_REST: float = 0.3
const TRAP_TEXTURE_PATH: String = "res://ingame/entities/projectiles/bullet_trap.png"
const TRAP_SCALE_MODIFIER_TEXTURE: float = 4.2
const TRAP_SCALE_MODIFIER_REST: float = 0.4
func _ready() -> void:
	if multiplayer.is_server(): process_mode = Node.PROCESS_MODE_INHERIT
	else: process_mode = Node.PROCESS_MODE_DISABLED
	apply_central_impulse(Vector2(initial_velocity_speed, 0).rotated(initial_velocity_direction))
	if type == "rocket":
		$RocketNavigation.process_mode = Node.PROCESS_MODE_INHERIT
		$Rest/Image.texture = load(ROCKET_TEXTURE_PATH)
		$Rest/Image.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_TEXTURE
		$Hitbox.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_REST
		$Rest.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_REST
		$RocketDelay.start()
	if type == "trap":
		$Rest/Image.texture = load(TRAP_TEXTURE_PATH)
		$Rest/Image.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_TEXTURE
		$Hitbox.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_REST
		$Rest.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_REST
		$AnimationPlayer.play("hide_trap")
	$LifespanTimer.start()

func determine_closest_target() -> void:
	var result: Node2D = owner_node
	for player: RigidBody2D in room_node.get_node("Players").get_children():
		if player.get_node("Rest").visible == false: continue
		if result.get_node("Rest").visible == false:
			result = player
			continue
		if position.distance_to(player.position) <= position.distance_to(result.position):
			result = player
	for bot: RigidBody2D in room_node.get_node("Bots").get_children():
		if bot.get_node("Rest").visible == false: continue
		if result.get_node("Rest").visible == false:
			result = bot
			continue
		if position.distance_to(bot.position) <= position.distance_to(result.position):
			result = bot
	$RocketNavigation.target_position = result.position
	target = result

func _on_rocket_delay_timeout() -> void:
	$RocketActivate.play()

const ROCKET_MAX_TURN_SPEED: float = 0.04
func configure_if_rocket() -> void:
	if type != "rocket": return
	if not $RocketDelay.is_stopped(): return
	#var random_turn: float = rng.randf_range(-ROCKET_MAX_TURN_SPEED, ROCKET_MAX_TURN_SPEED)
	#linear_velocity = linear_velocity.rotated(random_turn)
	determine_closest_target()
	var next_point: Vector2 = $RocketNavigation.get_next_path_position()
	var direction: Vector2 = (next_point - global_position).normalized()
	var proper_rotation: float = linear_velocity.angle()
	if target != null:
		$Rest/RocketTrail.emitting = target.get_node("Rest").visible
		if target.get_node("Rest").visible:
			proper_rotation = lerp_angle(proper_rotation, direction.angle(), ROCKET_MAX_TURN_SPEED)
	linear_velocity = (Vector2.RIGHT * linear_velocity.length()).rotated(proper_rotation)

func set_node_rotations() -> void:
	$Rest/VelocityRaycast1.rotation = linear_velocity.angle() - PI/2
	$Rest/VelocityRaycast2.rotation = linear_velocity.angle() - PI/2 - PI/60
	$Rest/VelocityRaycast3.rotation = linear_velocity.angle() - PI/2 + PI/60
	$Rest/Image.rotation = linear_velocity.angle()

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() != 0.0: linear_velocity = linear_velocity.normalized() * initial_velocity_speed
	configure_if_rocket()
	set_node_rotations()

func _on_lifespan_timer_timeout() -> void:
	die("lifespan")

func _on_body_entered(body: Node) -> void:
	if not $Rest.visible: return
	if body.get_meta("type", "NULL") == "wall":
		if type != "laser": MasterManager.play_server_sound($BounceRegular)
		else: MasterManager.play_server_sound($BounceLaser)
	if body.get_meta("type", "NULL") == "player":
		body.die()
		die("tank")
	if body.get_meta("type", "NULL") == "bot":
		body.die()
		#if (body.bot_friendly_fire == true and owner_node != body) or owner_node == body:
			#body.die()
		die("tank")
	if body.get_meta("type", "NULL") == "bullet":
		body.die("bullet")
		die("bullet")

func disable_process_mode() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func die(cause: String) -> void:
	$Rest.visible = false
	call_deferred("disable_process_mode")
	if type != "trap": owner_node.fired_bullet_count -= 1
	if cause == "lifespan":
		queue_free()
		return
	if cause == "tank":
		$DespawnParticles.restart()
		return
	if cause == "bullet":
		$DespawnParticles.restart()
		MasterManager.play_server_sound($BulletHit)
		return

func _on_despawn_particles_finished() -> void:
	queue_free()
