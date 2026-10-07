extends Node
## World clock: time of day, days, seasons, weather (rain, wind), and the 1x/2x/4x speed control.
## Autoloaded as `Clock`. One day lasts REAL_SECONDS_PER_DAY at 1x.

signal minutes_passed(minutes: float)   ## Awake time passing (not emitted while sleeping).
signal day_started(day: int)            ## Emitted at midnight for each new day.
signal speed_changed(speed: int)
signal skipped(hours: float)            ## The clock jumped ahead (the player slept).

const REAL_SECONDS_PER_DAY := 900.0
const MINUTES_PER_DAY := 1440.0
const DAYS_PER_SEASON := 6
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const SPEEDS: Array[int] = [1, 2, 4]
const RAIN_CHANCE: Array[float] = [0.35, 0.15, 0.35, 0.2]
const START_HOUR := 6.0

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var total_minutes: float = START_HOUR * 60.0
var speed_index: int = 0
var paused: bool = false
var raining: bool = false
var rng := RandomNumberGenerator.new()
## The wind follows smooth noise through game time, so it's the same for everyone at a given
## moment and only its seed needs saving. Tests and dev runs can pin it with set_wind().
var wind_seed: int = 1
var _wind_noise := FastNoiseLite.new()
var _wind_fixed: Variant = null   # [bearing_from, strength] while pinned

const WIND_NAMES: Array[String] = ["calm", "light air", "light breeze", "fresh breeze", "strong breeze", "gale"]
const WIND_STEPS: Array[float] = [0.12, 0.25, 0.42, 0.62, 0.82]
const COMPASS: Array[String] = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
const PREVAILING := 4.3          ## Bearing the wind mostly comes from (radians; ~west-south-west).
const SEASON_WIND: Array[float] = [0.05, -0.08, 0.06, 0.1]


func _ready() -> void:
	rng.randomize()
	_set_wind_seed(rng.randi())
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if paused:
		return
	advance(delta * speed() * MINUTES_PER_DAY / REAL_SECONDS_PER_DAY)


## Moves the clock forward. Day rollovers fire `day_started` for each day crossed.
func advance(minutes: float, awake: bool = true) -> void:
	var old_day := day()
	total_minutes += minutes
	if awake:
		minutes_passed.emit(minutes)
	for d in range(old_day + 1, day() + 1):
		_start_day(d)


## Advances to the next occurrence of `hour` (used by sleeping and collapsing).
func skip_to_hour(hour: float) -> float:
	var target := day() * MINUTES_PER_DAY + hour * 60.0
	if target <= total_minutes:
		target += MINUTES_PER_DAY
	var gap := target - total_minutes
	advance(gap, false)
	skipped.emit(gap / 60.0)
	return gap / 60.0


func _start_day(d: int) -> void:
	raining = rng.randf() < RAIN_CHANCE[season_of(d)]
	day_started.emit(d)


# --- Wind --------------------------------------------------------------------------------------

func _set_wind_seed(s: int) -> void:
	wind_seed = s
	_wind_noise.seed = s
	_wind_noise.frequency = 1.0


## Where the wind blows from, as a compass bearing in radians (0 = north, PI/2 = east).
func wind_from() -> float:
	if _wind_fixed != null:
		return _wind_fixed[0]
	var t := total_minutes
	return fposmod(PREVAILING + _wind_noise.get_noise_1d(t / 700.0) * 2.4 + _wind_noise.get_noise_1d(t / 97.0 + 300.0) * 0.35, TAU)


## How hard it's blowing, 0 (dead calm) to 1 (a gale). Changes over hours; days differ.
func wind_strength() -> float:
	if _wind_fixed != null:
		return _wind_fixed[1]
	var t := total_minutes
	var days := _wind_noise.get_noise_1d(t / 1100.0 + 900.0) * 0.55
	var hours := _wind_noise.get_noise_1d(t / 110.0 + 1700.0) * 0.22
	return clampf(0.42 + days + hours + SEASON_WIND[season()], 0.0, 1.0)


## The direction the wind blows towards (world, horizontal, unit length).
func wind_dir() -> Vector3:
	var b := wind_from()
	return -Vector3(sin(b), 0.0, -cos(b))


## Pins the wind (tests, dev runs). bearing_from in radians; pass a negative strength to unpin.
func set_wind(bearing_from: float, strength: float) -> void:
	_wind_fixed = null if strength < 0.0 else [fposmod(bearing_from, TAU), clampf(strength, 0.0, 1.0)]


static func wind_name(strength: float) -> String:
	var i := 0
	while i < WIND_STEPS.size() and strength >= WIND_STEPS[i]:
		i += 1
	return WIND_NAMES[i]


static func compass_name(bearing: float) -> String:
	return COMPASS[int(roundf(fposmod(bearing, TAU) / (TAU / 8.0))) % 8]


## "A fresh breeze from the west."
func wind_string() -> String:
	var s := wind_strength()
	if s < WIND_STEPS[0]:
		return "Dead calm"
	return "A %s from the %s" % [wind_name(s), compass_name(wind_from())]


func speed() -> int:
	return SPEEDS[speed_index]


func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	speed_changed.emit(speed())


func day() -> int:
	return int(total_minutes / MINUTES_PER_DAY)


func hour() -> float:
	return fmod(total_minutes, MINUTES_PER_DAY) / 60.0


func season() -> int:
	return season_of(day())


static func season_of(d: int) -> int:
	return (d / DAYS_PER_SEASON) % 4


func day_of_season() -> int:
	return day() % DAYS_PER_SEASON + 1


func year() -> int:
	return day() / (DAYS_PER_SEASON * 4) + 1


func is_night() -> bool:
	var h := hour()
	return h < 5.0 or h >= 20.5


func time_string() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


func date_string() -> String:
	return "%s, day %d (year %d)" % [SEASON_NAMES[season()], day_of_season(), year()]


func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes, "raining": raining, "speed_index": speed_index, "wind_seed": wind_seed}


func from_dict(d: Dictionary) -> void:
	total_minutes = float(d.get("total_minutes", START_HOUR * 60.0))
	raining = bool(d.get("raining", false))
	speed_index = int(d.get("speed_index", 0))
	_set_wind_seed(int(d.get("wind_seed", rng.randi())))
	speed_changed.emit(speed())


func reset() -> void:
	total_minutes = START_HOUR * 60.0
	raining = false
	speed_index = 0
	_set_wind_seed(rng.randi())
	_wind_fixed = null
	speed_changed.emit(speed())
