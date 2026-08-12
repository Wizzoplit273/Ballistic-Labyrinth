class_name PlayerController
extends Node

var pawn: Node = null

var sid: int = 0:
	set(id):
		if id <= 0: return
		sid = id
		$Sync.set_multiplayer_authority(id)

func update_pawn() -> void:
	if pawn == null: return

## if < 0 move backwards
## if = 0 idle
## if > 0 move forwards
var linear_input: int = 0

## if < 0 rotate counterclockwise
## if = 0 idle
## if > 0 rotate clockwise
var angular_input: int = 0
