class_name ThreshingFloor
extends StaticBody3D
## Where grain is beaten from the sheaves (flail) and cleaned of chaff (winnowing basket).
## Sheaves are carried here and laid out (E); threshed grain stays on the floor as a heap;
## winnowed grain goes into sacks beside the floor, ready to carry off. The pennant shows the wind.

const CAPACITY := 6
const SHEAF_TO_CHAFF := {&"barley_sheaf": &"barley_chaff", &"wheat_sheaf": &"wheat_chaff"}

var wind: float = 0.0
var sheaves: Array[Dictionary] = []    # [{id, quality, progress}]
var heap := Inventory.new()            ## Threshed, unwinnowed grain on the floor.
var sacks := Inventory.new()           ## Clean grain, bagged beside the floor.
var _sheaf_nodes: Array[Node3D] = []
var _noise := FastNoiseLite.new()
var _t := 0.0
var _pennant: Node3D
var _pile: Node3D
var _sack_nodes := Node3D.new()
var _shown_wind := 0.0
var _flap_phase := 0.0


func _ready() -> void:
	add_to_group("saveable")
	add_child(Models.make(&"threshing_floor"))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 0.12
	shape.shape = cyl
	shape.position.y = 0.06
	add_child(shape)
	# Pennant on a pole at the floor's edge.
	var pole := Models.box(Vector3(0.08, 3.2, 0.08), Color(0.33, 0.22, 0.13), Vector3(2.7, 1.6, 0))
	add_child(pole)
	_pennant = Node3D.new()
	_pennant.position = Vector3(2.7, 3.0, 0)
	add_child(_pennant)
	var cloth := Models.box(Vector3(0.9, 0.35, 0.02), Color(0.7, 0.18, 0.14), Vector3(0.45, 0, 0))
	_pennant.add_child(cloth)
	_pile = Models.make(&"chaff_pile")
	_pile.position = Vector3(-0.9, 0.08, 0.8)
	_pile.visible = false
	add_child(_pile)
	add_child(heap)
	add_child(sacks)
	_sack_nodes.position = Vector3(-1.6, 0.0, -2.9)   # just off the floor's edge
	add_child(_sack_nodes)
	_noise.frequency = 0.35
	_noise.seed = 5


func _process(delta: float) -> void:
	_t += delta
	var gusty := 0.5 + 0.5 * _noise.get_noise_1d(_t * 1.0)
	var flutter := _noise.get_noise_1d(_t * 6.0 + 100.0)
	wind = clampf(gusty * 1.25 - 0.15 + flutter * 0.08, 0.0, 1.0)
	_shown_wind = lerpf(_shown_wind, wind, minf(1.0, delta * 3.0))
	_flap_phase += delta * (5.0 + _shown_wind * 9.0)
	var dir := wind_dir()
	_pennant.rotation.y = atan2(-dir.z, dir.x)
	_pennant.rotation.z = lerpf(-1.25, -0.05, _shown_wind) + sin(_flap_phase) * 0.06 * (0.3 + _shown_wind)


func wind_dir() -> Vector3:
	var a := 0.6 + _noise.get_noise_1d(_t * 0.05 + 50.0) * 0.8
	return Vector3(cos(a), 0, sin(a))


func has_sheaves() -> bool:
	return not sheaves.is_empty()


func current_progress() -> float:
	return sheaves[0].progress if has_sheaves() else 0.0


func sheaf_position() -> Vector3:
	return _sheaf_nodes[0].global_position if not _sheaf_nodes.is_empty() else global_position + Vector3(0, 0.1, 0)


## Adds threshing progress to the current sheaf. Returns a message when a sheaf is done.
func beat(amount: float, _player: Player) -> String:
	if not has_sheaves():
		return ""
	sheaves[0].progress += amount
	var n := _sheaf_nodes[0]
	n.scale = Vector3(1.0, 1.0, maxf(0.3, 1.0 - sheaves[0].progress * 0.6))
	if sheaves[0].progress < 1.0:
		return ""
	var s: Dictionary = sheaves.pop_front()
	heap.add(SHEAF_TO_CHAFF[StringName(s.id)], 1, int(s.quality))
	_refresh()
	return "Sheaf threshed. The grain lies on the floor with its chaff."


func heap_count() -> int:
	var n := 0
	for st in heap.stacks():
		n += st.count
	return n


func sack_count() -> int:
	var n := 0
	for st in sacks.stacks():
		n += st.count
	return n


## The next measure of unwinnowed grain to clean (best first), or &"" if none. Takes it off the heap.
func take_from_heap() -> Dictionary:
	for id: StringName in SHEAF_TO_CHAFF.values():
		var q := heap.take_one(id, true)
		if q > -2:
			_refresh()
			return {"id": id, "quality": q}
	return {}


func return_to_heap(id: StringName, quality: int) -> void:
	heap.add(id, 1, quality)
	_refresh()


func add_clean(id: StringName, quality: int) -> void:
	sacks.add(id, 1, quality)
	_refresh()


func get_prompt(player: Player) -> String:
	var lines: Array[String] = ["Threshing floor · %d/%d sheaves laid" % [sheaves.size(), CAPACITY]]
	if heap_count() > 0:
		lines[0] += " · %d threshed to winnow" % heap_count()
	if sack_count() > 0:
		lines[0] += " · %d sacks of clean grain" % sack_count()
	lines.append("Lay sheaves (E)  →  thresh (flail)  →  winnow (basket)  →  carry off the sacks (E)")
	var held := player.held()
	if held == Player.CARRYING:
		if SHEAF_TO_CHAFF.has(player.carry_id):
			lines.append("[E] Lay out your sheaves" if sheaves.size() < CAPACITY else "The floor is full. Thresh what's here first.")
		else:
			lines.append("You're carrying %s. Set it down elsewhere." % player.carry_text())
	elif held == &"flail":
		lines.append("[Click] Thresh in rhythm" if has_sheaves() else "Bring sheaves here to thresh them.")
	elif held == &"winnowing_basket":
		lines.append("[Hold left, release to toss] Winnow" if heap_count() > 0 else "Thresh some sheaves first.")
	elif sack_count() > 0 and held != Player.PULLING:
		lines.append("[E] Pick up sacks of clean grain")
	elif has_sheaves():
		lines.append("Hold your flail to thresh." if player.inventory.has(&"flail") else "You need a flail to thresh (tool stall).")
	elif heap_count() > 0:
		lines.append("Hold your winnowing basket to clean the grain." if player.inventory.has(&"winnowing_basket") else "You need a winnowing basket (tool stall).")
	return "\n".join(lines)


func interact(player: Player) -> void:
	if player.is_carrying():
		if not SHEAF_TO_CHAFF.has(player.carry_id):
			player.say("Only sheaves go on the threshing floor.")
			return
		var id := player.carry_id
		var units := player.take_carry()
		var laid := 0
		for q in units:
			if sheaves.size() < CAPACITY:
				sheaves.append({"id": String(id), "quality": q, "progress": 0.0})
				laid += 1
			else:
				player.pick_up(id, q)
		Sfx.play_at("rustle", global_position)
		player.say("You lay out %d sheaf%s." % [laid, "" if laid == 1 else "s"] if laid > 0 else "The floor is full. Thresh what's here first.")
		_refresh()
		return
	if sack_count() > 0:
		var took := 0
		for st in sacks.stacks():
			while player.carry_space(st.id) > 0:
				var q := sacks.take_one(st.id, true)
				if q < -1:
					break
				player.pick_up(st.id, q)
				took += 1
			if took > 0:
				break
		Sfx.play_at("rustle", global_position)
		_refresh()


func use(player: Player) -> Minigame:
	if player.held() == &"flail" and has_sheaves():
		return ThreshGame.new(self)
	if player.held() == &"winnowing_basket" and heap_count() > 0:
		return WinnowGame.new(self)
	return null


func _refresh() -> void:
	for n in _sheaf_nodes:
		n.queue_free()
	_sheaf_nodes.clear()
	for i in sheaves.size():
		var n := Models.make(StringName(sheaves[i].id))
		var a := float(i) / CAPACITY * TAU
		n.position = Vector3(cos(a) * 1.0, 0.16, sin(a) * 1.0)
		n.rotation = Vector3(PI / 2, -a, 0)
		n.scale = Vector3(1, 1, maxf(0.3, 1.0 - float(sheaves[i].progress) * 0.6))
		add_child(n)
		_sheaf_nodes.append(n)
	var h := heap_count()
	_pile.visible = h > 0
	_pile.scale = Vector3.ONE * clampf(0.5 + h * 0.12, 0.5, 1.6)
	for c in _sack_nodes.get_children():
		c.queue_free()
	for i in mini(sack_count(), 12):
		var m := Models.make(&"grain_sack")
		m.position = Vector3((i % 4) * 0.45, (i / 4) * 0.55, 0.0)
		m.rotation.y = i * 0.7
		_sack_nodes.add_child(m)


func to_dict() -> Dictionary:
	return {"sheaves": sheaves, "heap": heap.to_dict(), "sacks": sacks.to_dict()}


func from_dict(d: Dictionary) -> void:
	sheaves.clear()
	for s: Dictionary in d.get("sheaves", []):
		sheaves.append({"id": String(s.id), "quality": int(s.quality), "progress": float(s.progress)})
	heap.from_dict(d.get("heap", {}))
	sacks.from_dict(d.get("sacks", {}))
	_refresh()
