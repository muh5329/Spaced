class_name AudioDirector
extends Node
## Bounded voice pool: sustained firing never allocates an unbounded audio graph.
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index: int = 0
var music_volume: float = 0.65
var effects_volume: float = 0.8

func _ready() -> void:
	for sound in ["rail", "hostile", "impact", "explosion", "collect", "scan", "ui", "dock"]:
		sounds[sound] = load("res://assets/audio/" + sound + ".wav")
	for i in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	var track := load("res://assets/audio/adrift.wav") as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = int(track.get_length() * track.mix_rate)
	music.stream = track
	add_child(music)
	apply_volume()
	music.play()

func play(sound: String, strength: float = 1.0) -> void:
	if not sounds.has(sound) or effects_volume <= 0:
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = sounds[sound]
	voice.volume_db = linear_to_db(effects_volume * strength * 0.65)
	voice.play()

func apply_volume() -> void:
	if music:
		music.volume_db = linear_to_db(maxf(0.0001, music_volume * 0.65))

func shutdown() -> void:
	if music:
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()

func _exit_tree() -> void:
	shutdown()
