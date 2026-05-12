class_name BoardRenderer extends Control

var game_ref: Game
var cell_size: int = Global.CELL_SIZE
var board_width: int = Global.BOARD_WIDTH
var board_height: int = Global.BOARD_HEIGHT

var border_color: Color = Color(0.3, 0.3, 0.35)
var bg_color: Color = Color(0.12, 0.12, 0.15)
var grid_color: Color = Color(0.18, 0.18, 0.22)

var board_offset_x: int = 0
var board_offset_y: int = 0

var smooth_piece_y: float = 0.0
var prev_piece_y: int = 0

var line_clear_progress: float = -1.0
var clearing_rows: Array = []
var clear_flash_count: int = 0
var screen_shake: float = 0.0

var lock_flash_timer: float = 0.0
var lock_flash_cells: Array = []
var lock_flash_pos: Vector2i
var lock_flash_type: int = -1

var hard_drop_trail: Array = []
var drop_trail_timer: float = 0.0

func _ready() -> void:
	var s = Vector2(
		(board_width + 2) * cell_size,
		(board_height + 2) * cell_size
	)
	custom_minimum_size = s
	size = s

func set_game(game: Game) -> void:
	game_ref = game
	if game_ref:
		game_ref.piece_locked.connect(_on_piece_locked)

func _on_piece_locked() -> void:
	if not game_ref:
		return
	lock_flash_cells = game_ref.current_cells.duplicate()
	lock_flash_pos = game_ref.current_pos
	lock_flash_type = game_ref.current_type
	lock_flash_timer = 0.15

	var rows = game_ref.board.get_full_rows()
	if not rows.is_empty():
		line_clear_progress = 0.0
		clearing_rows = rows.duplicate()
		clear_flash_count = 0
		screen_shake = 1.0

func _process(delta: float) -> void:
	if game_ref and game_ref.current_type >= 0 and game_ref.state != 3:
		var target = float(game_ref.current_pos.y)
		if abs(smooth_piece_y - target) > 8.0:
			smooth_piece_y = target
		else:
			smooth_piece_y = lerp(smooth_piece_y, target, 1.0 - exp(-25.0 * delta))

	if lock_flash_timer > 0:
		lock_flash_timer -= delta

	if line_clear_progress >= 0:
		line_clear_progress += delta
		if line_clear_progress >= 0.15:
			clear_flash_count += 1
			line_clear_progress = 0.0
			if clear_flash_count >= 2:
				line_clear_progress = -1.0
				clearing_rows.clear()

	if hard_drop_trail.size() > 0:
		drop_trail_timer -= delta
		if drop_trail_timer <= 0:
			hard_drop_trail.clear()

	if screen_shake > 0:
		screen_shake -= delta * 4.0
		if screen_shake < 0:
			screen_shake = 0.0

	queue_redraw()

func _draw() -> void:
	var shake_off = Vector2i(0, 0)
	if screen_shake > 0:
		shake_off = Vector2i(randi() % 4 - 2, randi() % 4 - 2)

	board_offset_x = cell_size + shake_off.x
	board_offset_y = cell_size + shake_off.y

	draw_border()
	draw_grid()
	draw_board_cells()
	draw_hard_drop_trail()
	if game_ref and game_ref.state != 3:
		draw_ghost()
		draw_current_piece()
	draw_lock_flash()
	draw_line_clear_animation()

func draw_border() -> void:
	var rect = Rect2(
		board_offset_x - 2, board_offset_y - 2,
		board_width * cell_size + 4, board_height * cell_size + 4
	)
	draw_rect(rect, border_color, false, 2.0)

func draw_grid() -> void:
	draw_rect(Rect2(board_offset_x, board_offset_y, board_width * cell_size, board_height * cell_size), bg_color)

	for x in range(board_width + 1):
		var lx = board_offset_x + x * cell_size
		draw_line(Vector2(lx, board_offset_y), Vector2(lx, board_offset_y + board_height * cell_size), grid_color)
	for y in range(board_height + 1):
		var ly = board_offset_y + y * cell_size
		draw_line(Vector2(board_offset_x, ly), Vector2(board_offset_x + board_width * cell_size, ly), grid_color)

func draw_board_cells() -> void:
	if not game_ref:
		return
	for y in range(board_height):
		if line_clear_progress >= 0 and clearing_rows.has(y):
			continue
		for x in range(board_width):
			var cell_type = game_ref.board.get_cell(x, y)
			if cell_type >= 0:
				draw_cell(x, y, PieceData.get_color(cell_type))

func draw_current_piece() -> void:
	if not game_ref or game_ref.current_type < 0:
		return
	var color = PieceData.get_color(game_ref.current_type)
	var cells = game_ref.current_cells
	var pos = game_ref.current_pos
	var y_off = smooth_piece_y - float(pos.y)
	for cell in cells:
		var px = cell.x + pos.x
		var pyf = cell.y + pos.y + y_off
		if pyf + 1.0 >= 0:
			draw_cell_f(px, pyf, color)

func draw_ghost() -> void:
	if not game_ref or game_ref.current_type < 0:
		return
	var cells = game_ref.current_cells
	var gpos = game_ref.ghost_pos
	var color = PieceData.get_color(game_ref.current_type)
	color.a = PieceData.GHOST_ALPHA
	for cell in cells:
		var px = cell.x + gpos.x
		var py = cell.y + gpos.y
		if py >= 0:
			draw_cell(px, py, color, true)

func draw_lock_flash() -> void:
	if lock_flash_timer <= 0 or lock_flash_type < 0:
		return
	var t = lock_flash_timer / 0.15
	var alpha = t * 0.7
	for cell in lock_flash_cells:
		var px = cell.x + lock_flash_pos.x
		var py = cell.y + lock_flash_pos.y
		if py >= 0:
			draw_cell(px, py, Color(1, 1, 1, alpha))

func draw_line_clear_animation() -> void:
	if line_clear_progress < 0:
		return
	var flash = (sin(line_clear_progress * 30.0) * 0.5 + 0.5) * 0.7
	var c = Color(1, 1, 1, flash)
	for row in clearing_rows:
		draw_rect(Rect2(board_offset_x, board_offset_y + row * cell_size, board_width * cell_size, cell_size), c)

func draw_hard_drop_trail() -> void:
	if hard_drop_trail.is_empty():
		return
	for point in hard_drop_trail:
		var c = Color(1, 1, 1, 0.2)
		draw_rect(Rect2(board_offset_x + point.x * cell_size, board_offset_y + point.y * cell_size, cell_size, cell_size), c)

func draw_cell(x: int, y: int, color: Color, ghost: bool = false) -> void:
	var p = 1
	var rect = Rect2(
		board_offset_x + x * cell_size + p,
		board_offset_y + y * cell_size + p,
		cell_size - p * 2, cell_size - p * 2
	)
	if ghost:
		draw_rect(rect, Color(color.r, color.g, color.b, PieceData.GHOST_ALPHA), false, 2.0)
		return

	draw_rect(rect, color)

	var light = Color(minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), light)
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), light)

	var dark = Color(maxf(color.r - 0.3, 0.0), maxf(color.g - 0.3, 0.0), maxf(color.b - 0.3, 0.0))
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 2), Vector2(rect.size.x, 2)), dark)
	draw_rect(Rect2(Vector2(rect.end.x - 2, rect.position.y), Vector2(2, rect.size.y)), dark)

func draw_cell_f(x: int, yf: float, color: Color) -> void:
	var p = 1
	var rect = Rect2(
		board_offset_x + x * cell_size + p,
		board_offset_y + int(round(yf)) * cell_size + p,
		cell_size - p * 2, cell_size - p * 2
	)
	draw_rect(rect, color)

	var light = Color(minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), light)
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), light)

	var dark = Color(maxf(color.r - 0.3, 0.0), maxf(color.g - 0.3, 0.0), maxf(color.b - 0.3, 0.0))
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 2), Vector2(rect.size.x, 2)), dark)
	draw_rect(Rect2(Vector2(rect.end.x - 2, rect.position.y), Vector2(2, rect.size.y)), dark)

func draw_piece_preview(type: int, x: int, y: int, sz: int) -> void:
	if type < 0:
		return
	var color = PieceData.get_color(type)
	var shape = PieceData.get_shape(type, 0)
	for i in 16:
		if shape[i] == 1:
			var cx = (i % 4) * sz + x
			var cy = (i >> 2) * sz + y
			draw_rect(Rect2(cx, cy, sz - 1, sz - 1), color)

func trigger_hard_drop_trail(from_y: int, to_y: int, cells: Array, offset: Vector2i) -> void:
	hard_drop_trail.clear()
	for cell in cells:
		var px = cell.x + offset.x
		for y in range(from_y, to_y):
			var py = cell.y + y
			if py >= 0:
				hard_drop_trail.append(Vector2i(px, py))
	drop_trail_timer = 0.15
