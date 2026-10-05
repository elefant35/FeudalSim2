class_name Piles
extends Node3D
## Keeps track of the piles of goods set down around the farm, and saves them.


func _ready() -> void:
	add_to_group("piles")
	add_to_group("saveable")


## Puts goods on the ground at `at`: onto a matching pile nearby, or as a new pile.
func put(id: StringName, units: Array[int], at: Vector3) -> ProducePile:
	for p: ProducePile in get_children():
		if p.is_queued_for_deletion():
			continue
		if p.id == id and p.global_position.distance_to(at) < ProducePile.MERGE_RADIUS:
			p.units.append_array(units)
			p.refresh()
			return p
	var pile := ProducePile.new()
	pile.id = id
	pile.units = units
	add_child(pile)
	pile.global_position = Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
	pile.rotation.y = randf() * TAU
	return pile


func all_piles() -> Array[ProducePile]:
	var out: Array[ProducePile] = []
	for p: ProducePile in get_children():
		if not p.is_queued_for_deletion() and not p.units.is_empty():
			out.append(p)
	return out


func to_dict() -> Dictionary:
	var list: Array = []
	for p in all_piles():
		list.append(p.to_dict())
	return {"piles": list}


func from_dict(d: Dictionary) -> void:
	for p in get_children():
		p.free()
	for pd: Dictionary in d.get("piles", []):
		var units: Array[int] = []
		for q in pd.units:
			units.append(int(q))
		put(StringName(pd.id), units, Vector3(pd.x, 0, pd.z))
