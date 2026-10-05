class_name PoseRole
extends Role
## Dev and testing: does one thing over and over (an animation with a tool in hand).

var anim: StringName
var tool: StringName


func _init(animation: StringName, held: StringName = &"") -> void:
	anim = animation
	tool = held
	title = String(animation)


func next_task() -> Task:
	return Work.new(String(anim).capitalize(), anim, 30.0, Callable(), tool)
