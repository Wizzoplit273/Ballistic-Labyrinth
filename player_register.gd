## A RefCounted object that stores an internal player instance for helping the server manage player connections and properties accessible outside ingame.
class_name PlayerRegister extends RefCounted

## Unique ID assigned by the server. Note that this class is a single player instance, so the unique ID is only verified outside by the server. An ID equal to 0 means it's uninitialized.
var id: int = 0
## Whether or not this player instance is a bot.
var is_bot: bool = false
## Actual username of the player instance. Two players may have the same username. A blank string is a valid username.
var given_name: String = ""
## Modulation value for the player's color. This property may be changed in the future.
var modulation: Color = Color.TRANSPARENT
## Amount of score points. May only be a non-negative integer.
var score: int = 0
## Amount of kill points. May only be a non-negative integer.
var kills: int = 0

## Foolproof ID setter. Passing a non-positive value to input will leave its current value unchanged and throw an error.
func set_id(input: int) -> void:
	if input <= 0:
		push_error("CUSTOM ERROR: trying to assign invalid id =", id, "for player")
		return
	id = input
