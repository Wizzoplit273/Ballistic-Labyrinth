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
@export var linear_input: int = 0

## if < 0 rotate counterclockwise
## if = 0 idle
## if > 0 rotate clockwise
@export var angular_input: int = 0

func _ready() -> void:
	set_process(is_multiplayer_authority())

func _process(_delta: float) -> void:
	linear_input = int(Input.get_axis(&"MoveBackward", &"MoveForward"))
	angular_input = int(Input.get_axis(&"RotateCounterclockwise", &"RotateClockwise"))
