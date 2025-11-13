extends Control

func _on_min_maze_size_scroller_x_value_changed(value: float) -> void:
	if int(value) > $"..".max_maze_size.x:
		%MinMazeSizeScrollerX.value = $"..".max_maze_size.x
		return
	$"..".min_maze_size.x = int(value)
	%MinWidthLabel.text = "Width: " + str(int(value))
func _on_min_maze_size_scroller_y_value_changed(value: float) -> void:
	if int(value) > $"..".max_maze_size.y:
		%MinMazeSizeScrollerY.value = $"..".max_maze_size.y
		return
	$"..".min_maze_size.y = int(value)
	%MinHeightLabel.text = "Height: " + str(int(value))
func _on_max_maze_size_scroller_x_value_changed(value: float) -> void:
	if int(value) < $"..".min_maze_size.x:
		%MaxMazeSizeScrollerX.value = $"..".min_maze_size.x
		return
	$"..".max_maze_size.x = int(value)
	%MaxWidthLabel.text = "Width: " + str(int(value))
func _on_max_maze_size_scroller_y_value_changed(value: float) -> void:
	if int(value) < $"..".min_maze_size.y:
		%MaxMazeSizeScrollerY.value = $"..".min_maze_size.y
		return
	$"..".max_maze_size.y = int(value)
	%MaxHeightLabel.text = "Height: " + str(int(value))

func _on_min_enemy_count_scroller_value_changed(value: float) -> void:
	if int(value) > $"..".bot_count_interval.y:
		%MinEnemyCountScroller.value = $"..".bot_count_interval.y
		return
	$"..".bot_count_interval.x = int(value)
	%MinEnemyCountLabel.text = "Minimum: " + str(int(value))
func _on_max_enemy_count_collider_value_changed(value: float) -> void:
	if int(value) < $"..".bot_count_interval.x:
		%MaxEnemyCountScroller.value = $"..".bot_count_interval.x
		return
	$"..".bot_count_interval.y = int(value)
	%MaxEnemyCountLabel.text = "Maximum: " + str(int(value))
func _on_min_maze_wall_remove_scroller_value_changed(value: float) -> void:
	if int(value) > $"..".wall_remove_interval.y:
		%MinMazeWallRemoveScroller.value = $"..".wall_remove_interval.y
		return
	$"..".wall_remove_interval.x = int(value)
	%MinMazeWallRemoveLabel.text = "Minimum: " + str(int(value))
func _on_max_maze_wall_remove_scroller_value_changed(value: float) -> void:
	if int(value) < $"..".wall_remove_interval.x:
		%MaxMazeWallRemoveScroller.value = $"..".wall_remove_interval.x
		return
	$"..".wall_remove_interval.y = int(value)
	%MaxMazeWallRemoveLabel.text = "Maximum: " + str(int(value))

func _on_bot_friendly_fire_check_toggled(toggled_on: bool) -> void:
	$"..".bot_friendly_fire = toggled_on
	if toggled_on: %EnemyFriendlyFireLabel.text = "True"
	else: %EnemyFriendlyFireLabel.text = "False"

func _on_min_carve_offset_scroller_value_changed(value: float) -> void:
	if int(value) > $"..".maze_carve_offset.y:
		%MinCarveOffsetScroller.value = $"..".maze_carve_offset.y
		return
	$"..".maze_carve_offset.x = int(value)
	%MinCarveOffsetLabel.text = "Minimum: " + str(int(value))

func _on_max_carve_offset_scroller_value_changed(value: float) -> void:
	if int(value) < $"..".maze_carve_offset.x:
		%MaxCarveOffsetScroller.value = $"..".maze_carve_offset.x
		return
	$"..".maze_carve_offset.y = int(value)
	%MaxCarveOffsetLabel.text = "Maximum: " + str(int(value))

func _on_settings_to_main_menu_button_pressed() -> void:
	visible = false
	$"../MainMenu".activate(true)
