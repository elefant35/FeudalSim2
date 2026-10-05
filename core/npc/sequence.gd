class_name Sequence
extends Task
## Several tasks one after another (walk to the well, then draw water).

var steps: Array[Task] = []
var _i := 0


func _init(what: String, list: Array[Task]) -> void:
	label = what
	steps = list


func start(npc: Npc) -> void:
	_i = 0
	if not steps.is_empty():
		steps[0].start(npc)


func update(npc: Npc, delta: float) -> bool:
	if _i >= steps.size():
		return true
	if steps[_i].update(npc, delta):
		_i += 1
		if _i >= steps.size():
			return true
		steps[_i].start(npc)
	return false


func cancel(npc: Npc) -> void:
	if _i < steps.size():
		steps[_i].cancel(npc)


## The label of what's happening right now (the current step, if it has one).
func current_label() -> String:
	if _i < steps.size() and steps[_i].label != "":
		return steps[_i].label
	return label
