class_name Work
extends Task
## Do something on the spot for a while (an animation, a tool in hand), then apply its effect.
## Durations are game-time aware: at 4x speed, work finishes 4x sooner.

var anim: StringName
var tool: StringName
var seconds: float
var face: Variant          ## A Vector3 to turn towards, or null.
var on_done: Callable
var _t := 0.0


func _init(what: String, animation: StringName, duration: float, done: Callable, held: StringName = &"", look_at_point: Variant = null) -> void:
	label = what
	anim = animation
	seconds = duration
	on_done = done
	tool = held
	face = look_at_point


func start(npc: Npc) -> void:
	npc.hold(tool)
	npc.act(anim)
	if face is Vector3:
		npc.face(face)


func update(npc: Npc, delta: float) -> bool:
	_t += delta * Clock.speed()
	if npc.instant or _t >= seconds:
		npc.act(&"")
		npc.hold(&"")
		if on_done.is_valid():
			on_done.call()
		return true
	return false


func cancel(npc: Npc) -> void:
	npc.act(&"")
	npc.hold(&"")
