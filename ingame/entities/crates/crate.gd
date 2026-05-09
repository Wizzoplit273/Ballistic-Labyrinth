extends Area2D

## self variables determind by the level scene:
## position

## these variables will be set by the level scene
# no such variables for now

var type: String = "NULL"

const TEXTURE_PATH_PREFIX: String = "res://ingame/entities/crates/crate_"
const TEXTURE_EXTENSION: String = ".png"

## called by the level scene it's instantiated in
func modified_ready() -> void:
	pass

signal equip_weapon(player: RigidBody2D, type: String)
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server(): return
	if body.get_meta("type", "NULL") != "player": return
	equip_weapon.emit(body, type)
	rpc_queue_free()

@rpc("reliable", "any_peer")
func rpc_queue_free() -> void:
	if multiplayer.is_server(): rpc("rpc_queue_free")
	queue_free()
