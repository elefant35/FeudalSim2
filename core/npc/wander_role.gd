class_name WanderRole
extends Role
## The simplest role: stroll about near home. Useful for idle villagers and for testing.

var radius := 8.0


func _init() -> void:
	title = "villager"


func next_task() -> Task:
	var a := randf() * TAU
	var p := npc.home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, radius)
	var steps: Array[Task] = [GoTo.new(p, 0.8, "Strolling"), Work.new("Looking about", &"idle", 3.0, Callable())]
	return Sequence.new("Strolling", steps)
