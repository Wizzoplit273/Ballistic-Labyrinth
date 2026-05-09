extends RigidBody2D

signal despawn(RigidBody2D)

func _on_lifespan_timer_timeout() -> void:
	despawn.emit(self)
