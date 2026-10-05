class_name SleepTask
extends Task
## Lie in bed until morning (or until rested, if it's a nap).


func _init() -> void:
	label = "Sleeping"


func start(npc: Npc) -> void:
	npc.lie_down()


func update(npc: Npc, _delta: float) -> bool:
	var h := Clock.hour()
	var morning := h >= 6.0 and h < 20.0
	if npc.instant or (morning and npc.needs.energy > 85.0):
		npc.get_up()
		return true
	return false


func cancel(npc: Npc) -> void:
	npc.get_up()
