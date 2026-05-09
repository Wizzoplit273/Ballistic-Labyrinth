extends Area2D

## self variables determind by the level scene:
## position

## these variables will be set by the level scene
# no such variables for now

## the dictionary is only going to be used for selecting a random type:
## managing types by integer IDs is kinda bad when adding dozens of weapons
const TYPE_DICTIONARY: Dictionary = {
	1: "laser",
	2: "rocket",
	3: "trap"
}

var type: String = "NULL"

const TEXTURE_PATH_PREFIX: String = "res://ingame/entities/crates/crate_"
const TEXTURE_EXTENSION: String = ".png"

## called by the level scene it's instantiated in
func modified_ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	type = TYPE_DICTIONARY[rng.randi_range(1, TYPE_DICTIONARY.size())]
	$Image.texture = load(TEXTURE_PATH_PREFIX + type + TEXTURE_EXTENSION)
	rotation = rng.randf_range(-PI, PI)
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true

signal equip_weapon(player: RigidBody2D, type: String)
func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("type", "NULL") != "player": return
	equip_weapon.emit(body, type)
	queue_free()
