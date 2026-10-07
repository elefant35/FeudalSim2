class_name WaitUntil
extends Task
## Stand by until something is true (the sails have stopped), or give up after a while.

var anim: StringName
var ready: Callable
var timeout: float
var _t := 0.0


func _init(what: String, condition: Callable, animation: StringName = &"idle", give_up_after: float = 60.0) -> void:
	label = what
	ready = condition
	anim = animation
	timeout = give_up_after


func start(npc: Npc) -> void:
	npc.act(anim)


func update(npc: Npc, delta: float) -> bool:
	_t += delta * Clock.speed()
	if ready.call() or npc.instant or _t >= timeout:
		npc.act(&"")
		return true
	return false


func cancel(npc: Npc) -> void:
	npc.act(&"")
