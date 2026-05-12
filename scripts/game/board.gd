class_name Board extends Node

var grid: Array = []
var width: int = 10
var height: int = 20

func _init(w: int = 10, h: int = 20) -> void:
	width = w
	height = h
	reset()

func reset() -> void:
	grid = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(-1)
		grid.append(row)

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func is_cell_empty(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	return grid[y][x] == -1

func is_collision(cells: Array, offset: Vector2i) -> bool:
	for cell in cells:
		var px = cell.x + offset.x
		var py = cell.y + offset.y
		if px < 0 or px >= width or py >= height:
			return true
		if py < 0:
			continue
		if grid[py][px] != -1:
			return true
	return false

func place_piece(cells: Array, offset: Vector2i, type: int) -> void:
	for cell in cells:
		var px = cell.x + offset.x
		var py = cell.y + offset.y
		if px >= 0 and px < width and py >= 0 and py < height:
			grid[py][px] = type

func get_full_rows() -> Array:
	var rows = []
	for y in range(height):
		var full = true
		for x in range(width):
			if grid[y][x] == -1:
				full = false
				break
		if full:
			rows.append(y)
	return rows

func clear_rows(rows: Array) -> void:
	if rows.is_empty():
		return
	rows.sort()
	for row in rows:
		grid.remove_at(row)
		var new_row = []
		for x in range(width):
			new_row.append(-1)
		grid.insert(0, new_row)

func get_cell(x: int, y: int) -> int:
	if is_in_bounds(x, y):
		return grid[y][x]
	return -1

func is_above_board(cells: Array, offset: Vector2i) -> bool:
	for cell in cells:
		var py = cell.y + offset.y
		if py < 0:
			return true
	return false

func is_all_clear() -> bool:
	for y in range(height):
		for x in range(width):
			if grid[y][x] != -1:
				return false
	return true

func get_ghost_position(cells: Array, offset: Vector2i) -> Vector2i:
	var ghost = offset
	while not is_collision(cells, ghost + Vector2i(0, 1)):
		ghost = Vector2i(ghost.x, ghost.y + 1)
	return ghost
