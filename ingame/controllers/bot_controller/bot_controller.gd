extends Node

var sid: int = 0
var pawn: Node = null

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
var is_shooting: bool = false
