extends RigidBody2D

signal despawn(RigidBody2D)

## initialised by parent level node right after instantiation:
## used for correcting the position of the bullet when it touches a wall in the first frame, in order
##		to prevent wall tunneling
var initial_velocity_direction: float
var owner_node: RigidBody2D = null

func _physics_process(_delta: float) -> void:
	$VelocityRaycast.rotation = linear_velocity.angle() - PI/2

func _on_lifespan_timer_timeout() -> void:
	die("lifespan")
	despawn.emit(self)

func _on_body_entered(body: Node) -> void:
	if not $Rest.visible: return
	if body.get_meta("type", "NULL") == "wall":
		$Bounce.play()
	if body.get_meta("type", "NULL") == "player" or body.get_meta("type", "NULL") == "enemy":
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
