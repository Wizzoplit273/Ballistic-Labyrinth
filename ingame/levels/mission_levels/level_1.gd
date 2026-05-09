extends Node

## this variable is modified by the parent scene, which is the origin scene(origin.tscn)
var DEBUG_is_checking_maze: bool = false

signal maze_finished

func _ready() -> void:
	create_maze_ground_and_margins()
	generate_maze_with_randomized_prim()
	await maze_finished
	implement_maze_edges_physics()
	implement_maze_walls_physics()
	place_player_on_map()

func _process(_delta: float) -> void: pass

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

func get_maze_primary_wall(map_coordinates: Vector2i, adjacency: int) -> Vector2i:
	if adjacency <= -1 or adjacency >= 4: return Vector2i.ONE * -1
	# scale ratio has to effectively be an integer(for now, at least)
	var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
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
	var scale_ratio: int = $Map/Ground.scale.x / $Map/Walls.scale.x
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
		await get_tree().create_timer(0.02).timeout
		selected_frontier_cell_index = rng.randi_range(0, frontier_cells.size() - 1)
		selected_cell = frontier_cells[selected_frontier_cell_index]
		frontier_cells.remove_at(selected_frontier_cell_index)
		configure_as_maze_cell(selected_cell, maze_cells, frontier_cells)
		i += 1
	maze_finished.emit()

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

#const TEMPORARY_DEBUG_WALL_PHYSICS_TEXTURE_PATH: String = "res://icon.svg"
const TILE_MAZE_WALL_PATH: String = "res://ingame/tiles/tile_maze_wall.png"
var EFFECTIVE_TILE_WIDTH: int = load(TILE_MAZE_WALL_PATH).get_width() - 1
func implement_maze_walls_physics() -> void:
	implement_maze_horizontal_walls_physics()
	implement_maze_vertical_walls_physics()

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

const NEW_BULLET_PATH: String = "res://ingame/projectiles/bullet.tscn"
var bullet_ins: RigidBody2D = null
func _on_player_shoot() -> void:
	if $Player.bullet_count >= $Player.MAX_BULLET_COUNT: return
	bullet_ins = load(NEW_BULLET_PATH).instantiate()
	$Bullets.add_child(bullet_ins)
	bullet_ins.position = $Player.position + Vector2($Player.BULLET_SPAWN_OFFSET, 0).rotated($Player.rotation)
	bullet_ins.apply_central_impulse(Vector2($Player.BULLET_SPEED, 0).rotated($Player.rotation))
	bullet_ins.connect("despawn", on_bullet_despawn)
	bullet_ins.set_meta("owner_id", "player")
	$Player.bullet_count += 1
	

## connected to each bullet's despawn signal
func on_bullet_despawn(node: RigidBody2D) -> void:
	if node.get_meta("owner_id", "NULL") == "player": $Player.bullet_count -= 1
	node.queue_free()
