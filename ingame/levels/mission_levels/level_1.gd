extends Node

# there should be a separate function for creating a visual wall at the given ground coordinates
#	and on which side the wall will be adjacent to the ground: it'll help a lot with maze generation later

# wall physics will be a separate thing, however it'll be pretty trivial to implement it for margin walls

func _ready() -> void:
	create_maze_ground_and_margins()

## first vector entry is width, second is height
const TILE_SIZE: int = 16
var min_maze_size: Vector2i = Vector2i(5, 4)
var max_maze_size: Vector2i = Vector2i(10, 7)
var maze_size: Vector2i = Vector2i.ZERO
var maze_bottom_corner: Vector2i = Vector2i.ZERO
func create_maze_ground_and_margins() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	maze_size = Vector2i(rng.randi_range(min_maze_size.x, max_maze_size.x), rng.randi_range(min_maze_size.y, max_maze_size.y))
	
	print(maze_size)
	for row: int in range(0, maze_size.y ):
		for column: int in range(0, maze_size.x):
			var tile_type: int = abs(row + column) % 2
			$Map/Ground.set_cell(Vector2i(column, row), 0, Vector2i(tile_type, 0))
			$Camera.position = maze_size * $Map/Ground.scale.x * TILE_SIZE / 2
			
			if row == 0: create_maze_visual_wall(Vector2i(column, row), 3)
			if column == 0: create_maze_visual_wall(Vector2i(column, row), 2)
			if row == maze_size.x - 1: create_maze_visual_wall(Vector2i(column, row), 1)
			if column == maze_size.y - 1: create_maze_visual_wall(Vector2i(column, row), 0)

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
	print("adjacency: ", adjacency, " coords: ", wall_coordinates)
