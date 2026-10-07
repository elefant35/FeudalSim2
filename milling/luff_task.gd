class_name LuffTask
extends Task
## On the tailpole: walk a windmill round on its post until the sails face the wind. The mill
## follows whoever holds the tailpole (as it does for the player); this walks the villager
## round the circle a step ahead of it.

var mill: PostMill
var _t := 0.0


func _init(m: PostMill) -> void:
	mill = m
	label = "Turning the mill into the wind"


func start(npc: Npc) -> void:
	mill.grab(npc)
	npc.say("Round she comes.")


func update(npc: Npc, delta: float) -> bool:
	_t += delta * Clock.speed()
	var want := mill.wind_heading()
	if npc.instant:
		mill.turn_to(want)
		return _done(npc)
	var diff := angle_difference(mill.heading, want)
	if absf(diff) < 0.05 or _t > 90.0:
		return _done(npc)
	var ahead := mill.heading + clampf(diff, -0.3, 0.3)
	var r := Vector2(PostMill.TAIL_END.x, PostMill.TAIL_END.z).length()
	var at := ahead + PostMill.tail_angle()
	var p := mill.global_position + Vector3(sin(at), 0, cos(at)) * r
	npc.walk_to(Vector3(p.x, npc.global_position.y, p.z), true)
	return false


func _done(npc: Npc) -> bool:
	npc.stop_walking()
	mill.release(npc)
	return true


func cancel(npc: Npc) -> void:
	npc.stop_walking()
	if mill.is_pulled():
		mill.release(npc)
