class_name GoTo
extends Task
## Walk to a point (by the navigation mesh where there is one, or straight there if `direct`:
## inside a building, up a mill's steps).

var target: Vector3
var near: float
var direct := false
var _stuck := 0.0
var _last := Vector3.INF


func _init(where: Vector3, close_enough: float = 0.7, what: String = "", straight: bool = false) -> void:
	target = where
	near = close_enough
	label = what
	direct = straight


func start(npc: Npc) -> void:
	npc.walk_to(target, direct)


## Where to put them if they hop: on the ground, or at the target's own height indoors.
func _landing() -> Vector3:
	return target + Vector3(0, 0.05, 0) if direct else Vector3(target.x, Terrain.height_at(target.x, target.z), target.z)


func update(npc: Npc, delta: float) -> bool:
	if npc.instant:
		npc.global_position = _landing()
		npc.stop_walking()
		if npc.pulling and npc.pulling.has_method("trail"):
			npc.pulling.trail()   # a pulled cart comes along
		return true
	var flat := Vector2(npc.global_position.x - target.x, npc.global_position.z - target.z)
	if flat.length() <= near:
		npc.stop_walking()
		return true
	# Not getting anywhere for a while: hop the last bit rather than stand stuck forever.
	if _last != Vector3.INF and npc.global_position.distance_to(_last) < 0.02:
		_stuck += delta
	else:
		_stuck = 0.0
	_last = npc.global_position
	if _stuck > 4.0:
		print("NPC %s was stuck at %s walking to %s; hopped there" % [npc.name, npc.global_position.snapped(Vector3.ONE * 0.1), target.snapped(Vector3.ONE * 0.1)])
		npc.global_position = _landing()
		npc.stop_walking()
		if npc.pulling and npc.pulling.has_method("trail"):
			npc.pulling.trail()
		return true
	return false


func cancel(npc: Npc) -> void:
	npc.stop_walking()
