class_name Task
extends RefCounted
## One step of what a villager is doing: walk somewhere, work at something. A Role hands out
## tasks one at a time; the Npc runs them. Tasks never decide; they carry out.

## What the villager would say they're doing ("Weeding the cabbages").
var label: String = ""


func start(_npc: Npc) -> void:
	pass


## Advance; return true when finished.
func update(_npc: Npc, _delta: float) -> bool:
	return true


func cancel(_npc: Npc) -> void:
	pass
