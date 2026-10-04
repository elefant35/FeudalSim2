class_name ThreshingFloor
extends StaticBody3D
## Where grain is beaten from the sheaves (flail) and cleaned of chaff (winnowing basket).
## The pennant shows the wind.

const CAPACITY := 6
const SHEAF_TO_CHAFF := {&"barley_sheaf": &"barley_chaff", &"wheat_sheaf": &"wheat_chaff"}

var wind: float = 0.0
var sheaves: Array[Dictionary] = []    # [{id, quality, progress}]
var _sheaf_nodes: Array[Node3D] = []
var _noise := FastNoiseLite.new()
var _t := 0.0
var _pennant: Node3D
var _pile: Node3D
var _pile_amount := 0.0
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
	_pile.position = Vector3(-1.2, 0.08, 1.0)
	_pile.visible = false
	add_child(_pile)
	_noise.frequency = 0.35
	_noise.seed = 5
	Clock.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	_pile_amount = 0.0
	_refresh()


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
func beat(amount: float, player: Player) -> String:
	if not has_sheaves():
		return ""
	sheaves[0].progress += amount
	var n := _sheaf_nodes[0]
	n.scale = Vector3(1.0, 1.0, maxf(0.3, 1.0 - sheaves[0].progress * 0.6))
	if sheaves[0].progress < 1.0:
		return ""
	var s: Dictionary = sheaves.pop_front()
	var out: StringName = SHEAF_TO_CHAFF[StringName(s.id)]
	player.inventory.add(out, 1, int(s.quality))
	_pile_amount += 1.0
	_refresh()
	return "Threshed: %s." % Items.name_of(out, int(s.quality)).to_lower()


func _chaff_held(player: Player) -> StringName:
	for id: StringName in SHEAF_TO_CHAFF.values():
		if player.inventory.has(id):
			return id
	return &""


func _sheaves_held(player: Player) -> int:
	var n := 0
	for id: StringName in SHEAF_TO_CHAFF:
		n += player.inventory.count(id)
	return n


func get_prompt(player: Player) -> String:
	var lines: Array[String] = ["Threshing floor · %d/%d sheaves laid" % [sheaves.size(), CAPACITY],
		"Lay sheaves (E)  →  thresh (flail)  →  winnow (basket)"]
	var held := player.held()
	if _sheaves_held(player) > 0 and sheaves.size() < CAPACITY:
		lines.append("[E] Lay out your sheaves")
	if held == &"flail":
		lines.append("[Click] Thresh in rhythm" if has_sheaves() else "Lay sheaves here to thresh them.")
	elif held == &"winnowing_basket":
		lines.append("[Hold left, release to toss] Winnow" if _chaff_held(player) != &"" else "Thresh some grain first.")
	elif has_sheaves() and not player.inventory.has(&"flail"):
		lines.append("You need a flail to thresh (tool stall).")
	elif _chaff_held(player) != &"" and not player.inventory.has(&"winnowing_basket"):
		lines.append("You need a winnowing basket to clean the grain (tool stall).")
	elif has_sheaves():
		lines.append("Hold your flail to thresh.")
	elif _chaff_held(player) != &"":
		lines.append("Hold your winnowing basket to clean the grain.")
	return "\n".join(lines)


func interact(player: Player) -> void:
	var laid := 0
	for id: StringName in SHEAF_TO_CHAFF:
		while sheaves.size() < CAPACITY:
			var q := player.inventory.take_one(id)
			if q < -1:
				break
			sheaves.append({"id": String(id), "quality": q, "progress": 0.0})
			laid += 1
	if laid > 0:
		Sfx.play_at("rustle", global_position)
		player.say("You lay out %d sheaf%s." % [laid, "" if laid == 1 else "s"])
		_refresh()
	elif sheaves.size() >= CAPACITY:
		player.say("The floor is full. Thresh what's here first.")


func use(player: Player) -> Minigame:
	if player.held() == &"flail" and has_sheaves():
		return ThreshGame.new(self)
	if player.held() == &"winnowing_basket":
		var item := _chaff_held(player)
		if item != &"":
			return WinnowGame.new(self, item)
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
	_pile.visible = _pile_amount > 0.0
	_pile.scale = Vector3.ONE * clampf(0.5 + _pile_amount * 0.1, 0.5, 1.6)


func to_dict() -> Dictionary:
	return {"sheaves": sheaves, "pile": _pile_amount}


func from_dict(d: Dictionary) -> void:
	sheaves.clear()
	for s: Dictionary in d.get("sheaves", []):
		sheaves.append({"id": String(s.id), "quality": int(s.quality), "progress": float(s.progress)})
	_pile_amount = float(d.get("pile", 0.0))
	_refresh()
