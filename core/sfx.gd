extends Node
## Sound effects by name. Autoloaded as `Sfx`. Each name maps to one or more files in
## res://assets/sounds; a random variant plays each time.

const DIR := "res://assets/sounds"
const LOOPING: Array[String] = ["pour", "rain_loop", "ambience_day"]

var _banks: Dictionary = {}   # name -> Array[AudioStream]


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file in DirAccess.get_files_at(DIR):
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var stream: AudioStream = load(DIR.path_join(file))
		if stream == null:
			continue
		# "hoe_strike_2.ogg" -> bank "hoe_strike"
		var bank := file.get_basename()
		var tail := bank.get_slice("_", bank.get_slice_count("_") - 1)
		if tail.is_valid_int():
			bank = bank.trim_suffix("_" + tail)
		if not _banks.has(bank):
			_banks[bank] = []
		if bank in LOOPING and "loop" in stream:
			stream.set("loop", true)
		if not (stream in _banks[bank]):
			_banks[bank].append(stream)


func stream(bank: String) -> AudioStream:
	var list: Array = _banks.get(bank, [])
	return null if list.is_empty() else list.pick_random()


## Non-positional (UI, the player's own hands).
func play(bank: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var s := stream(bank)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Positional, in the world.
func play_at(bank: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var s := stream(bank)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
