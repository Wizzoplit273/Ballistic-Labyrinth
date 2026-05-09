extends Node

## those variables are modified by the origin scene(origin.tscn)
var DEBUG_is_checking_maze: bool = false
var DEBUG_is_showing_dodging: bool = false
var min_maze_size: Vector2i = Vector2i.ZERO
var max_maze_size: Vector2i = Vector2i.ZERO
var wall_remove_interval: Vector2i = Vector2i.ZERO
var enemy_count_interval: Vector2i = Vector2i.ZERO
var enemy_friendly_fire: bool = true

signal dimensions_finished
signal generation_finished
signal wall_remove_finished

@onready var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
## called by the origin scene after initial configuration
func modified_ready() -> void:
	initialize_score_ui()
	create_maze_ground_and_margins()
	await dimensions_finished
	generate_maze_with_randomized_prim()
	await generation_finished
	remove_random_maze_walls()
	await wall_remove_finished
	implement_maze_edges_physics()
	implement_maze_walls_physics()
	implement_navigation()
	place_player_on_map()
	place_enemies_on_map()

const SCROLL_VALUE: float = 1.1
func _process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if Input.is_action_just_pressed("ScrollUp"):
		$Camera.zoom *= SCROLL_VALUE
	if Input.is_action_just_pressed("ScrollDown"):
		$Camera.zoom /= SCROLL_VALUE
	for instance: RigidBody2D in $Enemies.get_children():
		instance.DEBUG_is_showing_dodging = DEBUG_is_showing_dodging
		var player_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local($Player.position))
		var enemy_cell: Vector2i = $Map/Ground.local_to_map($Map/Ground.to_local(instance.position))
		instance.is_adjacent_wall_to_player = is_wall_between_cells(player_cell, enemy_cell, 2, true)

func initialize_score_ui() -> void:
	%PlayerScore.text = str(player_score)
	%EnemyScore.text = str(enemy_score)


const TILE_SIZE: int = 16

## first vector entry is width, second is height
var maze_size: Vector2i = Vector2i.ZERO
var maze_bottom_corner: Vector2i = Vector2i.ZERO
func create_maze_ground_and_margins() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	maze_size = Vector2i(rng.randi_range(min_maze_size.x, max_maze_size.x), rng.randi_range(min_maze_size.y, max_maze_size.y))
	if maze_size.x < maze_size.y:
		var auxiliary: int = maze_size.x
		maze_size.x = maze_size.y
		maze_size.y = auxiliary
	$Map/Ground/MazeDimensionsLabel.text = "Width: " + str(maze_size.x)
	$Map/Ground/MazeDimensionsLabel.text += "\nHeight: " + str(maze_size.y)
	$Camera.zoom = Vector2.ONE / maze_size.y * 6
	$Camera.scale.x = 1 / $Camera.zoom.x
	$Camera.scale.y = 1 / $Camera.zoom.y
	for row: int in range(0, maze_size.y):
		for column: int in range(0, maze_size.x):
			await get_tree().create_timer(0.01).timeout
			$DimensionsGenerationNoise.play()
			$Map/Ground.set_cell(Vector2i(column, row), 0, Vector2i(0, 0), 1)
			$Camera.position = maze_size * $Map/Ground.scale.x * TILE_SIZE / 2
			create_maze_visual_wall(Vector2i(column, row), 3)
			create_maze_visual_wall(Vector2i(column, row), 2)
			create_maze_visual_wall(Vector2i(column, row), 1)
			create_maze_visual_wall(Vector2i(column, row), 0)
	dimensions_finished.emit()

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

func delete_maze_visual_wall(map_coordinates: Vector2i, adjacency: int) -> void:
	if adjacency <= -1 or adjacency >= 4: return
	var wall_coordinates: Vector2i = get_maze_primary_wall(map_coordinates, adjacency)
	$Map/Walls.set_cell(wall_coordinates)
	wall_coordinates += get_maze_primary_wall_increment(adjacency)
	$Map/Walls.set_cell(wall_coordinates)

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
func modify_physics_wall_length(wall_node: StaticBody2D, wall_increment: int, direction: int) -> void:
	if direction <= -1 or direction >= 4: return
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var selected_cell: Vector2i
	## all vector entries should be integers, but this is what Godot offers for optimisation
	var maze_cells: PackedVector2Array
	var frontier_cells: PackedVector2Array
	selected_cell.x = rng.randi_range(0, maze_size.x - 1)
	selected_cell.y = rng.randi_range(0, maze_size.y - 1)
	if (selected_cell.x + selected_cell.y) % 2 == 0:
		$Map/Ground.set_cell(selected_cell, 0, Vector2i(0, 0), 0)
	else: $Map/Ground.set_cell(selected_cell, 0, Vector2i(1, 0), 0)
	maze_cells.append(selected_cell)
	if $Map/Ground.get_cell_source_id(selected_cell + Vector2i.RIGHT) != -1:
		frontier_cells.append(selected_cell + Vector2i.RIGHT)
		delete_maze_visual_wall(selected_cell, 0)
	if $Map/Ground.get_cell_source_id(selected_cell + Vector2i.DOWN) != -1:
		frontier_cells.append(selected_cell + Vector2i.DOWN)
		delete_maze_visual_wall(selected_cell, 1)
	if $Map/Ground.get_cell_source_id(selected_cell + Vector2i.LEFT) != -1:
		frontier_cells.append(selected_cell + Vector2i.LEFT)
		delete_maze_visual_wall(selected_cell, 2)
	if $Map/Ground.get_cell_source_id(selected_cell + Vector2i.UP) != -1:
		frontier_cells.append(selected_cell + Vector2i.UP)
		delete_maze_visual_wall(selected_cell, 3)
	var selected_frontier_cell_index: int
	var i: int = 0
	while frontier_cells.size() != 0:
		await get_tree().create_timer(0.01).timeout
		$MazeGenerationNoise.play()
		selected_frontier_cell_index = rng.randi_range(0, frontier_cells.size() - 1)
		selected_cell = frontier_cells[selected_frontier_cell_index]
		frontier_cells.remove_at(selected_frontier_cell_index)
		configure_as_maze_cell(selected_cell, maze_cells, frontier_cells)
		i += 1
	generation_finished.emit()

func configure_as_maze_cell(selected_cell: Vector2i, maze_cells: PackedVector2Array, frontier_cells: PackedVector2Array) -> void:
	maze_cells.append(selected_cell)
	if (selected_cell.x + selected_cell.y) % 2 == 0:
		$Map/Ground.set_cell(selected_cell, 0, Vector2i(0, 0), 0)
	else: $Map/Ground.set_cell(selected_cell, 0, Vector2i(1, 0), 0)
	
	## remove one adjacent maze cell's wall
	## only one adjacent wall will be deleted(at least for now)
	## it will always yield at least one because the selected cell is a former frontier cell
	var num_neighboring_maze_cells: int = 0
	var possible_directions: Array[int] ## min size should be 1, max size should be 4
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var neighboring_cell_offset: Vector2i = Vector2i.RIGHT
	var selected_neighbor_cell: Vector2i
	for index: int in range(4):
		selected_neighbor_cell = selected_cell + Vector2i(neighboring_cell_offset)
		if $Map/Ground.get_cell_source_id(selected_neighbor_cell) != -1:
			if maze_cells.find(selected_neighbor_cell) != -1:
				num_neighboring_maze_cells += 1
				possible_directions.append(index)
		neighboring_cell_offset = rotate_integer_vector(neighboring_cell_offset)
	var random_direction: int = possible_directions[rng.randi_range(0, num_neighboring_maze_cells - 1)]
	delete_maze_visual_wall(selected_cell, random_direction)
	
	## mark neighboring cells as frontier cells
	neighboring_cell_offset = Vector2i.RIGHT
	for i: int in range(4):
		selected_neighbor_cell = selected_cell + neighboring_cell_offset
		if $Map/Ground.get_cell_source_id(selected_neighbor_cell) != -1:
			if frontier_cells.find(selected_neighbor_cell) == -1:
				# this third if statement is a temporary fix for the problem of frontier cells not being removed when
				#	transformed to maze cells
				if maze_cells.find(selected_neighbor_cell) == -1:
					$Map/Ground.set_cell(selected_neighbor_cell, 0, Vector2i(0, 0), 2)
					frontier_cells.append(selected_neighbor_cell)
		neighboring_cell_offset = rotate_integer_vector(neighboring_cell_offset)

func rotate_integer_vector(vector: Vector2i) -> Vector2i:
	if vector == Vector2i.RIGHT: return Vector2i.DOWN
	if vector == Vector2i.DOWN: return Vector2i.LEFT
	if vector == Vector2i.LEFT: return Vector2i.UP
	if vector == Vector2i.UP: return Vector2i.RIGHT
	return Vector2i.ZERO ## invalid input handler

func remove_random_maze_walls() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	#if maze_size.x + maze_size.y >= 32:
		#wall_removed_interval = Vector2i(10, 25)
	#elif maze_size.x + maze_size.y >= 20:
		#removed_walls_interval = Vector2i(4, 10)
	#else: #maze_size.x + maze_size.y <= 15:
		#removed_walls_interval = Vector2i(0, 6)
	var remove_count: int = rng.randi_range(wall_remove_interval.x, wall_remove_interval.y)
	await get_tree().create_timer(0).timeout
	if remove_count == 0: ## the for loop stops working when remove_count is 0 for some reason
		wall_remove_finished.emit()
		return
	for index: int in range(0, remove_count):
		await get_tree().create_timer(0.03).timeout
		$WallRemoveNoise.play()
		var random_cell: Vector2i = maze_size - Vector2i.ONE
		var wall_does_not_exist: bool = true # temporarily modified so a cell has to have at least two adjacent walls
		while wall_does_not_exist or random_cell == maze_size - Vector2i.ONE:
			var wall_count: int = 0
			for adjacency: int in range(0, 3):
				if maze_visual_wall_exists(random_cell, adjacency): wall_count += 1
			wall_does_not_exist = wall_count <= 1 # temporarily modified so a cell has to have at least two adjacent walls
			random_cell = Vector2i(rng.randi_range(0, maze_size.x - 1), rng.randi_range(0, maze_size.y - 1))
		if random_cell.x == maze_size.x - 1:
			delete_maze_visual_wall(random_cell, 1)
			continue
		if random_cell.y == maze_size.y - 1:
			delete_maze_visual_wall(random_cell, 0)
			continue
		delete_maze_visual_wall(random_cell, rng.randi_range(0, 1))
	wall_remove_finished.emit()

func implement_maze_edges_physics() -> void:
	var maze_corner: Vector2
	maze_corner.x = maze_size.x * $Map/Ground.scale.x * $Map/Ground.scale.x / $Map/Walls.scale.x
	maze_corner.y = maze_size.y * $Map/Ground.scale.y * $Map/Ground.scale.y / $Map/Walls.scale.y
	
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
	for body: StaticBody2D in $Map/PhysicsWalls.get_children():
		body.set_meta("type", "wall")

func new_collision_shape() -> CollisionShape2D:
	var physics_shape_ref: CollisionShape2D = CollisionShape2D.new()
	var shape_ref: RectangleShape2D = RectangleShape2D.new()
	#var temporary_debug: Texture2D = load(TEMPORARY_DEBUG_WALL_PHYSICS_TEXTURE_PATH)
	shape_ref.set_size(Vector2.ONE)
	physics_shape_ref.shape = shape_ref
	return physics_shape_ref

func implement_maze_horizontal_walls_physics() -> void:
	var selected_cell: Vector2i
	var is_extending_wall: bool
	var physics_wall_ins: StaticBody2D
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
				physics_wall_ins = StaticBody2D.new()
				var collision_shape: CollisionShape2D = new_collision_shape()
				physics_wall_ins.add_child(collision_shape)
				$Map/PhysicsWalls.add_child(physics_wall_ins)
				physics_wall_ins.owner = self
				physics_wall_ins.position = get_visual_wall_world_coordinates(selected_cell, 1)
				physics_wall_ins.scale.x = EFFECTIVE_TILE_WIDTH
				is_extending_wall = true
				continue
			if maze_visual_wall_exists(selected_cell, 1) and is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can extend!")
				modify_physics_wall_length(physics_wall_ins, 1, 3)
			if not maze_visual_wall_exists(selected_cell, 1):
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\t\tVISUAL WALL DOESN'T EXIST HERE...")
				is_extending_wall = false

func implement_maze_vertical_walls_physics() -> void:
	var selected_cell: Vector2i
	var is_extending_wall: bool
	var physics_wall_ins: StaticBody2D
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
				physics_wall_ins = StaticBody2D.new()
				var collision_shape: CollisionShape2D = new_collision_shape()
				physics_wall_ins.add_child(collision_shape)
				$Map/PhysicsWalls.add_child(physics_wall_ins)
				physics_wall_ins.owner = self
				physics_wall_ins.position = get_visual_wall_world_coordinates(selected_cell, 0)
				physics_wall_ins.scale.y = EFFECTIVE_TILE_WIDTH
				is_extending_wall = true
				continue
			if maze_visual_wall_exists(selected_cell, 0) and is_extending_wall:
				if OS.is_debug_build() and DEBUG_is_checking_maze:
					print("\t\tvisual wall exists and can extend!")
				modify_physics_wall_length(physics_wall_ins, 1, 0)
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

const GROUND_TILE_SET: String = "res://ingame/tiles/ground_tileset.tres"
const OFFSET_SUBTRACT: float = 20.0
func place_player_on_map() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var selected_cell: Vector2i
	var ground_tile_size: Vector2i = load(GROUND_TILE_SET).tile_size
	selected_cell.x = rng.randi_range(0, maze_size.x - 1)
	selected_cell.y = rng.randi_range(0, maze_size.y - 1)
	var selected_position: Vector2 = $Map/Ground.map_to_local(selected_cell)
	selected_position.x *= $Map/Ground.scale.x
	selected_position.y *= $Map/Ground.scale.y
	$Player.position = selected_position
	var offset_vector: Vector2
	var max_offset_scalar: Vector2 = $Map/Ground.scale / 2 - Vector2.ONE * OFFSET_SUBTRACT
	offset_vector.x = rng.randf_range(-max_offset_scalar.x, max_offset_scalar.x)
	offset_vector.y = rng.randf_range(-max_offset_scalar.y, max_offset_scalar.y)
	$Player.position += offset_vector
	$Player.rotation = rng.randf_range(0, PI * 2)
	$Player.visible = true
	$Player.process_mode = Node.PROCESS_MODE_INHERIT
	alive_players_count = 1

@export var MIN_SPAWNPOINT_DISTANCING: float = 400.0
var enemy_count: int
const NEW_ENEMY_INSTANCE_PATH: String = "res://ingame/entities/enemy/enemy.tscn"
func place_enemies_on_map() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# enemy_count_interval selection is temporary, this can be optimised later
	#if maze_size.x + maze_size.y >= 32:
		#enemy_count_interval = Vector2i(6, 9)
	#elif maze_size.x + maze_size.y >= 20:
		#enemy_count_interval = Vector2i(3, 5)
	#else: #maze_size.x + maze_size.y >= 15:
		#enemy_count_interval = Vector2i(1, 3)
	enemy_count = rng.randi_range(enemy_count_interval.x, enemy_count_interval.y)
	var enemy_instance: RigidBody2D = null
	for index: int in range(0, enemy_count):
		enemy_instance = load(NEW_ENEMY_INSTANCE_PATH).instantiate()
		$Enemies.add_child(enemy_instance)
		enemy_instance.global_position = $Player.global_position
		while ($Player.global_position - enemy_instance.global_position).length() <= MIN_SPAWNPOINT_DISTANCING:
			enemy_instance.process_mode = Node.PROCESS_MODE_DISABLED
			enemy_instance.visible = false
			var selected_cell: Vector2i
			var ground_tile_size: Vector2i = load(GROUND_TILE_SET).tile_size
			selected_cell.x = rng.randi_range(0, maze_size.x - 1)
			selected_cell.y = rng.randi_range(0, maze_size.y - 1)
			var selected_position: Vector2 = $Map/Ground.map_to_local(selected_cell)
			selected_position.x *= $Map/Ground.scale.x
			selected_position.y *= $Map/Ground.scale.y
			enemy_instance.position = selected_position
			var offset_vector: Vector2
			var max_offset_scalar: Vector2 = $Map/Ground.scale / 2 - Vector2.ONE * OFFSET_SUBTRACT
			offset_vector.x = rng.randf_range(-max_offset_scalar.x, max_offset_scalar.x)
			offset_vector.y = rng.randf_range(-max_offset_scalar.y, max_offset_scalar.y)
			enemy_instance.position += offset_vector
			enemy_instance.rotation = rng.randf_range(0, PI * 2)
			enemy_instance.visible = true
			enemy_instance.player_node = $Player
			enemy_instance.enemy_friendly_fire = enemy_friendly_fire
			if not enemy_instance.is_connected("shoot", _on_enemy_shoot):
				enemy_instance.connect("shoot", _on_enemy_shoot)
			if not enemy_instance.is_connected("level_die", _on_enemy_level_die):
				enemy_instance.connect("level_die", _on_enemy_level_die)
			enemy_instance.process_mode = Node.PROCESS_MODE_INHERIT
			#enemy_instance.get_node("Rest/Image").scale += Vector2.ONE * rng.randf_range(-0.1, 0.1)
		alive_enemies_count = enemy_count

const NEW_BULLET_PATH: String = "res://ingame/entities/projectiles/bullet.tscn"
var bullet_ins: RigidBody2D = null
func _on_player_shoot() -> void:
	if $Player.bullet_count >= $Player.MAX_BULLET_COUNT:
		$NoAmmoNoise.play()
		return
	$NormalShootNoise.play()
	bullet_ins = load(NEW_BULLET_PATH).instantiate()
	bullet_ins.initial_velocity_direction = $Player.rotation
	$Bullets.add_child(bullet_ins)
	bullet_ins.position = $Player.position + Vector2($Player.BULLET_SPAWN_OFFSET, 0).rotated($Player.rotation)
	bullet_ins.apply_central_impulse(Vector2($Player.BULLET_SPEED, 0).rotated($Player.rotation))
	bullet_ins.connect("despawn", on_bullet_despawn)
	bullet_ins.owner_node = $Player
	$Player.bullet_count += 1

func _on_enemy_shoot(enemy_node: RigidBody2D) -> void:
	if enemy_node.bullet_count >= enemy_node.MAX_BULLET_COUNT:
		$NoAmmoNoise.play()
		return
	$NormalShootNoise.play()
	bullet_ins = load(NEW_BULLET_PATH).instantiate()
	bullet_ins.initial_velocity_direction = enemy_node.rotation
	$Bullets.add_child(bullet_ins)
	bullet_ins.position = enemy_node.position + Vector2(enemy_node.BULLET_SPAWN_OFFSET, 0).rotated(enemy_node.rotation)
	bullet_ins.apply_central_impulse(Vector2(enemy_node.BULLET_SPEED, 0).rotated(enemy_node.rotation))
	bullet_ins.connect("despawn", on_bullet_despawn)
	bullet_ins.owner_node = enemy_node
	enemy_node.bullet_count += 1

## connected to each bullet's despawn signal
func on_bullet_despawn(bullet: RigidBody2D) -> void:
	# it'll probably be a single if statement in the future, there is no good reason to distinguish between
	# players and enemies inside this function
	if bullet.owner_node.get_meta("type", "NULL") == "player": $Player.bullet_count -= 1
	if bullet.owner_node.get_meta("type", "NULL") == "enemy": bullet.owner_node.bullet_count -= 1
	#node.queue_free()

var alive_players_count: int
var alive_enemies_count: int

## scores are initialised by the origin scene
var player_score: int = 0
var enemy_score: int = 0

func _on_player_level_die() -> void:
	alive_players_count -= 1
	$DeathNoise.play()
	$DeathDelay.start()

func _on_enemy_level_die() -> void:
	alive_enemies_count -= 1
	$DeathNoise.play()
	$DeathDelay.start()

func _on_death_delay_timeout() -> void:
	if alive_players_count != 0 and alive_enemies_count != 0: return
	if alive_players_count == alive_enemies_count and alive_players_count == 0:
		%DrawTitle.visible = true
		$NextRoundDelay.start()
		$NextRoundNoise.play()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	if alive_players_count == 0:
		enemy_score += 1
		%EnemyScore.text = str(enemy_score)
	if alive_enemies_count == 0:
		player_score += 1
		%PlayerScore.text = str(player_score)
	$NextRoundDelay.start()
	$NextRoundNoise.play()
	process_mode = Node.PROCESS_MODE_DISABLED

signal next_round(player_score: int, enemy_score: int)
func _on_next_round_delay_timeout() -> void:
	next_round.emit(player_score, enemy_score)
	queue_free()
