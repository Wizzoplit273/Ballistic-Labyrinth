extends Control

func get_session_id() -> int:
	return session_id_ui.text.to_int()

func get_username() -> String:
	return username_ui.text

func get_color() -> Color:
	return texture_ui.modulate

func get_kills() -> int:
	return kills_ui.text.to_int()

func get_score() -> int:
	return score_ui.text.to_int()

@onready var session_id_ui: Label = $Container/SessionIDLabel
@onready var username_ui: Label = $Container/UsernameLabel
@onready var texture_ui: TextureRect = $Container/TankTexture
@onready var kills_ui: Label = $Container/KillsScoreContainer/KillsLabel
@onready var score_ui: Label = $Container/KillsScoreContainer/ScoreLabel

func update(profile_key: int, profile: Dictionary) -> void:
	set_session_id(profile_key)
	set_username(profile["name"])
	set_color(profile["color"])
	set_kills(profile["kills"])
	set_score(profile["score"])

func set_session_id(sid: int) -> void:
	$Container/SessionIDLabel.text = str(sid)

func set_username(username: String) -> void:
	$Container/UsernameLabel.text = username

func set_color(color: Color) -> void:
	$Container/TankTexture.modulate = color

func set_kills(kills: int) -> void:
	$Container/KillsScoreContainer/KillsLabel.text = str(kills)

func set_score(score: int) -> void:
	$Container/KillsScoreContainer/ScoreLabel.text = str(score)
