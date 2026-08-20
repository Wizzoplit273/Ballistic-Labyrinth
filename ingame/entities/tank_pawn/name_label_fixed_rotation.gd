extends Label

func _process(_delta: float) -> void:
	rotation = -get_parent().rotation
