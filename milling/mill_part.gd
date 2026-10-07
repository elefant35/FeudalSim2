class_name MillPart
extends Area3D
## Something on a windmill you can aim at (the tailpole, the brake, the hopper...). Passes the
## player's look, E and click on to the mill with its own name, so the mill keeps all the rules.

var mill: PostMill
var part: StringName


static func make(m: PostMill, what: StringName, size: Vector3, at: Vector3) -> MillPart:
	var p := MillPart.new()
	p.mill = m
	p.part = what
	p.name = String(what).capitalize().replace(" ", "")
	p.position = at
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	p.add_child(shape)
	return p


func get_prompt(player: Player) -> String:
	return mill.part_prompt(part, player)


func interact(player: Player) -> void:
	mill.part_interact(part, player)


func use(player: Player) -> Minigame:
	return mill.part_use(part, player)
