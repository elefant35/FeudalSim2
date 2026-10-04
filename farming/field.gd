class_name Field
extends Node3D
## The fenced field: its plots, the scarecrows, and the crows that come for fresh seed.
## Runs each plot's daily update at midnight.

const COLS := 4
const ROWS := 3
const PITCH := 3.0
const SCARECROW_RADIUS := 8.0
const CROW_CHECK_MINUTES := 60.0
const CROW_CHANCE := 0.12
const MAX_CROWS := 2

var plots: Array[FarmPlot] = []
var scarecrows: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var _scarecrow_nodes: Array[Node3D] = []
var _crow_timer := 0.0


func _ready() -> void:
	add_to_group("saveable")
	add_to_group("field")
	rng.randomize()
	for r in ROWS:
		for c in COLS:
			var p := FarmPlot.new()
			p.index = plots.size()
			p.field = self
			p.name = "Plot%d" % p.index
			p.position = Vector3((c - (COLS - 1) / 2.0) * PITCH, 0.0, (r - (ROWS - 1) / 2.0) * PITCH)
			add_child(p)
			plots.append(p)
	Clock.day_started.connect(_on_day_started)
	Clock.minutes_passed.connect(_on_minutes)


## Are there reaped stalks lying anywhere, waiting to be bound?
func any_cut() -> bool:
	for p in plots:
		if p.state.count_plants(PlotState.Plant.CUT) > 0:
			return true
	return false


func half_extents() -> Vector2:
	return Vector2(COLS * PITCH / 2.0, ROWS * PITCH / 2.0)


func _on_day_started(_day: int) -> void:
	var news: Array[String] = []
	for p in plots:
		var e := p.daily_update(Clock.season(), Clock.raining, rng)
		if e != "" and not (e in news):
			news.append(e)
	var player: Player = get_tree().get_first_node_in_group("player")
	for e in news:
		player.say(e)


# --- Crows ----------------------------------------------------------------------------------

func _on_minutes(minutes: float) -> void:
	_crow_timer += minutes
	if _crow_timer < CROW_CHECK_MINUTES:
		return
	_crow_timer = 0.0
	var h := Clock.hour()
	if h < 6.0 or h > 19.0 or Clock.raining:
		return
	var crows := 0
	for c in get_children():
		if c is Crow:
			crows += 1
	for p in plots:
		if crows >= MAX_CROWS:
			return
		if p.state.is_sown_not_sprouted() and not _protected(p) and not _has_crow(p) and rng.randf() < CROW_CHANCE:
			crows += 1
			var crow := Crow.new()
			crow.plot = p
			add_child(crow)


func _has_crow(p: FarmPlot) -> bool:
	for c in get_children():
		if c is Crow and c.plot == p:
			return true
	return false


func _protected(p: FarmPlot) -> bool:
	for s in scarecrows:
		if s.distance_to(p.global_position) < SCARECROW_RADIUS:
			return true
	return false


# --- Scarecrows -----------------------------------------------------------------------------

## Can a scarecrow stand at this world point? Beside the plots, inside or near the fence.
func scarecrow_error(point: Vector3) -> String:
	var l := to_local(point)
	var he := half_extents()
	if absf(l.x) > he.x + 4.0 or absf(l.z) > he.y + 4.0:
		return "Put it in or beside the field."
	for p in plots:
		var pl := p.to_local(point)
		if absf(pl.x) < FarmPlot.SIZE / 2 + 0.2 and absf(pl.z) < FarmPlot.SIZE / 2 + 0.2:
			return "Not on a plot; put it in a path between them."
	return ""


func place_scarecrow(point: Vector3) -> void:
	scarecrows.append(point)
	_spawn_scarecrow(point)
	for c in get_children():
		if c is Crow and _protected(c.plot):
			c.flee()


func _spawn_scarecrow(point: Vector3) -> void:
	var s := Models.make(&"scarecrow")
	add_child(s)
	s.global_position = point
	s.rotation.y = rng.randf() * TAU
	_scarecrow_nodes.append(s)


func to_dict() -> Dictionary:
	var sc: Array = []
	for s in scarecrows:
		sc.append([s.x, s.y, s.z])
	var ps: Array = []
	for p in plots:
		ps.append(p.to_dict())
	return {"plots": ps, "scarecrows": sc}


func from_dict(d: Dictionary) -> void:
	for i in mini(plots.size(), d.plots.size()):
		plots[i].from_dict(d.plots[i])
	for n in _scarecrow_nodes:
		n.queue_free()
	_scarecrow_nodes.clear()
	scarecrows.clear()
	for s: Array in d.get("scarecrows", []):
		var v := Vector3(s[0], s[1], s[2])
		scarecrows.append(v)
		_spawn_scarecrow(v)
