class_name AudioManager extends Node

var audio_bus: int
var _player: AudioStreamPlayer

func _ready() -> void:
	audio_bus = AudioServer.get_bus_index("Master")
	if audio_bus < 0:
		audio_bus = 0
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

func play_move() -> void:
	_play_tone(400, 0.04, 0.08)

func play_rotate() -> void:
	_play_tone(600, 0.06, 0.1)

func play_hard_drop() -> void:
	_play_tone(150, 0.12, 0.2)

func play_lock() -> void:
	_play_tone(300, 0.08, 0.12)

func play_clear(count: int) -> void:
	var freq = 500 + count * 100
	_play_tone(freq, 0.15, 0.25)

func play_game_over() -> void:
	_play_tone(200, 0.3, 0.4)

func play_hold() -> void:
	_play_tone(500, 0.05, 0.08)

func _play_tone(freq: float, duration: float, vol: float) -> void:
	var sample_rate = 22050
	var n_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(n_samples * 2)
	var volume = clampf(vol * Global.volume, 0.0, 1.0)
	for i in range(n_samples):
		var t = float(i) / sample_rate
		var envelope = 1.0 - (float(i) / n_samples)
		var sample = sin(2.0 * PI * freq * t) * envelope * volume * 0.3
		var s16 = int(clampf(sample * 32767, -32768, 32767))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	_player.stream = wav
	_player.play()
