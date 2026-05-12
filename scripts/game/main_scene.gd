extends Node

var game: Game
var board_renderer: BoardRenderer
var hud: Control
var container: Control

var menu_layer: CanvasLayer
var active_menu: String = "main"
var previous_menu: String = ""
var input_enabled: bool = true

var _hud_dirty: bool = true
var _last_score: int = -1
var _last_level: int = -1
var _last_lines: int = -1
var _last_hold: int = -99
var _last_next: Array = [-99, -99, -99, -99, -99]
var _last_time_str: String = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game and active_menu == "game":
		game.save_state()
		Global.save_high_score()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	
	var root = ColorRect.new()
	root.color = Color(0.08, 0.08, 0.1)
	root.size = get_viewport().get_visible_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	get_viewport().size_changed.connect(_resize)
	create_main_menu()

func setup_inputs() -> void:
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"soft_drop": [KEY_S, KEY_DOWN],
		"hard_drop": [KEY_W, KEY_SPACE],
		"rotate_cw": [KEY_UP, KEY_X, KEY_J],
		"rotate_ccw": [KEY_Z, KEY_K],
		"hold": [KEY_SHIFT, KEY_C],
		"pause": [KEY_ESCAPE, KEY_P]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var ev = InputEventKey.new()
				ev.keycode = key
				InputMap.action_add_event(action, ev)

func _resize() -> void:
	var size = get_viewport().get_visible_rect().size
	for child in get_children():
		if child is ColorRect:
			child.size = size

func create_main_menu() -> void:
	BGM.stop_bgm()
	clear_scene()
	active_menu = "main"
	
	var menu = Control.new()
	add_child(menu)
	
	var title = Label.new()
	title.text = "Gotris"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title.position = Vector2(0, 80)
	title.size = Vector2(get_viewport().size.x, 80)
	menu.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "A Block Stacking Game"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.position = Vector2(0, 150)
	subtitle.size = Vector2(get_viewport().size.x, 40)
	menu.add_child(subtitle)
	
	var menu_btns = []
	var btn_start = make_button(tr("start_game"), func(): start_game(), Color(0.25, 0.3, 0.5))
	btn_start.position = Vector2(get_viewport().size.x / 2 - 120, 240)
	menu.add_child(btn_start)
	menu_btns.append(btn_start)
	
	var btn_settings = make_button(tr("settings"), func(): show_settings("main"), Color(0.2, 0.2, 0.25))
	btn_settings.position = Vector2(get_viewport().size.x / 2 - 120, 300)
	menu.add_child(btn_settings)
	menu_btns.append(btn_settings)
	
	var btn_quit = make_button(tr("quit"), func(): get_tree().quit(), Color(0.2, 0.2, 0.25))
	btn_quit.position = Vector2(get_viewport().size.x / 2 - 120, 360)
	menu.add_child(btn_quit)
	menu_btns.append(btn_quit)

	var has_save = FileAccess.file_exists("user://save.dat")
	if has_save:
		var btn_continue = make_button(tr("continue"), func():
			start_game_with_load()
		, Color(0.3, 0.35, 0.5))
		btn_continue.position = Vector2(get_viewport().size.x / 2 - 120, 420)
		menu.add_child(btn_continue)
		menu_btns.append(btn_continue)
	
	_chain_focus(menu_btns)
	btn_start.grab_focus()
	
	var version = Label.new()
	version.text = "v1.0"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	version.position = Vector2(get_viewport().size.x - 80, get_viewport().size.y - 30)
	version.size = Vector2(70, 20)
	menu.add_child(version)

func show_settings(from: String) -> void:
	previous_menu = from
	clear_scene()
	active_menu = "settings"
	
	var settings = Control.new()
	add_child(settings)
	
	var title = Label.new()
	title.text = tr("settings")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title.position = Vector2(0, 40)
	title.size = Vector2(get_viewport().size.x, 60)
	settings.add_child(title)
	
	var start_y = 100
	var items = [
		{ "label": tr("language"), "key": "lang", "type": "lang" },
		{ "label": tr("das"), "key": "das", "type": "slider", "min": 0.033, "max": 0.5, "step": 0.001 },
		{ "label": tr("arr"), "key": "arr", "type": "slider", "min": 0.0, "max": 0.2, "step": 0.001 },
		{ "label": tr("lock_delay"), "key": "lock_delay", "type": "slider", "min": 0.1, "max": 1.0, "step": 0.01 },
		{ "label": tr("volume"), "key": "volume", "type": "slider", "min": 0.0, "max": 1.0, "step": 0.05 }
	]
	
	for i in range(items.size()):
		var item = items[i]
		var y = start_y + i * 60
		
		var lbl = Label.new()
		lbl.text = item.label
		lbl.position = Vector2(120, y)
		lbl.size = Vector2(200, 30)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		settings.add_child(lbl)
		
		if item.type == "lang":
			var lang_idx = Global.get_language_idx()
			var lang_btn = make_button(
				"English" if lang_idx == 0 else "中文",
				func():
					var idx = 1 - Global.get_language_idx()
					TranslationServer.set_locale("en" if idx == 0 else "zh")
					Global.save_settings(idx)
					show_settings(previous_menu),
				Color(0.25, 0.25, 0.3)
			)
			lang_btn.position = Vector2(380, y)
			lang_btn.custom_minimum_size = Vector2(200, 36)
			lang_btn.size = Vector2(200, 36)
			settings.add_child(lang_btn)
		else:
			var slider = HSlider.new()
			slider.position = Vector2(380, y + 5)
			slider.size = Vector2(200, 30)
			slider.min_value = item.min
			slider.max_value = item.max
			slider.step = item.step
			
			var val_label = Label.new()
			val_label.position = Vector2(600, y)
			val_label.size = Vector2(80, 30)
			val_label.add_theme_font_size_override("font_size", 18)
			val_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
			
			match item.key:
				"das": slider.value = Global.das
				"arr": slider.value = Global.arr
				"lock_delay": slider.value = Global.lock_delay
				"volume": slider.value = Global.volume
			
			var update_func = func(val: float):
				match item.key:
					"das": Global.das = val
					"arr": Global.arr = val
					"lock_delay": Global.lock_delay = val
					"volume": Global.volume = val
				val_label.text = String("%.3f" % val).trim_suffix("0").trim_suffix(".")
				Global.save_settings(Global.get_language_idx())
			
			update_func.call(slider.value)
			slider.value_changed.connect(update_func)
			settings.add_child(slider)
			settings.add_child(val_label)
	
	var back_y = start_y + items.size() * 60 + 30
	var back = make_button(tr("back"), func():
		if previous_menu == "game":
			start_game()
		else:
			create_main_menu()
	, Color(0.2, 0.2, 0.25))
	back.position = Vector2(get_viewport().size.x / 2 - 120, back_y)
	settings.add_child(back)
	
	var focus_list = []
	for c in settings.get_children():
		if c is Control and c.focus_mode != Control.FOCUS_NONE:
			focus_list.append(c)
	if focus_list.size() > 1:
		_chain_focus(focus_list)
		focus_list[0].grab_focus()

func start_game_with_load() -> void:
	start_game()
	if game and game.load_state():
		game.state = 0
		game.soft_dropping = false
	else:
		game.start()

func start_game() -> void:
	clear_scene()
	active_menu = "game"
	input_enabled = true
	_hud_dirty = true
	_last_score = -1
	_last_level = -1
	_last_lines = -1
	_last_hold = -99
	_last_next = [-99, -99, -99, -99, -99]
	_last_time_str = ""
	
	var size = get_viewport().get_visible_rect().size
	container = Control.new()
	container.size = size
	add_child(container)
	
	var game_width = Global.BOARD_WIDTH * Global.CELL_SIZE
	var game_height = Global.BOARD_HEIGHT * Global.CELL_SIZE
	var cx = int((size.x - game_width) / 2)
	var cy = int((size.y - game_height) / 2)
	
	board_renderer = BoardRenderer.new()
	board_renderer.position = Vector2(cx, cy)
	var render_size = Vector2(game_width + Global.CELL_SIZE * 2, game_height + Global.CELL_SIZE * 2)
	board_renderer.custom_minimum_size = render_size
	board_renderer.size = render_size
	container.add_child(board_renderer)
	
	game = Game.new()
	board_renderer.set_game(game)
	game.piece_locked.connect(game.on_piece_locked)
	game.game_over.connect(_on_game_over)
	game.hard_dropped.connect(_on_hard_drop)
	game.lines_cleared.connect(_on_lines_cleared)
	game.combo.connect(_on_combo)
	game.all_clear.connect(_on_all_clear)
	game.back_to_back.connect(_on_back_to_back)
	
	create_hud(size)
	game.start()
	BGM.start_bgm()

func create_hud(size: Vector2) -> void:
	hud = Control.new()
	hud.size = size
	container.add_child(hud)
	
	var info_x = 20
	var preview_x = int(size.x) - 160
	
	var hold_title = Label.new()
	hold_title.text = tr("hold")
	hold_title.position = Vector2(info_x, 30)
	hold_title.size = Vector2(120, 24)
	hold_title.add_theme_font_size_override("font_size", 18)
	hold_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hud.add_child(hold_title)
	
	var hold_box = ColorRect.new()
	hold_box.color = Color(0.1, 0.1, 0.12)
	hold_box.position = Vector2(info_x, 55)
	hold_box.size = Vector2(120, 100)
	hold_box.name = "hold_box"
	hud.add_child(hold_box)
	
	var stats = [
		{ "name": "score", "label": tr("score"), "y": 180 },
		{ "name": "level", "label": tr("level"), "y": 250 },
		{ "name": "lines", "label": tr("lines"), "y": 320 },
		{ "name": "time", "label": "Time", "y": 390 }
	]
	
	for s in stats:
		var lbl = Label.new()
		lbl.text = s.label
		lbl.position = Vector2(info_x, s.y)
		lbl.size = Vector2(120, 20)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hud.add_child(lbl)
		
		var val = Label.new()
		val.text = "0"
		val.position = Vector2(info_x, s.y + 22)
		val.size = Vector2(120, 28)
		val.add_theme_font_size_override("font_size", 26)
		val.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		val.name = "val_" + s.name
		hud.add_child(val)
	
	var next_title = Label.new()
	next_title.text = tr("next")
	next_title.position = Vector2(preview_x, 30)
	next_title.size = Vector2(140, 24)
	next_title.add_theme_font_size_override("font_size", 18)
	next_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hud.add_child(next_title)
	
	for i in range(Global.PREVIEW_COUNT):
		var box = ColorRect.new()
		box.color = Color(0.1, 0.1, 0.12)
		box.position = Vector2(preview_x, 55 + i * 80)
		box.size = Vector2(140, 70)
		box.name = "next_" + str(i)
		hud.add_child(box)

func draw_preview_in(container_node: ColorRect, piece_type: int) -> void:
	for child in container_node.get_children():
		child.queue_free()
	
	if piece_type < 0:
		return
	
	var color = PieceData.get_color(piece_type)
	var shape = PieceData.get_shape(piece_type, 0)
	var s = 16
	var ox = int((container_node.size.x - 4 * s) / 2)
	var oy = int((container_node.size.y - 4 * s) / 2)
	
	for i in 16:
		if shape[i] == 1:
			var cell = ColorRect.new()
			cell.color = color
			cell.size = Vector2(s - 2, s - 2)
			cell.position = Vector2(
				(i % 4) * s + ox + 1,
				(i >> 2) * s + oy + 1
			)
			container_node.add_child(cell)

func update_hud_display() -> void:
	if not game or not is_instance_valid(hud):
		return
	
	var time_str = ""
	var elapsed = int((Time.get_ticks_msec() - game.start_time_msec) / 1000.0)
	var m = int(elapsed / 60.0)
	var s = elapsed % 60
	time_str = "%02d:%02d" % [m, s]
	
	var dirty = time_str != _last_time_str
	_last_time_str = time_str
	
	if Global.score != _last_score:
		_last_score = Global.score
		dirty = true
	if Global.level != _last_level:
		_last_level = Global.level
		dirty = true
	if Global.lines != _last_lines:
		_last_lines = Global.lines
		dirty = true
	if game.hold_type != _last_hold:
		_last_hold = game.hold_type
		dirty = true
	
	for i in range(Global.PREVIEW_COUNT):
		var n = game.get_next_piece(i)
		if n != _last_next[i]:
			_last_next[i] = n
			dirty = true
	
	if not dirty:
		return
	
	for child in hud.get_children():
		if child.name == "val_score":
			child.text = str(Global.score)
		elif child.name == "val_level":
			if Global.game_mode == Global.GameMode.ULTRA:
				child.text = str(int(Global.ultra_time_left))
			else:
				child.text = str(Global.level)
		elif child.name == "val_lines":
			child.text = str(Global.lines)
		elif child.name == "val_time":
			child.text = time_str
	
	var hold_box = hud.get_node("hold_box")
	if hold_box:
		draw_preview_in(hold_box, game.hold_type)
	
	for i in range(Global.PREVIEW_COUNT):
		var box = hud.get_node("next_" + str(i))
		if box:
			draw_preview_in(box, game.get_next_piece(i))

func _process(delta: float) -> void:
	if active_menu == "game" and game and input_enabled:
		game.update(delta)
		if game.state == 0 or game.state == 1:
			handle_input(delta)
		update_hud_display()

func handle_input(delta: float) -> void:
	if not input_enabled:
		return
	
	if Input.is_action_just_pressed("pause"):
		create_pause_menu()
		return
	
	if Input.is_action_just_pressed("hold"):
		game.hold()
	
	if Input.is_action_just_pressed("rotate_cw"):
		game.rotate(1)
	if Input.is_action_just_pressed("rotate_ccw"):
		game.rotate(-1)
	
	if Input.is_action_just_pressed("hard_drop"):
		game.hard_drop()
	
	game.soft_dropping = Input.is_action_pressed("soft_drop")
	
	var left = Input.is_action_pressed("move_left")
	var right = Input.is_action_pressed("move_right")
	
	if left and not right:
		if game.das_dir != -1:
			game.das_dir = -1
			game.das_timer = 0.0
			game.arr_timer = 0.0
			game.das_charged = false
			game.move_left()
		else:
			game.das_timer += delta
			if not game.das_charged and game.das_timer >= Global.das:
				game.das_charged = true
				game.arr_timer = 0.0
			if game.das_charged:
				game.arr_timer += delta
				if Global.arr <= 0.001:
					while game.arr_timer >= Global.das * 0.5:
						game.arr_timer -= Global.das * 0.5
						game.move_left()
				else:
					while game.arr_timer >= Global.arr:
						game.arr_timer -= Global.arr
						game.move_left()
	elif right and not left:
		if game.das_dir != 1:
			game.das_dir = 1
			game.das_timer = 0.0
			game.arr_timer = 0.0
			game.das_charged = false
			game.move_right()
		else:
			game.das_timer += delta
			if not game.das_charged and game.das_timer >= Global.das:
				game.das_charged = true
				game.arr_timer = 0.0
			if game.das_charged:
				game.arr_timer += delta
				if Global.arr <= 0.001:
					while game.arr_timer >= Global.das * 0.5:
						game.arr_timer -= Global.das * 0.5
						game.move_right()
				else:
					while game.arr_timer >= Global.arr:
						game.arr_timer -= Global.arr
						game.move_right()
	else:
		game.das_dir = 0
		game.das_timer = 0.0
		game.arr_timer = 0.0
		game.das_charged = false

func create_pause_menu() -> void:
	input_enabled = false
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = get_viewport().get_visible_rect().size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)
	
	var pause = Control.new()
	pause.position = Vector2(get_viewport().size.x / 2 - 120, 150)
	pause.size = Vector2(240, 250)
	menu_layer.add_child(pause)
	
	var title = Label.new()
	title.text = tr("pause")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(240, 40)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	pause.add_child(title)
	
	var pause_btns = []
	var resume_btn = make_button(tr("resume"), func():
		input_enabled = true
		remove_child(menu_layer); menu_layer.queue_free()
	, Color(0.2, 0.2, 0.25))
	resume_btn.position = Vector2(0, 60)
	pause.add_child(resume_btn)
	pause_btns.append(resume_btn)
	
	var restart_btn = make_button(tr("restart"), func():
		Game.delete_save()
		remove_child(menu_layer); menu_layer.queue_free()
		start_game()
	, Color(0.2, 0.2, 0.25))
	restart_btn.position = Vector2(0, 115)
	pause.add_child(restart_btn)
	pause_btns.append(restart_btn)
	
	var settings_btn = make_button(tr("settings"), func():
		remove_child(menu_layer); menu_layer.queue_free()
		show_settings("game")
	, Color(0.2, 0.2, 0.25))
	settings_btn.position = Vector2(0, 170)
	pause.add_child(settings_btn)
	pause_btns.append(settings_btn)
	
	var quit_btn = make_button(tr("main_menu"), func():
		if game:
			game.save_state()
		Global.save_high_score()
		remove_child(menu_layer); menu_layer.queue_free()
		create_main_menu()
	, Color(0.2, 0.2, 0.25))
	quit_btn.position = Vector2(0, 225)
	pause.add_child(quit_btn)
	pause_btns.append(quit_btn)
	
	_chain_focus(pause_btns)
	resume_btn.grab_focus()

func _chain_focus(buttons: Array) -> void:
	for i in range(buttons.size()):
		var b = buttons[i]
		if i > 0:
			b.focus_neighbor_top = buttons[i-1].get_path()
			b.focus_previous = buttons[i-1].get_path()
		if i < buttons.size() - 1:
			b.focus_neighbor_bottom = buttons[i+1].get_path()
			b.focus_next = buttons[i+1].get_path()

func make_button(text: String, callback: Callable, color: Color = Color(0.2, 0.2, 0.25)) -> Control:
	var btn = Control.new()
	btn.custom_minimum_size = Vector2(240, 48)
	btn.size = Vector2(240, 48)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_ALL

	var bg = ColorRect.new()
	bg.color = color
	bg.size = Vector2(240, 48)
	bg.name = "bg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(240, 48)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	btn.add_child(lbl)

	btn.mouse_entered.connect(func(): bg.color = Color(0.35, 0.35, 0.4))
	btn.mouse_exited.connect(func(): bg.color = color)
	btn.focus_entered.connect(func(): bg.color = Color(0.4, 0.4, 0.5))
	btn.focus_exited.connect(func(): bg.color = color)

	var activate = func():
		callback.call()
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			activate.call()
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE:
				activate.call()
				get_viewport().set_input_as_handled()
			elif ev.keycode == KEY_UP:
				var target_path = btn.focus_neighbor_top
				if target_path:
					var target = btn.get_node(target_path)
					if target and target is Control:
						target.grab_focus()
						get_viewport().set_input_as_handled()
			elif ev.keycode == KEY_DOWN:
				var target_path = btn.focus_neighbor_bottom
				if target_path:
					var target = btn.get_node(target_path)
					if target and target is Control:
						target.grab_focus()
						get_viewport().set_input_as_handled()
	)

	return btn

func _on_game_over() -> void:
	Global.save_high_score()
	Game.delete_save()
	BGM.stop_bgm()
	input_enabled = false
	
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = get_viewport().get_visible_rect().size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(dim)
	
	var go = Control.new()
	go.position = Vector2(get_viewport().size.x / 2 - 140, 120)
	go.size = Vector2(280, 320)
	menu_layer.add_child(go)
	
	var title_text = tr("game_over")
	var title_color = Color(0.9, 0.3, 0.3)
	if Global.game_mode == Global.GameMode.SPRINT and Global.lines >= Global.sprint_target:
		title_text = "Sprint Complete!"
		title_color = Color(0.3, 0.9, 0.3)
	elif Global.game_mode == Global.GameMode.ULTRA:
		title_text = "Time Up!"
	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(280, 50)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", title_color)
	go.add_child(title)
	
	var score_label = Label.new()
	score_label.text = tr("score") + ": " + str(Global.score)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.size = Vector2(280, 30)
	score_label.position = Vector2(0, 80)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	go.add_child(score_label)
	
	if Global.score >= Global.high_scores.get(Global.game_mode, 0) and Global.score > 0:
		var hs = Label.new()
		hs.text = tr("new_high_score")
		hs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs.size = Vector2(280, 30)
		hs.position = Vector2(0, 115)
		hs.add_theme_font_size_override("font_size", 20)
		hs.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		go.add_child(hs)
	
	var go_btns = []
	var restart_btn = make_button(tr("restart"), func():
		remove_child(menu_layer); menu_layer.queue_free()
		start_game()
	, Color(0.25, 0.3, 0.5))
	restart_btn.position = Vector2(20, 170)
	go.add_child(restart_btn)
	go_btns.append(restart_btn)
	
	var menu_btn = make_button(tr("main_menu"), func():
		remove_child(menu_layer); menu_layer.queue_free()
		create_main_menu()
	, Color(0.2, 0.2, 0.25))
	menu_btn.position = Vector2(20, 230)
	go.add_child(menu_btn)
	go_btns.append(menu_btn)
	
	_chain_focus(go_btns)
	restart_btn.grab_focus()

func _on_lines_cleared(count: int, is_tspin: bool) -> void:
	if not board_renderer:
		return
	var texts = ["", "Single", "Double", "Triple", "Quad"]
	var label_text = texts[count] if count < texts.size() else str(count) + " Lines"
	if is_tspin:
		label_text = "T-Spin " + label_text
	_show_clear_text(label_text)

func _show_clear_text(text: String) -> void:
	var br = board_renderer
	_show_floating_text(text, br.position + Vector2(br.size.x / 2 - 60, br.size.y / 2 - 40), Color(1, 1, 1), 24)

func _show_floating_text(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	label.size = Vector2(200, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(label, "modulate", Color(color.r, color.g, color.b, 0), 1.0)
	tween.tween_callback(label.queue_free)

func _on_combo(c: int) -> void:
	if not board_renderer:
		return
	var br = board_renderer
	var pos = br.position + Vector2(br.size.x / 2 - 60, br.size.y / 2)
	_show_floating_text(str(c) + " Combo", pos, Color(1, 0.8, 0), 22)

func _on_all_clear() -> void:
	if not board_renderer:
		return
	var br = board_renderer
	var pos = br.position + Vector2(br.size.x / 2 - 60, br.size.y / 2 + 30)
	_show_floating_text("All Clear", pos, Color(0.3, 1, 0.6), 26)

func _on_back_to_back(_is_tspin: bool, _count: int) -> void:
	if not board_renderer:
		return
	var br = board_renderer
	var pos = br.position + Vector2(br.size.x / 2 - 60, br.size.y / 2 + 60)
	_show_floating_text("Back to Back", pos, Color(1, 0.5, 0), 22)

func _on_hard_drop(from_y: int, to_y: int) -> void:
	if board_renderer and game:
		board_renderer.trigger_hard_drop_trail(from_y, to_y, game.current_cells, game.current_pos)

func clear_scene() -> void:
	game = null
	board_renderer = null
	hud = null
	container = null
	var children = get_children().duplicate()
	for child in children:
		if child is CanvasLayer:
			child.queue_free()
		elif child is ColorRect:
			continue
		else:
			child.queue_free()
