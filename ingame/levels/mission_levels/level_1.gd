extends Node

# there should be a separate function for creating a visual wall at the given ground coordinates
#	and on which side the wall will be adjacent to the ground: it'll help a lot with maze generation later

# wall physics will be a separate thing, however it'll be pretty trivial to implement it for margin walls

func _ready() -> void:
	create_maze_ground_and_margins()

## first vector entry is width, second is height
var min_maze_size: Vector2i = Vector2i(5, 4)
var max_maze_size: Vector2i = Vector2i(10, 7)
var maze_size: Vector2i = Vector2i.ZERO
func create_maze_ground_and_margins() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	maze_size = Vector2i(rng.randi_range(min_maze_size.x, max_maze_size.x), rng.randi_range(min_maze_size.y, max_maze_size.y))
	
	var top_corner: Vector2i = Vector2i(maze_size.x / -2, maze_size.y / -2)
	var bottom_corner: Vector2i = Vector2i(maze_size.x / 2 - 1, maze_size.y / 2 - 1)
	for row: int in range(top_corner.y, bottom_corner.y + 1):
		for column: int in range(top_corner.x, bottom_corner.x + 1):
			var tile_type: int = abs(row + column) % 2
			$Map/Ground.set_cell(Vector2i(column, row), 0, Vector2i(tile_type, 0))
			
			create_maze_margin_wall(row, column, top_corner, bottom_corner)

# this function needs some optimisation; mapping coordinates is pretty tedious nowadays
const MAP_CORNER_COORDS_FACTOR: int = 4
func create_maze_margin_wall(row: int, column: int, top_corner: Vector2i, bottom_corner: Vector2i) -> void:
	# scale ratio has to effectively be an integer(for now, at least)
	var scale_ratio: int = $Map/Ground.scale.x / $Map/WallsHorizontal.scale.x
	
	var abs_offset: float = 0.0 # sorry, magic numbers will be here for now; they depend on scale_ratio
	var total_offset: float = -0.25 # sorry, magic numbers will be here for now; they depend on scale_ratio
	var wall_coordinates_x: float = (sign(column) * (abs(column) + abs_offset) + total_offset) * scale_ratio
	var wall_coordinates_y: float = (sign(row) * (abs(row) + abs_offset) + total_offset) * scale_ratio
	var wall_coordinates: Vector2i = Vector2(wall_coordinates_x, wall_coordinates_y)
	
	# could be optimised to be inside the complete_map_corner() function
	var corner_coordinates: Vector2i = Vector2(column, row) * MAP_CORNER_COORDS_FACTOR
	
	var is_corner: bool = complete_map_corner(corner_coordinates, scale_ratio, top_corner, bottom_corner)
	if is_corner: return ## if given row and column is one of the map's corners, then all work is done
	
	var stretch_offset_vector: Vector2i = Vector2i.ZERO
	if row == top_corner.y or row == bottom_corner.y:
		stretch_offset_vector.x += scale_ratio
		if row == bottom_corner.y: stretch_offset_vector.y += scale_ratio
		for offset: int in range(0, scale_ratio):
			$Map/WallsHorizontal.set_cell(wall_coordinates + stretch_offset_vector + Vector2i(-offset, 0), 1, Vector2i(0, 0), 0)
	elif column == top_corner.x or column == bottom_corner.x:
		stretch_offset_vector.y += scale_ratio
		if column == bottom_corner.x: stretch_offset_vector.x += scale_ratio
		for offset: int in range(0, scale_ratio):
			$Map/WallsVertical.set_cell(wall_coordinates + stretch_offset_vector + Vector2i(0, -offset), 1, Vector2i(0, 0), 1)

func complete_map_corner(corner_coordinates: Vector2i, scale_ratio: int, top_corner: Vector2, bottom_corner: Vector2) -> bool:
	var row: int = corner_coordinates.y / MAP_CORNER_COORDS_FACTOR
	var column: int = corner_coordinates.x / MAP_CORNER_COORDS_FACTOR
	
	## test if given row and column is a corner; if not, then abort
	var false_corner_count: int = 0
	if row != top_corner.y or column != top_corner.x: false_corner_count += 1
	if row != bottom_corner.y or column != bottom_corner.x: false_corner_count += 1
	if row != top_corner.y or column != bottom_corner.x: false_corner_count += 1
	if row != bottom_corner.y or column != top_corner.x: false_corner_count += 1
	if false_corner_count >= 4: return false
	
	$Map/WallsCorners.set_cell(corner_coordinates, 1, Vector2i(1, 0))
	
	var row_offset: int
	var column_offset: int
	## coordinates get weirdly placed everywhere, so the if statements are important
	if row == top_corner.y: row_offset = -1
	if column == top_corner.x: column_offset = -1
	if row == bottom_corner.y: row_offset = scale_ratio - 1
	if column == bottom_corner.x: column_offset = scale_ratio - 1
	for incomplete_row: int in range(0, scale_ratio):
		$Map/WallsHorizontal.set_cell(corner_coordinates + Vector2i(incomplete_row, row_offset), 1, Vector2i(0, 0), 0)
	for incomplete_column: int in range(0, scale_ratio):
		$Map/WallsVertical.set_cell(corner_coordinates + Vector2i(column_offset, incomplete_column), 1, Vector2i(0, 0), 1)
		
	return true
