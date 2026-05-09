extends Node

# wall physics will be a separate thing, however it'll be pretty trivial to implement it for margin walls

func _ready() -> void:
	create_maze_ground_and_margins()
	generate_maze_with_randomized_prim()

## first vector entry is width, second is height
const TILE_SIZE: int = 16
var min_maze_size: Vector2i = Vector2i(10, 6)
var max_maze_size: Vector2i = Vector2i(14, 8)
var maze_size: Vector2i = Vector2i.ZERO
var maze_bottom_corner: Vector2i = Vector2i.ZERO
func create_maze_ground_and_margins() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	maze_size = Vector2i(rng.randi_range(min_maze_size.x, max_maze_size.x), rng.randi_range(min_maze_size.y, max_maze_size.y))
	
	for row: int in range(0, maze_size.y):
		for column: int in range(0, maze_size.x):
			$Map/Ground.set_cell(Vector2i(column, row), 0, Vector2i(0, 0), 1)
			$Camera.position = maze_size * $Map/Ground.scale.x * TILE_SIZE / 2
			create_maze_visual_wall(Vector2i(column, row), 3)
			create_maze_visual_wall(Vector2i(column, row), 2)
			create_maze_visual_wall(Vector2i(column, row), 1)
			create_maze_visual_wall(Vector2i(column, row), 0)

## maze walls are accessed by two variables: one of the adjacent ground cells' map coordinates and
##	an integer that is 0, 1, 2 or 3 that marks on which direction the wall is positioned relative to the first variable

## for adjacency:
##	-	0 means right
##	-	1 means down
##	-	2 means left
##	-	3 means up

func create_maze_visual_wall(map_coordinates: Vector2i, adjacency: int) -> void:
	if adjacency <= -1 or adjacency >= 4: return
	# scale ratio has to effectively be an integer(for now, at least)
	var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
	
	var wall_coordinates: Vector2i
	wall_coordinates.x = (map_coordinates.x - map_coordinates.y) * scale_ratio
	wall_coordinates.y = (map_coordinates.x + map_coordinates.y) * scale_ratio
	if adjacency == 0:
		wall_coordinates.x += 1
		wall_coordinates.y += scale_ratio
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 1)
		wall_coordinates.x -= 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 1)
	if adjacency == 1:
		wall_coordinates.x -= scale_ratio
		wall_coordinates.y += scale_ratio
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 0)
		wall_coordinates.x += 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 0)
	if adjacency == 2:
		wall_coordinates.x -= 1
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 1)
		wall_coordinates.x -= 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 1)
	if adjacency == 3: ## it's already calculated for adjacency == 3 by default
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 0)
		wall_coordinates.x += 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates, 1, Vector2i.ZERO, 0)

func delete_maze_visual_wall(map_coordinates: Vector2i, adjacency: int) -> void:
	if adjacency <= -1 or adjacency >= 4: return
	# scale ratio has to effectively be an integer(for now, at least)
	var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
	
	var wall_coordinates: Vector2i
	wall_coordinates.x = (map_coordinates.x - map_coordinates.y) * scale_ratio
	wall_coordinates.y = (map_coordinates.x + map_coordinates.y) * scale_ratio
	if adjacency == 0:
		wall_coordinates.x += 1
		wall_coordinates.y += scale_ratio
		$Map/Walls.set_cell(wall_coordinates)
		wall_coordinates.x -= 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates)
	if adjacency == 1:
		wall_coordinates.x -= scale_ratio
		wall_coordinates.y += scale_ratio
		$Map/Walls.set_cell(wall_coordinates)
		wall_coordinates.x += 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates)
	if adjacency == 2:
		wall_coordinates.x -= 1
		$Map/Walls.set_cell(wall_coordinates)
		wall_coordinates.x -= 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates)
	if adjacency == 3: ## it's already calculated for adjacency == 3 by default
		$Map/Walls.set_cell(wall_coordinates)
		wall_coordinates.x += 1
		wall_coordinates.y += 1
		$Map/Walls.set_cell(wall_coordinates)

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
		selected_frontier_cell_index = rng.randi_range(0, frontier_cells.size() - 1)
		selected_cell = frontier_cells[selected_frontier_cell_index]
		frontier_cells.remove_at(selected_frontier_cell_index)
		configure_as_maze_cell(selected_cell, maze_cells, frontier_cells)
		await get_tree().create_timer(0.02).timeout
		i += 1

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
