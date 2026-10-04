class_name Inventory
extends Node
## Item stacks keyed by item id and quality (-1 for items without quality).

signal changed

var _stacks: Dictionary = {}   # "id|quality" -> int


static func _key(id: StringName, quality: int) -> String:
	return "%s|%d" % [id, quality]


func add(id: StringName, amount: int = 1, quality: int = -1) -> void:
	if amount <= 0:
		return
	var k := _key(id, quality)
	_stacks[k] = int(_stacks.get(k, 0)) + amount
	changed.emit()


## Removes from one exact stack. Returns false (and removes nothing) if there aren't enough.
func remove(id: StringName, amount: int = 1, quality: int = -1) -> bool:
	var k := _key(id, quality)
	var have: int = _stacks.get(k, 0)
	if have < amount:
		return false
	if have == amount:
		_stacks.erase(k)
	else:
		_stacks[k] = have - amount
	changed.emit()
	return true


## Removes one unit of `id`, lowest quality first. Returns the quality taken, or -2 if none.
func take_one(id: StringName, best_first: bool = false) -> int:
	var qualities := qualities_of(id)
	if qualities.is_empty():
		return -2
	var q: int = qualities.back() if best_first else qualities.front()
	remove(id, 1, q)
	return q


## Qualities held for `id`, ascending.
func qualities_of(id: StringName) -> Array[int]:
	var out: Array[int] = []
	for k: String in _stacks:
		var parts := k.split("|")
		if StringName(parts[0]) == id:
			out.append(int(parts[1]))
	out.sort()
	return out


func count(id: StringName, quality: int = -999) -> int:
	if quality != -999:
		return _stacks.get(_key(id, quality), 0)
	var total := 0
	for q in qualities_of(id):
		total += int(_stacks[_key(id, q)])
	return total


func has(id: StringName) -> bool:
	return count(id) > 0


## [{id, quality, count}] sorted by id then quality.
func stacks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: String in _stacks:
		var parts := k.split("|")
		out.append({"id": StringName(parts[0]), "quality": int(parts[1]), "count": int(_stacks[k])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.id != b.id:
			return String(a.id) < String(b.id)
		return a.quality < b.quality)
	return out


func to_dict() -> Dictionary:
	return _stacks.duplicate()


func from_dict(d: Dictionary) -> void:
	_stacks.clear()
	for k: String in d:
		_stacks[k] = int(d[k])
	changed.emit()
