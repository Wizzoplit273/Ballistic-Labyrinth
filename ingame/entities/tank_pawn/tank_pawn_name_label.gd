extends Label

func _process(_delta: float) -> void:
	rotation = -get_parent().rotation

const FADE_DURATION: float = 1.5
func _ready() -> void:
	create_tween().tween_property(self, ^"modulate:a", 0.0, FADE_DURATION)
