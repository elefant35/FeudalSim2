class_name DoNow
extends Task
## Something that happens at once (take the cart's handles, sell, let go).

var action: Callable


func _init(what: String, act: Callable) -> void:
	label = what
	action = act


func update(_npc: Npc, _delta: float) -> bool:
	if action.is_valid():
		action.call()
	return true
