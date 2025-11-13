extends Node2D

#func server_randf_range(min_value: float, max_value: float) -> void:
	#if not multiplayer.is_server(): return
	#var value: float = rng.randf_range(min_value, max_value)
	#rpc("receive_randf_range", value)
#
#@rpc("reliable", "any_peer")
#func receive_randf_range(value: float) -> void:
	#

const FLOAT_MAX: float = 9223372036854775808.0

const REGULAR_BULLET_SPEED: float = 250.0
const INGAME_CAMERA_ZOOM: float = 2.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## those variables are modified by the origin scene(origin.tscn)
var DEBUG_is_checking_maze: bool = false
var DEBUG_is_showing_dodging: bool = false
var min_maze_size: Vector2i = Vector2i.ZERO
var max_maze_size: Vector2i = Vector2i.ZERO
var wall_remove_interval: Vector2i = Vector2i.ZERO
var bot_count_interval: Vector2i = Vector2i.ZERO
var bot_friendly_fire: bool = true
var maze_carve_offset: Vector2i = Vector2i.ZERO
var player_color: Color = Color.WHITE
var peer_username: String = "unnamed"


signal dimensions_finished
signal carve_finished
signal generation_finished
signal wall_remove_finished

var is_finished_loading: bool = false

@onready var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
@onready var navigation_map: RID = get_world_2d().get_navigation_map()
## called by the origin scene after initial configuration
func modified_ready() -> void:
	if not multiplayer.is_server(): return
	initialize_score_ui()
	create_maze_rectangle()
	await dimensions_finished
	carve_maze_rectangle()
	await carve_finished
	generate_maze_with_randomized_prim()
	await generation_finished
	remove_remaining_maze_cells()
	remove_random_maze_walls()
	await wall_remove_finished
	implement_maze_edges_physics()
	implement_maze_walls_physics()
	implement_navigation()
	place_players_on_map()
	#place_player_on_map()
	#place_bots_on_map()
	start_timers()
	finish_loading()

@rpc("reliable", "any_peer")
func finish_loading() -> void:
	if multiplayer.is_server(): rpc("finish_loading")
	$Camera.zoom = Vector2.ONE * INGAME_CAMERA_ZOOM
	is_finished_loading = true

func start_timers() -> void:
	$Timers/CrateSpawnDelay.start()
	$Timers/BotTargetClosestPlayerDelay.start()

const SCROLL_VALUE: float = 1.1
func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if is_finished_loading:
		$Camera.position = get_peer_player_node(multiplayer.get_unique_id()).position
	#if is_finished_loading: $Camera.position = $Player.position
	if Input.is_action_just_pressed("ScrollUp"):
		$Camera.zoom *= SCROLL_VALUE
	if Input.is_action_just_pressed("ScrollDown"):
		$Camera.zoom /= SCROLL_VALUE
	if $Players.get_child_count() < 2: return
	# for debugging
	#%PlayerTitle.text = str(alive_players_count)
	#%EnemyTitle.text = str(alive_enemies_count)

func get_peer_player_node(id: int) -> RigidBody2D:
	var target_player: RigidBody2D = null
	for player: RigidBody2D in $Players.get_children():
		if player.has_meta("bot_id"): continue
		if player.get_meta("server_id", -1) == -1:
			var ERROR: String = "CUSTOM ERROR: player node " + str(player) + " has metadata server_id equal to -1"
			push_error(ERROR)
			print_debug(ERROR)
			continue
		if player.get_meta("server_id", -1) == id:
			target_player = player
			break
	return target_player

@rpc("reliable", "any_peer")
func initialize_score_ui() -> void:
	if multiplayer.is_server(): rpc("initialize_score_ui")
	%PlayerScore.text = str(player_score)
	%EnemyScore.text = str(bot_score)

const TILE_SIZE: int = 16

## first vector entry is width, second is height
var maze_size: Vector2i = Vector2i.ZERO
var maze_bottom_corner: Vector2i = Vector2i.ZERO
func create_maze_rectangle() -> void:
	maze_size = Vector2i(rng.randi_range(min_maze_size.x, max_maze_size.x), rng.randi_range(min_maze_size.y, max_maze_size.y))
	if maze_size.x < maze_size.y:
		var auxiliary: int = maze_size.x
		maze_size.x = maze_size.y
		maze_size.y = auxiliary
	initialize_maze_rectangle(maze_size)
	await get_tree().create_timer(0.01).timeout
	for row: int in range(0, maze_size.y):
		for column: int in range(0, maze_size.x):
			iterate_maze_rectangle(row, column)
			await get_tree().create_timer(WAIT_TIME).timeout
	dimensions_finished.emit()

@rpc("reliable", "any_peer")
func initialize_maze_rectangle(received_maze_size: Vector2i) -> void:
	if multiplayer.is_server(): rpc("initialize_maze_rectangle", received_maze_size)
	maze_size = received_maze_size
	$Map/Ground/MazeDimensionsLabel.text = "Width: " + str(maze_size.x)
	$Map/Ground/MazeDimensionsLabel.text += "\nHeight: " + str(maze_size.y)
	$Camera.zoom = Vector2.ONE / maze_size.y * 6
	$Camera.scale.x = 1 / $Camera.zoom.x
	$Camera.scale.y = 1 / $Camera.zoom.y

@rpc("reliable", "any_peer")
func iterate_maze_rectangle(row: int, column: int) -> void:
	if multiplayer.is_server(): rpc("iterate_maze_rectangle", row, column)
	$SoundEffects/DimensionsGenerationNoise.play()
	$Map/Ground.set_cell(Vector2i(column, row), 0, Vector2i(0, 0), 1)
	#$Camera.position = maze_size * $Map/Ground.scale.x * TILE_SIZE / 2

var WAIT_TIME: float = 0.01
var maze_cells: Array[Vector2i] = []
func carve_maze_rectangle() -> void:
	var effective_vertical_margins: Array[Vector2i] = []
	var effective_horizontal_margins: Array[Vector2i] = []
	
	## random crop at every margin: it doesn't keep track of the previous margin(neighbour) for now
	var MAX_CARVE_LENGTH: int = min(maze_size.x, maze_size.y) / 3
	var random_offset: int = rng.randi_range(0, MAX_CARVE_LENGTH)
	var result_interval: Vector2i
	var result_cell: Vector2i
	for x: int in range(0, maze_size.x):
		random_offset = rng.randi_range(maze_carve_offset.x, maze_carve_offset.y)
		result_interval.x = random_offset
		random_offset = rng.randi_range(maze_carve_offset.x, maze_carve_offset.y)
		result_interval.y = maze_size.y - 1 - random_offset
		for y: int in range(result_interval.x, result_interval.y + 1):
			result_cell = Vector2i(x, y)
			effective_vertical_margins.append(result_cell)
			carve_maze_vertical(result_cell)
			await get_tree().create_timer(WAIT_TIME).timeout
	for y: int in range(0, maze_size.y):
		random_offset = rng.randi_range(maze_carve_offset.x, maze_carve_offset.y)
		result_interval.x = random_offset
		random_offset = rng.randi_range(maze_carve_offset.x, maze_carve_offset.y)
		result_interval.y = maze_size.x - 1 - random_offset
		for x: int in range(result_interval.x, result_interval.y + 1):
			result_cell = Vector2i(x, y)
			effective_horizontal_margins.append(result_cell)
			var is_covered_twice: bool = effective_vertical_margins.find(result_cell) != -1
			carve_maze_horizontal(result_cell, is_covered_twice)
			await get_tree().create_timer(WAIT_TIME).timeout
	
	clear_interval_tilemaps()
	for x: int in range(0, maze_size.x):
		for y: int in range(0, maze_size.y):
			var selected_cell: Vector2i = Vector2i(x, y)
			var is_cell_found_on_verticals: bool = effective_vertical_margins.find(selected_cell) != -1
			var is_cell_found_on_horizontals: bool = effective_horizontal_margins.find(selected_cell) != -1
			var is_maze_cell: bool = is_cell_found_on_verticals and is_cell_found_on_horizontals
			await get_tree().create_timer(WAIT_TIME).timeout
			$SoundEffects/TerrainGenerationNoise.play()
			if is_maze_cell:
				set_maze_cell(selected_cell)
				rpc("set_maze_cell", selected_cell)
				continue
			#var random_index: int = rng.randi_range(0, 1)
			#$Map/Ground.set_cell(selected_cell, 1, Vector2i(random_index, 0))
			clear_cell(selected_cell)
			rpc("clear_cell", selected_cell)
	
	carve_finished.emit()

@rpc("reliable", "any_peer")
func carve_maze_vertical(result_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("carve_maze_vertical", result_cell)
	$Map/VerticalIntervals.set_cell(result_cell, 0, Vector2i(0, 0), 3)
	$SoundEffects/SingleIntervalNoise.play()

@rpc("reliable", "any_peer")
func carve_maze_horizontal(result_cell: Vector2i, is_covered_twice: bool) -> void:
	if multiplayer.is_server(): rpc("carve_maze_horizontal", result_cell, is_covered_twice)
	$Map/HorizontalIntervals.set_cell(result_cell, 0, Vector2i(0, 0), 3)
	if is_covered_twice: $SoundEffects/DoubleIntervalNoise.play()
	else: $SoundEffects/SingleIntervalNoise.play()

@rpc("reliable", "any_peer")
func clear_interval_tilemaps() -> void:
	if multiplayer.is_server(): rpc("clear_interval_tilemaps")
	$Map/VerticalIntervals.clear()
	$Map/HorizontalIntervals.clear()

@rpc("reliable", "any_peer")
func set_maze_cell(selected_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("set_maze_cell", selected_cell)
	maze_cells.append(selected_cell)
	#$Map/Ground.set_cell(current_cell, 0, Vector2i(0, 0), 1) # redundant
	create_maze_visual_wall(selected_cell, 0)
	create_maze_visual_wall(selected_cell, 1)
	create_maze_visual_wall(selected_cell, 2)
	create_maze_visual_wall(selected_cell, 3)

@rpc("reliable", "any_peer")
func clear_cell(selected_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("clear_cell", selected_cell)
	$Map/Ground.set_cell(selected_cell)

## maze walls are accessed by two variables: one of the adjacent ground cells' map coordinates and
##	an integer that is 0, 1, 2 or 3 that marks on which direction the wall is positioned relative to the first variable

## for adjacency:
##	-	0 means right
##	-	1 means down
##	-	2 means left
##	-	3 means up

func get_maze_primary_wall(map_coordinates: Vector2i, adjacency: int) -> Vector2i:
	if adjacency <= -1 or adjacency >= 4: return Vector2i.ONE * -1
	# scale ratio has to effectively be an integer(for now, at least)
	var wall_coordinates: Vector2i
	wall_coordinates.x = (map_coordinates.x - map_coordinates.y) * scale_ratio
	wall_coordinates.y = (map_coordinates.x + map_coordinates.y) * scale_ratio
	if adjacency == 0:
		wall_coordinates.x += 1
		wall_coordinates.y += scale_ratio
	if adjacency == 1:
		wall_coordinates.x -= scale_ratio
		wall_coordinates.y += scale_ratio
	if adjacency == 2:
		wall_coordinates.x -= 1
	if adjacency == 3: ## it's already calculated for adjacency == 3 by default
		pass
	return wall_coordinates

func get_maze_primary_wall_increment(adjacency: int) -> Vector2i: 
	if adjacency == 0: return Vector2i(-1, 1)
	if adjacency == 1: return Vector2i(1, 1)
	if adjacency == 2: return Vector2i(-1, 1)
	if adjacency == 3: return Vector2i(1, 1)
	return Vector2i.ZERO

func create_maze_visual_wall(map_coordinates: Vector2i, adjacency: int) -> void:
	if adjacency <= -1 or adjacency >= 4: return
	var wall_coordinates: Vector2i = get_maze_primary_wall(map_coordinates, adjacency)
	$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, (adjacency + 1) % 2)
	wall_coordinates += get_maze_primary_wall_increment(adjacency)
	$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, (adjacency + 1) % 2)

func maze_visual_wall_exists(map_coordinates: Vector2i, adjacency: int) -> bool:
	if adjacency <= -1 or adjacency >= 4: return false
	var result: int = $Map/Walls.get_cell_source_id(get_maze_primary_wall(map_coordinates, adjacency))
	if OS.is_debug_build() and DEBUG_is_checking_maze:
		print("maze_visual_wall_exists(", map_coordinates, ", ", adjacency, "): ", result)
	return $Map/Walls.get_cell_source_id(get_maze_primary_wall(map_coordinates, adjacency)) != -1

func get_visual_wall_world_coordinates(map_coordinates: Vector2i, adjacency: int) -> Vector2:
	if adjacency <= -1 or adjacency >= 4: return Vector2.ONE * -1
	var primary_wall: Vector2 = get_maze_primary_wall(map_coordinates, adjacency)
	var secondary_wall: Vector2 = Vector2i(primary_wall) + get_maze_primary_wall_increment(adjacency)
	primary_wall = $Map/Walls.map_to_local(primary_wall) / scale_ratio - Vector2(0, scale_ratio * 2)
	secondary_wall = $Map/Walls.map_to_local(secondary_wall) / scale_ratio - Vector2(0, scale_ratio * 2)
	return (primary_wall + secondary_wall) / 2

## direction == 0 means positive y axis
## direction == 1 means negative x axis
## direction == 2 means negative y axis
## direction == 3 means positive x axis
@rpc("reliable", "any_peer")
func modify_physics_wall_length(index: int, wall_increment: int, direction: int) -> void:
	if multiplayer.is_server(): rpc("modify_physics_wall_length", index, wall_increment, direction)
	#if wall_node == null:
		#push_error("CUSTOM_ERROR: invalid wall_node")
		#print_debug("CUSTOM_ERROR: invalid wall_node")
		#return
	if direction <= -1 or direction >= 4: return
	var wall_node: StaticBody2D = null
	for node: StaticBody2D in $Map/PhysicsWalls.get_children():
		wall_node = node
		if wall_node.get_meta("wall_id", -1) == -1: continue
		if wall_node.get_meta("wall_id", -1) == index: break
	var primary_wall: Vector2 = get_maze_primary_wall(Vector2i.ZERO, 1)
	var secondary_wall: Vector2 = Vector2i(primary_wall) + get_maze_primary_wall_increment(1)
	var unit_wall_length: float = ($Map/Walls.map_to_local(secondary_wall) - $Map/Walls.map_to_local(primary_wall)).x
	var int_is_positive_axis: int = int(direction == 0 or direction == 3) * 2 - 1
	# idk how to calculate magic_tile_offset for now, neither how to name it, but it makes the code work ;)
	var magic_tile_offset: int = 8
	if direction == 1 or direction == 3:
		wall_node.position.x += unit_wall_length * wall_increment / 2 * int_is_positive_axis
		wall_node.scale.x += (unit_wall_length * wall_increment / 2 + magic_tile_offset) * int_is_positive_axis
	if direction == 0 or direction == 2:
		wall_node.position.y += unit_wall_length * wall_increment / 2 * int_is_positive_axis
		wall_node.scale.y += (unit_wall_length * wall_increment / 2 + magic_tile_offset) * int_is_positive_axis

func is_wall_between_cells(cell_1: Vector2i, cell_2: Vector2i, range: int, include_diagonals: bool) -> bool:
	if cell_1 == cell_2: return false ## slight optimisation just in case
	for k: int in range(range):
		if cell_1.x + k + 1 == cell_2.x:
			if maze_visual_wall_exists(cell_1, 0) or maze_visual_wall_exists(cell_2, 2): return true
		if cell_1.y + k + 1 == cell_2.y:
			if maze_visual_wall_exists(cell_1, 1) or maze_visual_wall_exists(cell_2, 3): return true
		if cell_1.x - k - 1 == cell_2.x:
			if maze_visual_wall_exists(cell_1, 2) or maze_visual_wall_exists(cell_2, 0): return true
		if cell_1.y - k - 1 == cell_2.y:
			if maze_visual_wall_exists(cell_1, 3) or maze_visual_wall_exists(cell_2, 1): return true
	if not include_diagonals: return false
	if cell_1 + Vector2i(1, 1) == cell_2:
		if maze_visual_wall_exists(cell_1, 0) or maze_visual_wall_exists(cell_1, 1): return true
		if maze_visual_wall_exists(cell_2, 2) or maze_visual_wall_exists(cell_2, 3): return true
	if cell_1 + Vector2i(-1, 1) == cell_2:
		if maze_visual_wall_exists(cell_1, 1) or maze_visual_wall_exists(cell_1, 2): return true
		if maze_visual_wall_exists(cell_2, 3) or maze_visual_wall_exists(cell_2, 0): return true
	if cell_1 + Vector2i(-1, -1) == cell_2:
		if maze_visual_wall_exists(cell_1, 2) or maze_visual_wall_exists(cell_1, 3): return true
		if maze_visual_wall_exists(cell_2, 0) or maze_visual_wall_exists(cell_2, 1): return true
	if cell_1 + Vector2i(1, -1) == cell_2:
		if maze_visual_wall_exists(cell_1, 3) or maze_visual_wall_exists(cell_1, 0): return true
		if maze_visual_wall_exists(cell_2, 1) or maze_visual_wall_exists(cell_2, 2): return true
	return false

## Randomized Prim's Algorithm: it's the primary maze generating algorithm for this project
func generate_maze_with_randomized_prim() -> void:
	var selected_cell: Vector2i
	## all vector entries should be integers, but this is what Godot offers for optimisation
	var final_maze_cells: PackedVector2Array
	var frontier_cells: PackedVector2Array
	selected_cell = maze_size / 2 #maze_cells[rng.randi_range(0, maze_cells.size() - 1)]
	var color_index: int = rng.randi_range(0, 3)
	color_generated_maze_cell(selected_cell, color_index)
	final_maze_cells.append(selected_cell)
	
	if maze_cells.find(selected_cell + Vector2i.RIGHT) != -1:
		frontier_cells.append(selected_cell + Vector2i.RIGHT)
		delete_maze_visual_wall(selected_cell, 0)
	if maze_cells.find(selected_cell + Vector2i.DOWN) != -1:
		frontier_cells.append(selected_cell + Vector2i.DOWN)
		delete_maze_visual_wall(selected_cell, 1)
	if maze_cells.find(selected_cell + Vector2i.LEFT) != -1:
		frontier_cells.append(selected_cell + Vector2i.LEFT)
		delete_maze_visual_wall(selected_cell, 2)
	if maze_cells.find(selected_cell + Vector2i.UP) != -1:
		frontier_cells.append(selected_cell + Vector2i.UP)
		delete_maze_visual_wall(selected_cell, 3)
	var selected_frontier_cell_index: int
	var i: int = 0
	while frontier_cells.size() != 0:
		await get_tree().create_timer(0.01).timeout
		play_sound("MazeGenerationNoise")
		selected_frontier_cell_index = rng.randi_range(0, frontier_cells.size() - 1)
		selected_cell = frontier_cells[selected_frontier_cell_index]
		frontier_cells.remove_at(selected_frontier_cell_index)
		configure_as_maze_cell(selected_cell, final_maze_cells, frontier_cells)
		i += 1
	generation_finished.emit()

@rpc("reliable", "any_peer")
func color_generated_maze_cell(selected_cell: Vector2i, color_index: int) -> void:
	if multiplayer.is_server(): rpc("color_generated_maze_cell", selected_cell, color_index)
	$Map/Ground.set_cell(selected_cell, 0, Vector2i(color_index, 0), 0)

@rpc("reliable", "any_peer")
func delete_maze_visual_wall(map_coordinates: Vector2i, adjacency: int) -> void:
	if multiplayer.is_server(): rpc("delete_maze_visual_wall", map_coordinates, adjacency)
	if adjacency <= -1 or adjacency >= 4: return
	var wall_coordinates: Vector2i = get_maze_primary_wall(map_coordinates, adjacency)
	$Map/Walls.set_cell(wall_coordinates)
	wall_coordinates += get_maze_primary_wall_increment(adjacency)
	$Map/Walls.set_cell(wall_coordinates)

@rpc("reliable", "any_peer")
func play_sound(name: String) -> void:
	if multiplayer.is_server(): rpc("play_sound", name)
	$SoundEffects.get_node(name).play()

@rpc("reliable", "any_peer")
func color_generated_frontier_cell(selected_neighbor_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("color_generated_frontier_cell", selected_neighbor_cell)
	$Map/Ground.set_cell(selected_neighbor_cell, 0, Vector2i(0, 0), 2)

func configure_as_maze_cell(selected_cell: Vector2i, final_maze_cells: PackedVector2Array, frontier_cells: PackedVector2Array) -> void:
	final_maze_cells.append(selected_cell)
	var color_index: int = rng.randi_range(0, 3)
	color_generated_maze_cell(selected_cell, color_index)
	
	## remove one adjacent maze cell's wall
	## only one adjacent wall will be deleted(at least for now)
	## it will always yield at least one because the selected cell is a former frontier cell
	var num_neighboring_maze_cells: int = 0
	var possible_directions: Array[int] ## min size should be 1, max size should be 4
	var neighboring_cell_offset: Vector2i = Vector2i.RIGHT
	var selected_neighbor_cell: Vector2i
	for index: int in range(4):
		selected_neighbor_cell = selected_cell + Vector2i(neighboring_cell_offset)
		if maze_cells.find(selected_neighbor_cell) != -1:
			if final_maze_cells.find(selected_neighbor_cell) != -1:
				num_neighboring_maze_cells += 1
				possible_directions.append(index)
		neighboring_cell_offset = get_rotated_integer_vector(neighboring_cell_offset)
	var random_direction: int = possible_directions[rng.randi_range(0, num_neighboring_maze_cells - 1)]
	delete_maze_visual_wall(selected_cell, random_direction)
	
	## mark neighboring cells as frontier cells
	neighboring_cell_offset = Vector2i.RIGHT
	for i: int in range(4):
		selected_neighbor_cell = selected_cell + neighboring_cell_offset
		if maze_cells.find(selected_neighbor_cell) != -1:
			if frontier_cells.find(selected_neighbor_cell) == -1:
				# this third if statement is a temporary fix for the problem of frontier cells not being removed when
				#	transformed to maze cells
				if final_maze_cells.find(selected_neighbor_cell) == -1:
					color_generated_frontier_cell(selected_neighbor_cell)
					frontier_cells.append(selected_neighbor_cell)
		neighboring_cell_offset = get_rotated_integer_vector(neighboring_cell_offset)

func get_rotated_integer_vector(vector: Vector2i) -> Vector2i:
	if vector == Vector2i.RIGHT: return Vector2i.DOWN
	if vector == Vector2i.DOWN: return Vector2i.LEFT
	if vector == Vector2i.LEFT: return Vector2i.UP
	if vector == Vector2i.UP: return Vector2i.RIGHT
	return Vector2i.ZERO ## invalid input handler

func remove_remaining_maze_cells() -> void:
	var selected_cell: Vector2i
	for x: int in range(0, maze_size.x):
		for y: int in range(0, maze_size.y):
			selected_cell = Vector2i(x, y)
			var is_black_cell: bool = $Map/Ground.get_cell_alternative_tile(selected_cell) == 1
			var is_visual_outside_cell: bool = $Map/Ground.get_cell_source_id(selected_cell) == 1
			var is_array_maze_cell: bool = maze_cells.find(selected_cell) != -1
			var is_invalid_outside_cell: bool = is_visual_outside_cell and is_array_maze_cell
			if not is_black_cell and not is_invalid_outside_cell: continue
			remove_maze_cell(selected_cell)
			for adjacency: int in range(4):
				var neighbor_cell: Vector2i = get_maze_cell_neighbor(selected_cell, adjacency)
				if maze_cells.find(neighbor_cell, 0) != -1: continue
				delete_maze_visual_wall(selected_cell, 0)
				delete_maze_visual_wall(selected_cell, 1)
				delete_maze_visual_wall(selected_cell, 2)
				delete_maze_visual_wall(selected_cell, 3)

@rpc("reliable", "any_peer")
func remove_maze_cell(selected_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("remove_maze_cell", selected_cell)
	maze_cells.remove_at(maze_cells.find(selected_cell, 0))
	$Map/Ground.set_cell(selected_cell)

func remove_random_maze_walls() -> void:
	var remove_count: int = rng.randi_range(wall_remove_interval.x, wall_remove_interval.y)
	await get_tree().create_timer(0.01).timeout
	if remove_count == 0:
		wall_remove_finished.emit()
		return
	var removed: int = 0
	while removed < remove_count:
		await get_tree().create_timer(0.03).timeout
		play_sound("WallRemoveNoise")
		var selected_cell: Vector2i = maze_cells.get(rng.randi_range(0, maze_cells.size() - 1))
		var possible_adjacencies: Array[int] = []
		for selected_adjacency: int in range(4):
			var selected_wall_exists: bool = maze_visual_wall_exists(selected_cell, selected_adjacency)
			var selected_neighbor_is_maze_cell: bool = maze_cells.find(get_maze_cell_neighbor(selected_cell, selected_adjacency), 0) != -1
			if selected_wall_exists and selected_neighbor_is_maze_cell:
				possible_adjacencies.push_back(selected_adjacency)
		if possible_adjacencies.size() == 0: continue
		var deleted_adjacency: int = rng.randi_range(0, possible_adjacencies.size() - 1)
		deleted_adjacency = possible_adjacencies[deleted_adjacency]
		delete_maze_visual_wall(selected_cell, deleted_adjacency)
		removed += 1
	wall_remove_finished.emit()

func get_maze_cell_neighbor(selected_cell: Vector2i, adjacency: int) -> Vector2i:
	if adjacency < 0 or adjacency > 3: return Vector2i.ONE * -1
	var result: Vector2i = selected_cell
	if adjacency == 0: result += Vector2i.RIGHT
	if adjacency == 1: result += Vector2i.DOWN
	if adjacency == 2: result += Vector2i.LEFT
	if adjacency == 3: result += Vector2i.UP
	return result

func implement_maze_edges_physics() -> void:
	var maze_corner: Vector2
	maze_corner.x = maze_size.x * $Map/Ground.scale.x * $Map/Ground.scale.x / $Map/Walls.scale.x
	maze_corner.y = maze_size.y * $Map/Ground.scale.y * $Map/Ground.scale.y / $Map/Walls.scale.y
	remote_implement_maze_edges_physics(maze_corner)

@rpc("reliable", "any_peer")
func remote_implement_maze_edges_physics(maze_corner: Vector2) -> void:
	if multiplayer.is_server(): rpc("remote_implement_maze_edges_physics", maze_corner)
	%RightEdgeWall.position.x = maze_corner.x
	%RightEdgeWall.position.y = maze_corner.y / 2
	%RightEdgeWall.scale.y = maze_size.y * $Map/Ground.scale.y * $Map/Ground.scale.y / $Map/Walls.scale.y
	
	%DownEdgeWall.position.x = maze_corner.x / 2
	%DownEdgeWall.position.y = maze_corner.y
	%DownEdgeWall.scale.x = maze_size.x * $Map/Ground.scale.x * $Map/Ground.scale.x / $Map/Walls.scale.x
	
	%LeftEdgeWall.position.x = 0
	%LeftEdgeWall.position.y = maze_corner.y / 2
	%LeftEdgeWall.scale.y = maze_size.y * $Map/Ground.scale.y * $Map/Ground.scale.y / $Map/Walls.scale.y
	
	%UpEdgeWall.position.x = maze_corner.x / 2
	%UpEdgeWall.position.y = 0
	%UpEdgeWall.scale.x = maze_size.x * $Map/Ground.scale.x * $Map/Ground.scale.x / $Map/Walls.scale.x
	for body: StaticBody2D in $Map/Edges.get_children():
		body.set_meta("type", "wall")

const TILE_MAZE_WALL_PATH: String = "res://ingame/tiles/tile_maze_wall.png"
var EFFECTIVE_TILE_WIDTH: int = load(TILE_MAZE_WALL_PATH).get_width() - 1
func implement_maze_walls_physics() -> void:
	implement_maze_horizontal_walls_physics()
	implement_maze_vertical_walls_physics()
	final_implement_maze_walls_physics()

@rpc("reliable", "any_peer")
func final_implement_maze_walls_physics() -> void:
	if multiplayer.is_server(): rpc("final_implement_maze_walls_physics")
	for body: StaticBody2D in $Map/PhysicsWalls.get_children():
		body.set_meta("type", "wall")

func new_collision_shape() -> CollisionShape2D:
	var physics_shape_ref: CollisionShape2D = CollisionShape2D.new()
	var shape_ref: RectangleShape2D = RectangleShape2D.new()
	#var temporary_debug: Texture2D = load(TEMPORARY_DEBUG_WALL_PHYSICS_TEXTURE_PATH)
	shape_ref.set_size(Vector2.ONE)
	physics_shape_ref.shape = shape_ref
	return physics_shape_ref

var physics_wall_index: int = -1
var physics_wall_ins: StaticBody2D = null
func implement_maze_horizontal_walls_physics() -> void:
	var selected_cell: Vector2i
	var is_extending_wall: bool
	if OS.is_debug_build() and DEBUG_is_checking_maze:
		print("\t\t\t\t\t\t\t\t\t\timplementing maze horizontal walls physics")
	for row: int in range(0, maze_size.y - 1):
		if OS.is_debug_build() and DEBUG_is_checking_maze:
			print("on row: ", row)
		is_extending_wall = false
		for column: int in range(0, maze_size.x):
			if OS.is_debug_build() and DEBUG_is_checking_maze:
				print("\ton column: ", column)
			selected_cell = Vector2i(column, row)
			if OS.is_debug_build() and DEBUG_is_checking_maze:
				print("\tselected cell: ", selected_cell)
			if maze_visual_wall_exists(selected_cell, 1) and not is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can initiate!")
				physics_wall_index += 1
				create_new_physics_wall(selected_cell, true, physics_wall_index)
				is_extending_wall = true
				continue
			if maze_visual_wall_exists(selected_cell, 1) and is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can extend!")
				modify_physics_wall_length(physics_wall_index, 1, 3)
			if not maze_visual_wall_exists(selected_cell, 1):
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\t\tVISUAL WALL DOESN'T EXIST HERE...")
				is_extending_wall = false

@rpc("reliable", "any_peer")
func create_new_physics_wall(selected_cell: Vector2i, is_horizontal: bool, index: int) -> void:
	if multiplayer.is_server(): rpc("create_new_physics_wall", selected_cell, is_horizontal, index)
	var physics_wall: StaticBody2D = StaticBody2D.new()
	physics_wall.set_meta("wall_id", index)
	var collision_shape: CollisionShape2D = new_collision_shape()
	physics_wall.add_child(collision_shape)
	$Map/PhysicsWalls.add_child(physics_wall)
	physics_wall.owner = self
	physics_wall.position = get_visual_wall_world_coordinates(selected_cell, int(is_horizontal))
	if is_horizontal: physics_wall.scale.x = EFFECTIVE_TILE_WIDTH
	else: physics_wall.scale.y = EFFECTIVE_TILE_WIDTH
	if multiplayer.is_server(): physics_wall_ins = physics_wall

func implement_maze_vertical_walls_physics() -> void:
	var selected_cell: Vector2i
	var is_extending_wall: bool
	if OS.is_debug_build() and DEBUG_is_checking_maze:
		print("\t\t\t\t\t\t\t\t\t\timplementing maze vertical walls physics")
	for column: int in range(0, maze_size.x - 1):
		if OS.is_debug_build() and DEBUG_is_checking_maze:
			print("on column: ", column)
		is_extending_wall = false
		for row: int in range(0, maze_size.y):
			if OS.is_debug_build() and DEBUG_is_checking_maze:
				print("\ton row: ", row)
			selected_cell = Vector2i(column, row)
			if OS.is_debug_build() and DEBUG_is_checking_maze:
				print("\tselected cell: ", selected_cell)
			if maze_visual_wall_exists(selected_cell, 0) and not is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can initiate!")
				physics_wall_index += 1
				create_new_physics_wall(selected_cell, false, physics_wall_index)
				is_extending_wall = true
				continue
			if maze_visual_wall_exists(selected_cell, 0) and is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can extend!")
				modify_physics_wall_length(physics_wall_index, 1, 0)
			if not maze_visual_wall_exists(selected_cell, 0):
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\t\tVISUAL WALL DOESN'T EXIST HERE...")
				is_extending_wall = false

# this function presupposes that at every maze cell has at least one accessible neighbour
# probably could be optimised
func implement_navigation() -> void:
	for row: int in range(0, maze_size.y):
		for column: int in range(0, maze_size.x):
			var directions: Array[bool]
			for i: int in range(4):
				directions.push_back(not maze_visual_wall_exists(Vector2i(column, row), i))
			var occurences: Array[int]
			occurences.push_back(directions.find(true, 0))
			occurences.push_back(directions.find(true, occurences[0] + 1))
			if occurences[1] == -1:
				$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(1, 0), occurences[0])
				continue
			occurences.push_back(directions.find(true, occurences[1] + 1))
			if occurences[2] == -1:
				if (occurences[1] - occurences[0]) % 2 == 0:
					var is_alternative_tile: bool = (occurences[1] + occurences[0]) % 4 == 0
					$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(0, 1), is_alternative_tile)
				else:
					if occurences[0] == 0 and occurences[1] == 3: ## because of looping, this is an exception to the rule
						$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(2, 0), 0)
					else: $Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(2, 0), occurences[1])
				continue
			occurences.push_back(directions.find(true, occurences[2] + 1))
			if occurences[3] == -1:
				if occurences[0] == 0 and occurences[1] == 2 and occurences[2] == 3: ## because of looping, this is an exception to the rule
					$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(1, 1), 0)
				elif occurences[0] == 0 and occurences[1] == 1 and occurences[2] == 3: ## because of looping, this is an exception to the rule
					$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(1, 1), 1)
				else: $Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(1, 1), occurences[2])
				continue
			$Map/Navigation.set_cell(Vector2(column, row), 0, Vector2i(2, 1), 0)

## the selected cell doesn't need to be part of the maze
func get_maze_cell_to_world(selected_cell: Vector2i) -> Vector2:
	var result: Vector2 = $Map/Ground.map_to_local(selected_cell)
	result.x *= $Map/Ground.scale.x
	result.y *= $Map/Ground.scale.y
	return result

const GROUND_TILE_SET: String = "res://ingame/tiles/base_tileset.tres"
const OFFSET_SUBTRACT: float = 20.0
#func place_player_on_map() -> void:
	#var selected_cell: Vector2i
	#var ground_tile_size: Vector2i = load(GROUND_TILE_SET).tile_size
	#selected_cell = maze_cells.get(rng.randi_range(0, maze_cells.size() - 1))
	#var selected_position: Vector2 = get_maze_cell_to_world(selected_cell)
	#$Player.position = selected_position
	#var offset_vector: Vector2
	#var max_offset_scalar: Vector2 = $Map/Ground.scale / 2 - Vector2.ONE * OFFSET_SUBTRACT
	#offset_vector.x = rng.randf_range(-max_offset_scalar.x, max_offset_scalar.x)
	#offset_vector.y = rng.randf_range(-max_offset_scalar.y, max_offset_scalar.y)
	#$Player.position += offset_vector
	#$Player.rotation = rng.randf_range(0, PI * 2)
	#$Player.visible = true
	#$Player.process_mode = Node.PROCESS_MODE_INHERIT
	#$Player.modulate = player_color
	#alive_players_count = 1

# unused, but it can stay
func get_world_closest_player(player: RigidBody2D) -> RigidBody2D:
	var result: RigidBody2D = null
	var result_distance: float = INF
	for instance: RigidBody2D in $Players.get_children():
		if instance == player: continue
		if instance.get_node("Rest").visible == false: continue
		var calculated_distance: float = player.position.distance_to(instance.position)
		if calculated_distance < result_distance:
			result = instance
			result_distance = calculated_distance
	return result

func get_navigation_closest_player(player: RigidBody2D) -> RigidBody2D:
	if player == null:
		const STRING: String = "CUSTOM ERROR: Can't calculate nearest player to a null player"
		push_error(STRING)
		print_debug(STRING)
		return null
	if $Players.get_child_count() < 2:
		const STRING: String = "CUSTOM ERROR: Too few players, must be at least two instantiated players in level scene"
		push_error(STRING)
		print_debug(STRING)
		return null
	var result: RigidBody2D = null
	var result_distance: float = FLOAT_MAX
	for instance: RigidBody2D in $Players.get_children():
		if instance == player: continue
		if instance.get_node("Rest").visible == false: continue
		var instance_distance: float = get_navigation_distance(player.position, instance.position)
		if instance_distance < result_distance:
			result = instance
			result_distance = instance_distance
	if result == null:
		const STRING: String = "CUSTOM ERROR: Resulting closest player is null for some reason"
		push_error(STRING)
		print_debug(STRING)
	return result

func get_navigation_distance(start: Vector2, goal: Vector2) -> float:
	$NavigationNode.global_position = start
	$NavigationNode/NavigationAgent.target_position = goal
	#$NavigationNode/NavigationAgent.get_current_navigation_path()
	var path: PackedVector2Array = NavigationServer2D.map_get_path(navigation_map, start, goal, true, 1)
	var distance: float = 0.0
	for i: int in range(path.size() - 1):
		distance += path[i].distance_to(path[i + 1])
	return distance

const NEW_BULLET_FILE: String = "res://ingame/entities/projectiles/bullet.tscn"
const REGULAR_SPAWN_OFFSET: float = 35.0
const LASER_SPAWN_OFFSET: float = 35.0
const LASER_BULLET_SPEED: float = 4000.0
const LASER_LIFESPAN: float = 1.0
const ROCKET_SPAWN_OFFSET: float = 38.0
const TRAP_SPAWN_OFFSET: float = 60.0
const MAX_BULLET_COUNT: int = 10000
var current_bullet_index: int = -1
var current_bullet_ins: RigidBody2D = null
# technically humans only for now
func _on_player_shoot(player: RigidBody2D, weapon_type: String) -> void:
	if weapon_type == "regular" and player.bullet_count >= player.MAX_BULLET_COUNT:
		play_sound("NoAmmoNoise")
		return
	if weapon_type != "regular": player.equip_weapon("regular") ## should only execute for human players
	current_bullet_index += 1
	if current_bullet_index >= MAX_BULLET_COUNT: current_bullet_index = 0
	var bullet_offset: float
	if weapon_type == "regular": bullet_offset = REGULAR_SPAWN_OFFSET
	if weapon_type == "laser": bullet_offset = LASER_SPAWN_OFFSET
	if weapon_type == "rocket": bullet_offset = ROCKET_SPAWN_OFFSET
	if weapon_type == "trap": bullet_offset = TRAP_SPAWN_OFFSET
	var given_position: Vector2 = player.position + Vector2(bullet_offset, 0).rotated(player.rotation)
	add_child_bullet(current_bullet_index, weapon_type, given_position, player.rotation)
	current_bullet_ins.owner_node = player
	if weapon_type == "regular": player.bullet_count += 1

#func _on_bot_shoot(bot: RigidBody2D) -> void:
	#if bot.bullet_count >= bot.MAX_BULLET_COUNT:
		#play_sound("NoAmmoNoise")
		#rpc("play_sound", "NoAmmoNoise")
		#return
	#current_bullet_index += 1
	#if current_bullet_index >= MAX_BULLET_COUNT: current_bullet_index = 0
	#var given_position: Vector2 = bot.position + Vector2(bot.BULLET_SPAWN_OFFSET, 0).rotated(bot.rotation)
	#add_child_bullet(current_bullet_index, "regular", given_position, bot.rotation)
	#rpc("add_child_bullet", current_bullet_index, "regular", given_position, bot.rotation)
	#current_bullet_ins.owner_node = bot
	#bot.bullet_count += 1

@rpc("reliable", "any_peer")
func add_child_bullet(id: int, type: String, given_position: Vector2, given_rotation: float) -> void:
	if multiplayer.is_server(): rpc("add_child_bullet", id, type, given_position, given_rotation)
	var bullet: RigidBody2D = load(NEW_BULLET_FILE).instantiate()
	bullet.set_meta("bullet_id", id)
	bullet.type = type
	bullet.position = given_position
	bullet.initial_velocity_direction = given_rotation
	var bullet_speed: float
	if type == "regular":
		bullet_speed = REGULAR_BULLET_SPEED
		$SoundEffects/NormalShootNoise.play()
	if type == "laser":
		bullet_speed = LASER_BULLET_SPEED
		$SoundEffects/LaserShootNoise.play()
		bullet.get_node("LifespanTimer").wait_time = LASER_LIFESPAN
		bullet.get_node("Rest/LaserTrail").emitting = true
	if type == "rocket":
		bullet_speed = REGULAR_BULLET_SPEED
		$SoundEffects/RocketShootNoise.play()
	if type == "trap":
		bullet_speed = 0.0
		$SoundEffects/TrapPlaceNoise.play()
	if type != "trap": bullet.connect("despawn", on_bullet_despawn)
	bullet.initial_velocity_speed = bullet_speed
	$Bullets.add_child(bullet)
	bullet.modified_ready()
	if multiplayer.is_server(): current_bullet_ins = bullet

## connected to each bullet's despawn signal
func on_bullet_despawn(bullet: RigidBody2D) -> void:
	if not multiplayer.is_server(): return
	bullet.owner_node.bullet_count -= 1

var current_crate_index: int = -1
var current_crate_instance: Area2D = null
const TYPE_DICTIONARY: Dictionary = {
	1: "laser",
	2: "rocket",
	3: "trap"
}
func _on_crate_spawn_delay_timeout() -> void:
	play_sound("CrateSpawnNoise")
	current_crate_index += 1
	var selected_type: String = TYPE_DICTIONARY[rng.randi_range(1, TYPE_DICTIONARY.size())]
	var selected_maze_cell: Vector2i = maze_cells[rng.randi_range(0, maze_cells.size() - 1)]
	var selected_rotation: float = rng.randf_range(-PI, PI)
	create_crate(current_crate_index, selected_type, selected_maze_cell, selected_rotation)
	current_crate_instance.connect("equip_weapon", equip_weapon)

const NEW_CRATE_FILE: String = "res://ingame/entities/crates/crate.tscn"
@rpc("reliable", "any_peer")
func create_crate(id: int, type: String, maze_cell_position: Vector2i, given_rotation: float) -> void:
	if multiplayer.is_server(): rpc("create_crate", id, type, maze_cell_position, given_rotation)
	var crate: Area2D = load(NEW_CRATE_FILE).instantiate()
	crate.set_meta("crate_id", id)
	crate.type = type
	crate.get_node("Image").texture = load(crate.TEXTURE_PATH_PREFIX + type + crate.TEXTURE_EXTENSION)
	crate.global_position = get_maze_cell_to_world(maze_cell_position)
	crate.rotation = given_rotation
	$Crates.add_child(crate)
	if multiplayer.is_server(): current_crate_instance = crate

## connected to crates when one of them gets picked up by a player
func equip_weapon(player: RigidBody2D, type: String) -> void:
	player.equip_weapon(type)

var alive_players_count: int
var alive_enemies_count: int

## scores are initialised by the origin scene
var player_score: int = 0
var bot_score: int = 0

func _on_player_level_die() -> void:
	alive_players_count -= 1
	play_sound("DeathNoise")
	$Timers/DeathDelay.start()

func _on_bot_level_die() -> void:
	alive_enemies_count -= 1
	play_sound("DeathNoise")
	$Timers/DeathDelay.start()

func _on_death_delay_timeout() -> void:
	pass
	#if alive_players_count > 0 and alive_enemies_count > 0: return
	#if alive_players_count <= 0 and alive_enemies_count <= 0:
		#%DrawTitle.visible = true
		#$Timers/NextRoundDelay.start()
		#$SoundEffects/NextRoundNoise.play()
		#process_mode = Node.PROCESS_MODE_DISABLED
		#return
	#if alive_players_count <= 0:
		#bot_score += 1
		#%EnemyScore.text = str(bot_score)
	#if alive_enemies_count <= 0:
		#player_score += 1
		#%PlayerScore.text = str(player_score)
	#$Timers/NextRoundDelay.start()
	#$SoundEffects/NextRoundNoise.play()
	#process_mode = Node.PROCESS_MODE_DISABLED

signal next_round(player_score: int, bot_score: int)
func _on_next_round_delay_timeout() -> void:
	next_round.emit(player_score, bot_score)
	queue_free()

##
##
## 					MULTIPLAYER CONTROLLER CODE DOWN
##
##

const NEW_PLAYER_FILE: String = "res://ingame/entities/player/player.tscn"

func place_players_on_map() -> void:
	place_humans_on_map()
	place_bots_on_map()

var selected_player: RigidBody2D = null
func place_humans_on_map() -> void:
	for i in GameManager.humans_list:
		var name: String = GameManager.humans_list[i].name
		var modulation: Color = GameManager.humans_list[i].modulation
		create_human_player(i, name, modulation)
		
		var available_cells: Array[Vector2i] = maze_cells
		var random_cell_index: int = rng.randi_range(0, available_cells.size() - 1)
		var selected_cell: Vector2i = available_cells[random_cell_index]
		var is_valid_spawn: bool = false
		var foolproof_index: int = 0
		while not is_valid_spawn and available_cells.size() > 0:
			is_valid_spawn = true
			for other_player: RigidBody2D in $Players.get_children():
				if other_player.get_meta("server_id", -1) == -1:
					var ERROR: String = "CUSTOM ERROR: player node " + str(other_player) + " has server_id = -1"
					push_error(ERROR)
					print_debug(ERROR)
					continue
				if other_player.get_meta("server_id", -1) == i: continue
				var distance: float = other_player.global_position.distance_to(get_maze_cell_to_world(selected_cell))
				if distance < MIN_SPAWNPOINT_DISTANCING:
					is_valid_spawn = false
					available_cells.remove_at(random_cell_index)
					random_cell_index = rng.randi_range(0, available_cells.size() - 1)
					selected_cell = available_cells[random_cell_index]
					break
		
		set_human_player_position(i, selected_cell)
		
		if not selected_player.is_connected("shoot", _on_player_shoot):
			selected_player.connect("shoot", _on_player_shoot)
		if not selected_player.is_connected("level_die", _on_player_level_die):
			selected_player.connect("level_die", _on_player_level_die)

@rpc("reliable", "any_peer")
func create_human_player(server_id: int, name: String, modulation: Color) -> void:
	if multiplayer.is_server(): rpc("create_human_player", server_id, name, modulation)
	var player: RigidBody2D = load(NEW_PLAYER_FILE).instantiate()
	player.set_meta("server_id", server_id)
	player.get_node("Rest/FixedRotation/Name").text = name
	player.get_node("Rest").modulate = modulation
	player.get_node("DeathParticles").modulate = modulation
	$Players.add_child(player)
	if multiplayer.is_server(): selected_player = player

@rpc("reliable", "any_peer")
func set_human_player_position(server_id: int, selected_cell: Vector2i) -> void:
	if multiplayer.is_server(): rpc("set_human_player_position", server_id, selected_cell)
	var player: RigidBody2D = null
	for node: RigidBody2D in $Players.get_children():
		player = node
		if player.get_meta("server_id", -1) == -1:
			var ERROR: String = "CUSTOM ERROR: player node " + str(player) + " has server_id = -1"
			push_error(ERROR)
			print_debug(ERROR)
			continue
		if player.get_meta("server_id", -1) == server_id: break
	player.global_position = get_maze_cell_to_world(selected_cell)

@export var MIN_SPAWNPOINT_DISTANCING: float = 400.0
var bot_count: int
var bot_instance: RigidBody2D = null
const NEW_BOT_INSTANCE_PATH: String = "res://ingame/entities/bot/bot.tscn"
func place_bots_on_map() -> void:
	bot_count = rng.randi_range(bot_count_interval.x, bot_count_interval.y)
	for index: int in range(0, bot_count):
		add_child_bot_node(index)
		var random_index: int = rng.randi_range(0, maze_cells.size() - 1)
		bot_instance.global_position = get_maze_cell_to_world(maze_cells[random_index])
		var closest_player: RigidBody2D = get_navigation_closest_player(bot_instance)
		bot_instance.global_position = closest_player.global_position
		var distance: float = (closest_player.global_position - bot_instance.global_position).length()
		while distance <= MIN_SPAWNPOINT_DISTANCING:
			distance = (closest_player.global_position - bot_instance.global_position).length()
			var selected_cell: Vector2i
			var ground_tile_size: Vector2i = load(GROUND_TILE_SET).tile_size
			selected_cell = maze_cells.get(rng.randi_range(0, maze_cells.size() - 1))
			var selected_position: Vector2 = get_maze_cell_to_world(selected_cell)
			bot_instance.position = selected_position
			var offset_vector: Vector2
			var max_offset_scalar: Vector2 = $Map/Ground.scale / 2 - Vector2.ONE * OFFSET_SUBTRACT
			offset_vector.x = rng.randf_range(-max_offset_scalar.x, max_offset_scalar.x)
			offset_vector.y = rng.randf_range(-max_offset_scalar.y, max_offset_scalar.y)
			bot_instance.position += offset_vector
			bot_instance.rotation = rng.randf_range(0, PI * 2)
			bot_instance.visible = true
			bot_instance.player_node = closest_player
			bot_instance.bot_friendly_fire = bot_friendly_fire
			if not bot_instance.is_connected("shoot", _on_player_shoot):
				bot_instance.connect("shoot", _on_player_shoot)
			if not bot_instance.is_connected("level_die", _on_bot_level_die):
				bot_instance.connect("level_die", _on_bot_level_die)
			#bot_instance.get_node("Rest/Image").scale += Vector2.ONE * rng.randf_range(-0.1, 0.1)
		initialize_bot_position_and_rotation(index, bot_instance.global_position, bot_instance.rotation)
		alive_enemies_count = bot_count

@rpc("reliable", "any_peer")
func add_child_bot_node(bot_id: int) -> void:
	if multiplayer.is_server(): rpc("add_child_bot_node", bot_id)
	var bot: RigidBody2D = load(NEW_BOT_INSTANCE_PATH).instantiate()
	bot.set_meta("bot_id", bot_id)
	$Players.add_child(bot)
	if multiplayer.is_server(): bot_instance = bot

@rpc("reliable", "any_peer")
func initialize_bot_position_and_rotation(bot_id: int, init_position: Vector2, init_rotation: float) -> void:
	if multiplayer.is_server(): rpc("initialize_bot_position_and_rotation", bot_id, init_position, init_rotation)
	for bot: RigidBody2D in $Players.get_children():
		if bot.get_meta("bot_id", -1) == -1: continue
		if bot.get_meta("bot_id", -1) != bot_id: continue
		bot.global_position = init_position
		bot.rotation = init_rotation
		break

func _on_bot_target_closest_player_delay_timeout() -> void:
	for instance: RigidBody2D in $Players.get_children():
		if not instance.has_meta("bot_id"): continue
		if instance.get_node("Rest").visible == false: continue
		instance.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
		var closest_player: RigidBody2D = get_world_closest_player(instance)
		if closest_player == null: continue
		if closest_player.get_node("Rest").visible == false: continue
		instance.player_node = closest_player
		var instance_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local(instance.position))
		var closest_player_position: Vector2 = get_navigation_closest_player(instance).position
		var closest_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local(closest_player_position))
		instance.is_adjacent_wall_to_player = is_wall_between_cells(instance_cell, closest_cell, 2, true)
