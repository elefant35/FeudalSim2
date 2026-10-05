class_name ProducePile
extends StaticBody3D
## A heap of one kind of bulky goods set down on the ground: turnips, cabbages, a stack of
## sheaves, sacks of grain. E adds what you carry, or picks up an armful.

const MAX_SHOWN := 24
const MERGE_RADIUS := 1.3

var id: StringName
var units: Array[int] = []      ## One quality per unit.
var _visual := Node3D.new()
var _shape := CollisionShape3D.new()


func _ready() -> void:
	add_to_group("pile")
	add_child(_visual)
	var cyl := CylinderShape3D.new()
	_shape.shape = cyl
	add_child(_shape)
	refresh()


func refresh() -> void:
	for c in _visual.get_children():
		c.queue_free()
	var n := mini(units.size(), MAX_SHOWN)
	var sheaf := String(id).ends_with("_sheaf")
	var it := Items.item(id)
	var sack := it != null and it.kind == ItemData.Kind.GRAIN and not sheaf
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in n:
		var m := Models.make(&"grain_sack" if sack else id)
		_visual.add_child(m)
		if sheaf:
			# Laid flat and stacked like a woodpile: three abreast, heads alternating, layer on layer.
			var layer := i / 3
			var col := i % 3
			m.rotation = Vector3(PI / 2, PI if (col + layer) % 2 else 0.0, 0)
			m.position = Vector3((col - 1) * 0.26 + (0.13 if layer % 2 else 0.0), 0.09 + layer * 0.15, 0.0)
			m.position.z = (0.4 if (col + layer) % 2 else -0.4)
		elif sack:
			var row := i % 4
			m.position = Vector3((row % 2) * 0.45 - 0.22, (i / 4) * 0.5, (row / 2) * 0.4 - 0.2)
			m.rotation.y = rng.randf() * 0.6
		else:
			# A rough heap: a widening spiral that stacks up in the middle.
			var r := 0.06 * sqrt(float(i)) * (2.4 if id == &"cabbage" else 1.6)
			var a := float(i) * 2.4
			var layer := float(i) / 10.0
			m.position = Vector3(cos(a) * r, maxf(0.0, 0.12 - r * 0.25) * layer + layer * 0.03, sin(a) * r)
			m.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	var cyl := _shape.shape as CylinderShape3D
	var tall := (0.2 + 0.15 * float(units.size() / 3)) if sheaf else (0.6 + 0.5 * float(units.size() / 4) if sack else 0.3)
	cyl.radius = 0.55 if sheaf else 0.45
	cyl.height = minf(tall, 1.6)
	_shape.position.y = cyl.height / 2.0


func label() -> String:
	return "%s ×%d" % [Items.name_of(id), units.size()]


func get_prompt(player: Player) -> String:
	if player.is_carrying():
		if player.carry_id == id:
			return "%s\n[E] Add yours to the pile" % label()
		return "%s\n[E] Set yours down beside it" % label()
	if player.pulling:
		return label()
	return "%s\n[E] Pick up an armful (up to %d)" % [label(), Items.item(id).carry_max]


func interact(player: Player) -> void:
	if player.is_carrying():
		if player.carry_id == id:
			var n := player.carry_count()
			units.append_array(player.take_carry())
			Sfx.play_at("rustle", global_position)
			player.say("Added %d to the pile (%d now)." % [n, units.size()])
			refresh()
		else:
			player.set_down()
		return
	# Best quality first.
	units.sort()
	var took := 0
	while not units.is_empty() and player.carry_space(id) > 0:
		player.pick_up(id, units.pop_back())
		took += 1
	Sfx.play_at("rustle", global_position)
	if units.is_empty():
		queue_free()
	else:
		refresh()


func to_dict() -> Dictionary:
	return {"id": String(id), "units": units, "x": global_position.x, "z": global_position.z}
