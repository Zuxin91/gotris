class_name BGMPlayer extends AudioStreamPlayer

var _note_timer: float = 0.0
var _note_index: int = 0
var _note_duration: float = 0.18
var _notes: Array = []
var _playing_bgm: bool = false

func _ready() -> void:
	bus = "Master"
	_setup_korobeiniki()

func _setup_korobeiniki() -> void:
	var A4 = 440.0
	var notes = {
		"B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63,
		"F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
		"C5": 523.25, "D5": 587.33, "Eb5": 622.25, "E5": 659.25,
		"F5": 698.46, "G5": 783.99, "A5": 880.00, "B5": 987.77,
		"C6": 1046.50, "R": 0.0
	}
	var melody = [
		"E5","E5","R","G5","E5","R","E5","Eb5","E5","B4","R","D5","C5","A4","R","C5","B4","R",
		"E5","E5","R","G5","E5","R","E5","Eb5","E5","B4","R","D5","C5","A4","R","C5","B4","R",
		"B4","C5","D5","E5","G5","F5","E5","D5","R","F5","A5","G5","F5","E5","D5","C5","R",
		"E5","E5","R","G5","E5","R","E5","Eb5","E5","B4","R","D5","C5","A4","R","C5","B4","R",
	]
	_notes = []
	for n in melody:
		_notes.append(notes.get(n, 0.0))

func start_bgm() -> void:
	_note_index = 0
	_note_timer = 0.0
	_playing_bgm = true

func stop_bgm() -> void:
	_playing_bgm = false
	stop()

func _process(delta: float) -> void:
	if not _playing_bgm:
		return
	_note_timer += delta
	if _note_timer >= _note_duration:
		_note_timer = 0.0
		var freq = _notes[_note_index]
		_note_index = (_note_index + 1) % _notes.size()
		if freq > 0:
			_play_note(freq)

func _play_note(freq: float) -> void:
	var sample_rate = 22050
	var duration = _note_duration
	var n_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(n_samples * 2)
	var vol = 0.08 * Global.volume
	for i in range(n_samples):
		var t = float(i) / sample_rate
		var envelope = 1.0
		var attack_end = int(n_samples * 0.02)
		if i < attack_end:
			envelope = float(i) / attack_end
		var decay_start = int(n_samples * 0.7)
		if i > decay_start:
			envelope = 1.0 - float(i - decay_start) / (n_samples - decay_start)
		var sample = 0.0
		for h in range(1, 4):
			var amp = 1.0 / h
			sample += sin(2.0 * PI * freq * h * t) * amp * 0.5
		sample *= envelope * vol
		var s16 = int(clampf(sample * 32767, -32768, 32767))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	stream = wav
	play()
