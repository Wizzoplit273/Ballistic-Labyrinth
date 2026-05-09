extends RigidBody2D

signal despawn(RigidBody2D)

const FALLBACK_OFFSET: float = 500.0

## initialised by parent level node right after instantiation:
## used for correcting the position of the bullet when it touches a wall in the first frame, in order
##		to prevent wall tunneling
var initial_velocity_direction: float

func _on_lifespan_timer_timeout() -> void:
	despawn.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.get_meta("id", "NULL") == "player":
		body.die()
		despawn.emit(self)

func _on_wall_tunnel_proof_body_entered(body: Node2D) -> void:
	if not $WallTunnelProofTimer.is_stopped():
		despawn.emit(self)
