class_name Fx
extends RefCounted
## One-shot particle bursts (dirt clods, seed, water, chaff).


static func burst(where: Node, pos: Vector3, color: Color, amount: int = 16, speed: float = 2.0,
		dir: Vector3 = Vector3.UP, spread: float = 50.0, size: float = 0.03, gravity: float = 9.8,
		life: float = 0.8) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = Models.mat(color)
	p.mesh = mesh
	where.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static func dirt(where: Node, pos: Vector3, amount: int = 14) -> void:
	burst(where, pos, Color(0.32, 0.22, 0.14), amount, 2.2, Vector3.UP, 45.0, 0.04)


## A thrown stream from `from` toward `to` (seed, water).
static func throw(where: Node, from: Vector3, to: Vector3, color: Color, amount: int, size: float) -> void:
	var d := to - from
	var t := 0.45
	var v := Vector3(d.x / t, (d.y + 0.5 * 9.8 * t * t) / t, d.z / t)
	burst(where, from, color, amount, v.length(), v.normalized(), 9.0, size, 9.8, t + 0.05)
