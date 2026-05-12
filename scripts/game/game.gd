class_name Game extends Node

enum State { FALLING, LOCKING, CLEARING, GAME_OVER }

var board: Board
var current_type: int = -1
var current_rotation: int = 0
var current_pos: Vector2i
var current_cells: Array = []
var ghost_pos: Vector2i

var hold_type: int = -1
var hold_used: bool = false
var next_queue: Array = []
var bag: Array = []

var state: int = State.FALLING

var drop_timer: float = 0.0
var lock_timer: float = 0.0
var lock_moves_left: int = 0
var clear_timer: float = 0.0
var clearing_rows: Array = []
var clear_flash: float = 0.0

var das_timer: float = 0.0
var arr_timer: float = 0.0
var das_dir: int = 0
var das_charged: bool = false
var soft_dropping: bool = false
var _last_move_was_rotation: bool = false

var game_over_timer: float = 0.0
var start_time_msec: int = 0
var combo_count: int = -1
var _last_was_big: bool = false
var _cleared_this_lock: bool = false

signal piece_locked
signal lines_cleared(count: int, is_tspin: bool)
signal game_over
signal hard_dropped(from_y: int, to_y: int)
signal combo(count: int)
signal all_clear
signal back_to_back(is_tspin: bool, count: int)

func _init() -> void:
	board = Board.new(Global.BOARD_WIDTH, Global.BOARD_HEIGHT)

func start() -> void:
	board.reset()
	current_type = -1
	hold_type = -1
	hold_used = false
	bag = []
	next_queue = []
	Global.score = 0
	Global.lines = 0
	Global.level = 1
	Global.ultra_time_left = 120.0
	start_time_msec = Time.get_ticks_msec()
	combo_count = -1
	_last_was_big = false
	_cleared_this_lock = false
	state = State.FALLING
	
	for i in range(Global.PREVIEW_COUNT + 1):
		next_queue.append(pull_from_bag())
	spawn_piece()

func pull_from_bag() -> int:
	if bag.is_empty():
		bag = [0, 1, 2, 3, 4, 5, 6]
		bag.shuffle()
	return bag.pop_front()

func spawn_piece() -> void:
	if next_queue.is_empty():
		next_queue.append(pull_from_bag())
	current_type = next_queue[0]
	next_queue.remove_at(0)
	next_queue.append(pull_from_bag())
	
	current_rotation = 0
	current_pos = PieceData.get_spawn_position(current_type)
	current_cells = PieceData.get_cells(current_type, current_rotation)
	hold_used = false
	
	if board.is_collision(current_cells, current_pos):
		state = State.GAME_OVER
		game_over_timer = 0.0
		return
	
	update_ghost()
	state = State.FALLING
	drop_timer = 0.0
	lock_timer = 0.0
	lock_moves_left = 15
	soft_dropping = false

func update_ghost() -> void:
	ghost_pos = board.get_ghost_position(current_cells, current_pos)

func get_next_piece(i: int) -> int:
	if i < next_queue.size():
		return next_queue[i]
	return -1

func hold() -> void:
	if hold_used:
		return
	hold_used = true
	Audio.play_hold()
	if hold_type == -1:
		hold_type = current_type
		current_type = next_queue[0]
		next_queue.remove_at(0)
		next_queue.append(pull_from_bag())
	else:
		var tmp = hold_type
		hold_type = current_type
		current_type = tmp
	current_rotation = 0
	current_pos = PieceData.get_spawn_position(current_type)
	current_cells = PieceData.get_cells(current_type, current_rotation)
	
	if board.is_collision(current_cells, current_pos):
		state = State.GAME_OVER
		game_over_timer = 0.0
		return
	
	update_ghost()
	state = State.FALLING
	drop_timer = 0.0
	lock_timer = 0.0
	lock_moves_left = 15

func move_left() -> void:
	if state != State.FALLING and state != State.LOCKING:
		return
	var new_pos = current_pos + Vector2i(-1, 0)
	if not board.is_collision(current_cells, new_pos):
		current_pos = new_pos
		update_ghost()
		_last_move_was_rotation = false
		Audio.play_move()
		if state == State.LOCKING:
			lock_timer = 0.0
			lock_moves_left -= 1
			if lock_moves_left <= 0:
				lock()

func move_right() -> void:
	if state != State.FALLING and state != State.LOCKING:
		return
	var new_pos = current_pos + Vector2i(1, 0)
	if not board.is_collision(current_cells, new_pos):
		current_pos = new_pos
		update_ghost()
		_last_move_was_rotation = false
		Audio.play_move()
		if state == State.LOCKING:
			lock_timer = 0.0
			lock_moves_left -= 1
			if lock_moves_left <= 0:
				lock()

func hard_drop() -> void:
	if state != State.FALLING and state != State.LOCKING:
		return
	var from_y = current_pos.y
	while not board.is_collision(current_cells, current_pos + Vector2i(0, 1)):
		current_pos = Vector2i(current_pos.x, current_pos.y + 1)
	hard_dropped.emit(from_y, current_pos.y)
	Audio.play_hard_drop()
	lock()

func rotate(direction: int) -> void:
	if state != State.FALLING and state != State.LOCKING:
		return
	var from_rot = current_rotation
	var to_rot = (current_rotation + direction + 4) % 4
	var kicks = PieceData.get_wall_kicks(current_type, from_rot, to_rot)
	var new_cells = PieceData.get_cells(current_type, to_rot)
	
	for kick in kicks:
		var test_pos = current_pos + Vector2i(kick[0], -kick[1])
		if not board.is_collision(new_cells, test_pos):
			current_rotation = to_rot
			current_cells = new_cells
			current_pos = test_pos
			update_ghost()
			_last_move_was_rotation = true
			Audio.play_rotate()
			if state == State.LOCKING:
				lock_timer = 0.0
				lock_moves_left -= 1
				if lock_moves_left <= 0:
					lock()
			return

func lock() -> void:
	if state == State.GAME_OVER:
		return
	board.place_piece(current_cells, current_pos, current_type)
	Audio.play_lock()
	piece_locked.emit()

func start_lock() -> void:
	if state == State.FALLING:
		state = State.LOCKING
		lock_timer = 0.0
		lock_moves_left = 15

func update(delta: float) -> void:
	if Global.game_mode == Global.GameMode.ULTRA and state != State.GAME_OVER:
		Global.ultra_time_left -= delta
		if Global.ultra_time_left <= 0:
			Global.ultra_time_left = 0
			state = State.GAME_OVER
	match state:
		State.FALLING:
			drop_timer += delta
			var interval = Global.get_drop_interval()
			if soft_dropping:
				interval = interval * 0.1 if interval > 0.05 else 0.003
			if drop_timer >= interval:
				drop_timer = 0.0
				var new_pos = current_pos + Vector2i(0, 1)
				if not board.is_collision(current_cells, new_pos):
					current_pos = new_pos
					update_ghost()
				else:
					start_lock()
		
		State.LOCKING:
			if lock_timer >= Global.lock_delay:
				lock()
			else:
				if not board.is_collision(current_cells, current_pos + Vector2i(0, 1)):
					state = State.FALLING
					drop_timer = 0.0
				else:
					lock_timer += delta
		
		State.CLEARING:
			clear_timer += delta
			if clear_timer >= Global.LINE_CLEAR_DELAY:
				board.clear_rows(clearing_rows)
				_add_line_score(clearing_rows.size())
				clearing_rows.clear()
				state = State.FALLING
				spawn_piece()
		
		State.GAME_OVER:
			game_over_timer += delta
			if game_over_timer >= Global.GAME_OVER_DELAY:
				Audio.play_game_over()
				game_over.emit()

func _add_line_score(count: int) -> void:
	var base = Global.SCORE_TABLE.get(count, 0)
	Global.score += base * Global.level
	Global.lines += count
	var new_level = int(Global.lines / 10.0) + 1
	if new_level > Global.level:
		Global.level = new_level
	if Global.game_mode == Global.GameMode.SPRINT and Global.lines >= Global.sprint_target:
		state = State.GAME_OVER

func on_piece_locked() -> void:
	clearing_rows = board.get_full_rows()
	if clearing_rows.is_empty():
		combo_count = -1
		spawn_piece()
	else:
		combo_count += 1
		var is_tspin = _check_tspin()
		var big = clearing_rows.size() >= 4 or is_tspin
		var b2b = _last_was_big and big
		_last_was_big = big
		state = State.CLEARING
		clear_timer = 0.0
		clear_flash = 0.0
		Audio.play_clear(clearing_rows.size())
		lines_cleared.emit(clearing_rows.size(), is_tspin)
		if combo_count >= 1:
			combo.emit(combo_count + 1)
		if b2b:
			back_to_back.emit(is_tspin, clearing_rows.size())
		if board.is_all_clear():
			all_clear.emit()

func _check_tspin() -> bool:
	if current_type != PieceData.PIECE_T:
		return false
	if not _last_move_was_rotation:
		return false
	var corners = [Vector2i(0,0), Vector2i(2,0), Vector2i(0,2), Vector2i(2,2)]
	var filled = 0
	for c in corners:
		var cx = current_pos.x + c.x
		var cy = current_pos.y + c.y
		if cx >= 0 and cx < board.width and cy >= 0 and cy < board.height:
			if board.grid[cy][cx] != -1:
				filled += 1
	return filled >= 3

func save_state() -> void:
	var data = {
		"grid": board.grid,
		"current_type": current_type,
		"current_rotation": current_rotation,
		"current_x": current_pos.x,
		"current_y": current_pos.y,
		"next_queue": next_queue.duplicate(),
		"hold_type": hold_type,
		"hold_used": hold_used,
		"bag": bag.duplicate(),
		"score": Global.score,
		"lines": Global.lines,
		"level": Global.level,
		"game_mode": Global.game_mode,
		"ultra_time_left": Global.ultra_time_left,
		"soft_dropping": soft_dropping
	}
	data["elapsed_seconds"] = int((Time.get_ticks_msec() - start_time_msec) / 1000.0)
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_state() -> bool:
	var file = FileAccess.open("user://save.dat", FileAccess.READ)
	if not file:
		return false
	var data = file.get_var()
	file.close()
	if not data or not data.has("grid"):
		return false
	
	board.reset()
	for y in range(board.height):
		for x in range(board.width):
			if y < data.grid.size() and x < data.grid[y].size():
				board.grid[y][x] = data.grid[y][x]
	
	current_type = data.current_type
	current_rotation = data.current_rotation
	current_pos = Vector2i(data.current_x, data.current_y)
	current_cells = PieceData.get_cells(current_type, current_rotation)
	next_queue = data.next_queue.duplicate()
	hold_type = data.hold_type
	hold_used = data.hold_used
	bag = data.bag.duplicate()
	
	Global.score = data.score
	Global.lines = data.lines
	Global.level = data.level
	Global.game_mode = data.get("game_mode", 0)
	Global.ultra_time_left = data.get("ultra_time_left", 120.0)
	soft_dropping = data.get("soft_dropping", false)
	var elapsed = data.get("elapsed_seconds", 0)
	start_time_msec = Time.get_ticks_msec() - elapsed * 1000
	
	state = State.FALLING
	drop_timer = 0.0
	lock_timer = 0.0
	lock_moves_left = 15
	
	update_ghost()
	return true

static func delete_save() -> void:
	DirAccess.remove_absolute("user://save.dat")
