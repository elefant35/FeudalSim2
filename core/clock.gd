extends Node
## World clock: time of day, days, seasons, weather, and the 1x/2x/4x speed control.
## Autoloaded as `Clock`. One day lasts REAL_SECONDS_PER_DAY at 1x.

signal minutes_passed(minutes: float)   ## Awake time passing (not emitted while sleeping).
signal day_started(day: int)            ## Emitted at midnight for each new day.
signal speed_changed(speed: int)

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


func _ready() -> void:
	rng.randomize()
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
	var skipped := target - total_minutes
	advance(skipped, false)
	return skipped / 60.0


func _start_day(d: int) -> void:
	raining = rng.randf() < RAIN_CHANCE[season_of(d)]
	day_started.emit(d)


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
	return {"total_minutes": total_minutes, "raining": raining, "speed_index": speed_index}


func from_dict(d: Dictionary) -> void:
	total_minutes = float(d.get("total_minutes", START_HOUR * 60.0))
	raining = bool(d.get("raining", false))
	speed_index = int(d.get("speed_index", 0))
	speed_changed.emit(speed())


func reset() -> void:
	total_minutes = START_HOUR * 60.0
	raining = false
	speed_index = 0
	speed_changed.emit(speed())
