extends RigidBody2D

signal despawn(RigidBody2D)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## initialised by parent level node right after instantiation:
## used for correcting the position of the bullet when it touches a wall in the first frame, in order
##		to prevent wall tunneling
var initial_velocity_direction: float
var initial_velocity_speed: float
var owner_node: RigidBody2D = null

var type: String

const ROCKET_TEXTURE_PATH: String = "res://ingame/entities/projectiles/bullet_rocket.png"
const ROCKET_SCALE_MODIFIER_TEXTURE: float = 4.2
const ROCKET_SCALE_MODIFIER_REST: float = 0.3
const TRAP_TEXTURE_PATH: String = "res://ingame/entities/projectiles/bullet_trap.png"
const TRAP_SCALE_MODIFIER_TEXTURE: float = 4.2
const TRAP_SCALE_MODIFIER_REST: float = 0.4
func modified_ready() -> void:
	apply_central_impulse(Vector2(initial_velocity_speed, 0).rotated(initial_velocity_direction))
	if type == "rocket":
		$Rest/Image.texture = load(ROCKET_TEXTURE_PATH)
		$Rest/Image.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_TEXTURE
		$Hitbox.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_REST
		$Rest.scale = Vector2.ONE * ROCKET_SCALE_MODIFIER_REST
	if type == "trap":
		$Rest/Image.texture = load(TRAP_TEXTURE_PATH)
		$Rest/Image.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_TEXTURE
		$Hitbox.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_REST
		$Rest.scale = Vector2.ONE * TRAP_SCALE_MODIFIER_REST
		$AnimationPlayer.play("hide_trap")
	$LifespanTimer.start()

const ROCKET_MAX_TURN_SPEED: float = 0.2
func _physics_process(_delta: float) -> void:
	linear_velocity = linear_velocity.normalized() * initial_velocity_speed
	if type == "rocket":
		var random_turn: float = rng.randf_range(-ROCKET_MAX_TURN_SPEED, ROCKET_MAX_TURN_SPEED)
		linear_velocity = linear_velocity.rotated(random_turn)
	$Rest/VelocityRaycast.rotation = linear_velocity.angle() - PI/2
	$Rest/Image.rotation = linear_velocity.angle()

func _on_lifespan_timer_timeout() -> void:
	die("lifespan")
	despawn.emit(self)

func _on_body_entered(body: Node) -> void:
	if not $Rest.visible: return
	if body.get_meta("type", "NULL") == "wall":
		if type != "laser": $BounceRegular.play()
		else: $BounceLaser.play()
	if body.get_meta("type", "NULL") == "player":
		body.die()
		die("tank")
	if body.get_meta("type", "NULL") == "enemy":
		if body.enemy_friendly_fire == true or owner_node == body or owner_node.get_meta("type", "NULL") == "player":
			body.die()
		die("tank")
	if body.get_meta("type", "NULL") == "bullet":
		body.die("bullet")
		die("bullet")

func _on_wall_tunnel_proof_body_entered(body: Node2D) -> void:
	if not $WallTunnelProofTimer.is_stopped():
		die("tunnel_proof")

func disable_process_mode() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED

func die(cause: String) -> void:
	$Rest.visible = false
	call_deferred("disable_process_mode")
	if cause == "lifespan":
		despawn.emit(self)
		queue_free()
		return
	if cause == "tunnel_proof":
		despawn.emit(self)
		queue_free()
		return
	if cause == "tank":
		despawn.emit(self)
		$DespawnParticles.restart()
		return
	if cause == "bullet":
		despawn.emit(self)
		$DespawnParticles.restart()
		$BulletHit.play()
		return

func _on_despawn_particles_finished() -> void:
	queue_free()
