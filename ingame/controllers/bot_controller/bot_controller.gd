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

#func _process(_delta: float) -> void:
	#if is_queued_for_deletion(): return
	#for instance: RigidBody2D in $Bots.get_children():
		#instance.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
		#if instance.target == null: continue
		#var target_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local(instance.target.position))
		#var bot_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local(instance.position))
		#instance.is_adjacent_wall_to_target = is_wall_between_cells(target_cell, bot_cell, 2, true)
