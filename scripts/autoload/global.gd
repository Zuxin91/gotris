extends Node

enum GameMode { MARATHON, SPRINT, ULTRA }

var game_mode: int = GameMode.MARATHON
var score: int = 0
var lines: int = 0
var level: int = 1
var ultra_time_left: float = 120.0
var sprint_target: int = 40
var high_scores: Dictionary = {
	GameMode.MARATHON: 0,
	GameMode.SPRINT: 0,
	GameMode.ULTRA: 0
}

var das: float = 0.167
var arr: float = 0.033
var sdf: float = 0.0
var lock_delay: float = 0.5
var volume: float = 0.7

const BOARD_WIDTH: int = 10
const BOARD_HEIGHT: int = 20
const CELL_SIZE: int = 28
const PREVIEW_COUNT: int = 5

const LINE_CLEAR_DELAY: float = 0.4
const LOCK_FLASH_DELAY: float = 0.5
const GAME_OVER_DELAY: float = 2.0

const SCORE_TABLE: Dictionary = {
	1: 100, 2: 300, 3: 500, 4: 800
}

const SPEED_TABLE: Dictionary = {
	1: 1.0, 2: 0.75, 3: 0.55, 4: 0.40, 5: 0.30,
	6: 0.22, 7: 0.16, 8: 0.12, 9: 0.09, 10: 0.07,
	11: 0.05, 12: 0.04, 13: 0.03, 14: 0.02, 15: 0.015,
	16: 0.012, 17: 0.010, 18: 0.008, 19: 0.006, 20: 0.005
}

func _ready() -> void:
	load_translations()
	load_settings()
	load_high_scores()
	var loc = TranslationServer.get_locale()
	if not loc.begins_with("zh"):
		TranslationServer.set_locale("en")

func load_translations() -> void:
	var dir = DirAccess.open("res://locales")
	if not dir:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var locale = file.replace(".json", "")
		var json_str = FileAccess.get_file_as_string("res://locales/" + file)
		var json = JSON.new()
		if json.parse(json_str) != OK:
			continue
		var data = json.data as Dictionary
		if not data:
			continue
		var trans = Translation.new()
		trans.locale = locale
		for key in data:
			trans.add_message(key, data[key])
		TranslationServer.add_translation(trans)

func get_drop_interval() -> float:
	var lvl = mini(level, 20)
	return SPEED_TABLE.get(lvl, 0.008)

func save_high_score() -> void:
	if score > high_scores.get(game_mode, 0):
		high_scores[game_mode] = score
		save_high_scores_to_file()

func load_high_scores() -> void:
	var file = FileAccess.open("user://highscores.dat", FileAccess.READ)
	if file:
		for mode in GameMode.values():
			var val = file.get_64()
			if val > 0:
				high_scores[mode] = val
		file.close()

func save_high_scores_to_file() -> void:
	var file = FileAccess.open("user://highscores.dat", FileAccess.WRITE)
	if file:
		for mode in GameMode.values():
			file.store_64(high_scores.get(mode, 0))
		file.close()

func load_settings() -> void:
	var file = FileAccess.open("user://settings.dat", FileAccess.READ)
	if file:
		das = file.get_float()
		arr = file.get_float()
		sdf = file.get_float()
		lock_delay = file.get_float()
		volume = file.get_float()
		var lang = file.get_32()
		TranslationServer.set_locale("en" if lang == 0 else "zh")
		file.close()

func save_settings(lang_idx: int) -> void:
	var file = FileAccess.open("user://settings.dat", FileAccess.WRITE)
	if file:
		file.store_float(das)
		file.store_float(arr)
		file.store_float(sdf)
		file.store_float(lock_delay)
		file.store_float(volume)
		file.store_32(lang_idx)
		file.close()

func get_language_idx() -> int:
	var loc = TranslationServer.get_locale()
	return 0 if loc.begins_with("en") else 1
