class_name Field
extends Node3D
## All the farm's plots (a few start in the fenced garden; the player breaks new ground with
## the hoe wherever they like), the scarecrows, and the crows that come for fresh seed.
## Runs each plot's daily update at midnight.

const GARDEN_HALF := Vector2(6.0, 4.5)   ## The fenced garden around this node's origin.
const SNAP := 0.5
## A tidy 4x3 grid of bed positions in the garden; the first four are dug at the start.
const GARDEN_GRID: Array[Vector2] = [
	Vector2(-4.5, -3), Vector2(-1.5, -3), Vector2(-4.5, 0), Vector2(-1.5, 0),
	Vector2(1.5, -3), Vector2(4.5, -3), Vector2(1.5, 0), Vector2(4.5, 0),
	Vector2(-4.5, 3), Vector2(-1.5, 3), Vector2(1.5, 3), Vector2(4.5, 3)]
const STARTER_COUNT := 4
const SCARECROW_RADIUS := 8.0
const CROW_CHECK_MINUTES := 60.0
const CROW_CHANCE := 0.12
const MAX_CROWS := 2

## Where this field's beds start (local), and how many are dug from the outset.
var layout: Array[Vector2] = GARDEN_GRID
var starters: int = STARTER_COUNT
## The player's field posts its news (frost, blight...) to the player; a neighbour's doesn't.
var is_players: bool = true

var plots: Array[FarmPlot] = []
var scarecrows: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var _scarecrow_nodes: Array[Node3D] = []
var _crow_timer := 0.0
var _next_index := 0
var _preview := MeshInstance3D.new()
var _preview_ok := StandardMaterial3D.new()
var _preview_bad := StandardMaterial3D.new()
var _preview_frame := -10


func _ready() -> void:
	add_to_group("saveable")
	add_to_group("field")
	if is_players:
		add_to_group("player_field")
	rng.randomize()
	# Last year's beds: already broken, just needing a light re-tilling.
	for i in starters:
		var p := add_plot(to_global(Vector3(layout[i].x, 0, layout[i].y)))
		p.state.till_needed = PlotState.STUBBLE_TILL
	var bm := BoxMesh.new()
	bm.size = Vector3(FarmPlot.SIZE, 0.06, FarmPlot.SIZE)
	_preview.mesh = bm
	for pair: Array in [[_preview_ok, Color(0.4, 0.9, 0.35, 0.35)], [_preview_bad, Color(0.95, 0.3, 0.25, 0.35)]]:
		var m: StandardMaterial3D = pair[0]
		m.albedo_color = pair[1]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)
	Clock.day_started.connect(_on_day_started)
	Clock.minutes_passed.connect(_on_minutes)


## Are there reaped stalks lying anywhere, waiting to be bound?
func any_cut() -> bool:
	for p in plots:
		if p.state.count_plants(PlotState.Plant.CUT) > 0:
			return true
	return false


func half_extents() -> Vector2:
	return GARDEN_HALF


# --- Breaking new ground --------------------------------------------------------------------

## Where a new plot would go for a point on the ground (snapped to a tidy grid).
func snap(point: Vector3) -> Vector3:
	var x := snappedf(point.x, SNAP)
	var z := snappedf(point.z, SNAP)
	return Vector3(x, Terrain.height_at(x, z), z)


## Why a plot can't be dug here, or "" if it can.
func placement_error(pos: Vector3) -> String:
	for f: Field in get_tree().get_nodes_in_group("field"):   # every field, the neighbour's too
		for p in f.plots:
			var d := p.global_position - pos
			if absf(d.x) < FarmPlot.SIZE + 0.3 and absf(d.z) < FarmPlot.SIZE + 0.3:
				return "Too close to another plot."
	var reason := FarmLayout.no_dig_reason(pos)
	if reason != "":
		return reason
	var h := FarmPlot.SIZE / 2.0
	var heights: Array[float] = []
	for c: Vector2 in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		heights.append(Terrain.height_at(pos.x + c.x, pos.z + c.y))
	if heights.max() - heights.min() > 0.25:
		return "Too steep for a plot."
	# Nothing solid (fences, buildings, trees, the well) in the way.
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FarmPlot.SIZE + 0.2, 1.2, FarmPlot.SIZE + 0.2)
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.75, 0))
	q.collide_with_areas = false
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if not (hit.collider is Ground) and not (hit.collider is Player):
			return "Something's in the way."
	return ""


## Dev scenarios: dig the rest of the garden grid.
func fill_garden() -> void:
	for i in range(plots.size(), layout.size()):
		add_plot(to_global(Vector3(layout[i].x, 0, layout[i].y)))


func add_plot(pos: Vector3) -> FarmPlot:
	var p := FarmPlot.new()
	p.index = _next_index
	_next_index += 1
	p.field = self
	p.name = "Plot%d" % p.index
	add_child(p)
	p.global_position = pos
	plots.append(p)
	return p


## Shows where a new plot would go (green: fine, red: not here). Hidden unless called each frame.
func show_preview(pos: Vector3, ok: bool) -> void:
	_preview.global_position = pos + Vector3(0, 0.05, 0)
	_preview.material_override = _preview_ok if ok else _preview_bad
	_preview.visible = true
	_preview_frame = Engine.get_process_frames()


func _process(_delta: float) -> void:
	if _preview.visible and Engine.get_process_frames() - _preview_frame > 2:
		_preview.visible = false


func _on_day_started(_day: int) -> void:
	var news: Array[String] = []
	for p in plots:
		var e := p.daily_update(Clock.season(), Clock.raining, rng)
		if e != "" and not (e in news):
			news.append(e)
	if not is_players:
		return
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


## Crows on the ground eating this field's seed.
func pecking_crows() -> Array[Crow]:
	var out: Array[Crow] = []
	for c in get_children():
		if c is Crow and c.state == Crow.State.PECKING:
			out.append(c)
	return out


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

## Can a scarecrow stand at this world point? Anywhere that isn't on a plot.
func scarecrow_error(point: Vector3) -> String:
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
		var pd := p.to_dict()
		pd["x"] = p.global_position.x
		pd["z"] = p.global_position.z
		ps.append(pd)
	return {"plots": ps, "scarecrows": sc}


func from_dict(d: Dictionary) -> void:
	for p in plots:
		p.free()
	plots.clear()
	for pd: Dictionary in d.plots:
		var p := add_plot(Vector3(pd.x, Terrain.height_at(pd.x, pd.z), pd.z))
		p.from_dict(pd)
	for n in _scarecrow_nodes:
		n.queue_free()
	_scarecrow_nodes.clear()
	scarecrows.clear()
	for s: Array in d.get("scarecrows", []):
		var v := Vector3(s[0], s[1], s[2])
		scarecrows.append(v)
		_spawn_scarecrow(v)
