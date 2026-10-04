class_name FarmLayout
extends RefCounted
## Places everything on the farm. Metres; +x east, +z south. The house stands west of the
## field with its door facing it; the lane with the traders runs along the south.

const HOUSE_POS := Vector3(-15.0, 0.0, -3.0)
const FIELD_POS := Vector3(5.0, 0.0, -3.0)
const WELL_POS := Vector3(-7.0, 0.0, 3.5)
const THRESHING_POS := Vector3(-8.0, 0.0, -12.0)
const STALL_POS := Vector3(-3.0, 0.0, 11.0)
const BUYER_POS := Vector3(7.0, 0.0, 11.5)
const LANE_Z := 14.5

static var bed_wake_position := Vector3(-11.0, 0.0, -3.0)
static var bed_wake_yaw := -PI / 2


static func build(world: Node3D) -> void:
	_house(world)
	var field := Field.new()
	field.name = "Field"
	field.position = FIELD_POS
	world.add_child(field)
	_fence(world, field)
	var well := Well.new()
	well.name = "Well"
	well.position = WELL_POS
	world.add_child(well)
	var tf := ThreshingFloor.new()
	tf.name = "ThreshingFloor"
	tf.position = THRESHING_POS
	world.add_child(tf)
	_stall(world)
	_buyer(world)
	_lane(world)
	_props(world)
	_scatter_nature(world)


## Places a model on the ground at (x, z).
static func place(parent: Node3D, id: StringName, x: float, z: float, yaw: float = 0.0, scale: float = 1.0) -> Node3D:
	var n := Models.make(id)
	n.position = Vector3(x, Terrain.height_at(x, z), z)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


## A static box collider (local to `parent`).
static func solid(parent: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = offset + Vector3(0, size.y / 2.0, 0)
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _house(world: Node3D) -> void:
	var house := Node3D.new()
	house.name = "House"
	house.position = HOUSE_POS
	house.rotation.y = -PI / 2   # door faces east, towards the field
	world.add_child(house)
	var m := Models.make(&"house")
	house.add_child(m)
	# Collide with the cottage's real shape so you can walk in through the door.
	var body := StaticBody3D.new()
	body.add_to_group("wood_floor")
	house.add_child(body)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var shape := CollisionShape3D.new()
		shape.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		shape.transform = house.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform if mi.is_inside_tree() else (mi as MeshInstance3D).transform
		body.add_child(shape)
	var bed := Bed.new()
	bed.name = "Bed"
	bed.position = Vector3(1.95, 0.0, 1.25)
	house.add_child(bed)
	var hearth := OmniLight3D.new()
	hearth.position = Vector3(-2.25, 0.6, 1.75)
	hearth.light_color = Color(1.0, 0.6, 0.3)
	hearth.light_energy = 1.6
	hearth.omni_range = 6.0
	house.add_child(hearth)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.0, 0.0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.5
	lamp.omni_range = 5.0
	house.add_child(lamp)
	bed_wake_position = HOUSE_POS + house.basis * Vector3(0.9, 0.1, 1.25)
	bed_wake_yaw = -PI / 2


static func _fence(world: Node3D, field: Field) -> void:
	var he := field.half_extents() + Vector2(1.2, 1.2)
	var c := field.position
	var fence := Node3D.new()
	fence.name = "Fence"
	world.add_child(fence)
	# Four sides; the west side (towards the house) has a gap for a gate.
	var sides := [
		[Vector3(c.x - he.x, 0, c.z - he.y), Vector3(c.x + he.x, 0, c.z - he.y)],
		[Vector3(c.x + he.x, 0, c.z - he.y), Vector3(c.x + he.x, 0, c.z + he.y)],
		[Vector3(c.x + he.x, 0, c.z + he.y), Vector3(c.x - he.x, 0, c.z + he.y)],
		[Vector3(c.x - he.x, 0, c.z + he.y), Vector3(c.x - he.x, 0, c.z + 1.2)],
		[Vector3(c.x - he.x, 0, c.z - 1.2), Vector3(c.x - he.x, 0, c.z - he.y)],
	]
	for s: Array in sides:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var length := a.distance_to(b)
		var n := maxi(1, ceili(length / 3.0))
		var seg := length / n
		var dir := (b - a).normalized()
		var yaw := atan2(-dir.z, dir.x)
		for i in n:
			var mid := a + dir * seg * (i + 0.5)
			var f := place(fence, &"fence_simple", mid.x, mid.z, yaw)
			f.scale = Vector3(seg / 3.0, 1, 1)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, 1.1, 0.15)
		shape.shape = box
		body.add_child(shape)
		body.position = (a + b) / 2.0 + Vector3(0, 0.55, 0)
		body.rotation.y = yaw
		fence.add_child(body)
	# Gate posts.
	for z in [c.z - 1.2, c.z + 1.2]:
		var post := Models.box(Vector3(0.18, 1.4, 0.18), Color(0.33, 0.22, 0.13), Vector3(c.x - he.x, 0.7, z))
		fence.add_child(post)


static func _sign(parent: Node3D, text: String, pos: Vector3, yaw: float) -> void:
	var s := place(parent, &"signboard", pos.x, pos.z, yaw)
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color(0.2, 0.12, 0.06)
	l.outline_size = 0
	l.position = Vector3(0, 1.45, 0.04)
	l.double_sided = false
	s.add_child(l)
	var back := l.duplicate() as Label3D
	back.position.z = -0.04
	back.rotation.y = PI
	s.add_child(back)


static func _stall(world: Node3D) -> void:
	var stall := ToolStall.new()
	stall.name = "ToolStall"
	stall.position = STALL_POS
	stall.rotation.y = PI    # counter faces north, towards the farm
	world.add_child(stall)
	stall.add_child(Models.make(&"town_stall_red"))
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.6, 1.2, 2.4)
	shape.shape = b
	shape.position.y = 0.6
	stall.add_child(shape)
	# Wares on the counter and around.
	var wares := [[&"hoe", Vector3(-0.8, 1.6, 0.6), Vector3(0, 0, 0.4)], [&"sickle", Vector3(0.0, 1.9, 0.7), Vector3(0, 0, 0)],
		[&"bucket", Vector3(0.7, 1.35, 0.4), Vector3.ZERO], [&"seed_pouch", Vector3(-0.3, 0.98, -0.5), Vector3.ZERO],
		[&"seed_pouch", Vector3(0.2, 0.98, -0.6), Vector3.ZERO], [&"food_loaf", Vector3(0.7, 0.98, -0.5), Vector3.ZERO]]
	for w: Array in wares:
		var n := Models.make(w[0])
		n.position = w[1]
		n.rotation = w[2]
		stall.add_child(n)
	for p: Array in [[&"surv_barrel", Vector3(1.8, 0, 0.5)], [&"surv_box", Vector3(-1.8, 0, 0.8)], [&"grain_sack", Vector3(-1.7, 0, -0.3)], [&"scarecrow", Vector3(2.0, 0, -1.2)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		stall.add_child(n)
	_sign(world, "Tools & Seed", STALL_POS + Vector3(-2.4, 0, -1.6), 0.3)


static func _buyer(world: Node3D) -> void:
	var cart := ProduceBuyer.new()
	cart.name = "ProduceBuyer"
	cart.position = BUYER_POS
	cart.rotation.y = PI / 2
	world.add_child(cart)
	cart.add_child(Models.make(&"town_cart_high"))
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.2, 1.6, 3.3)
	shape.shape = b
	shape.position.y = 0.8
	cart.add_child(shape)
	for p: Array in [[&"grain_sack", Vector3(0.3, 0.75, 0.4)], [&"grain_sack", Vector3(-0.3, 0.75, 0.6)], [&"grain_sack", Vector3(0.1, 0.75, -0.3)],
			[&"cabbage", Vector3(-0.4, 0.8, -0.8)], [&"turnip", Vector3(0.4, 0.8, -0.9)], [&"turnip", Vector3(0.25, 0.8, -0.75)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		cart.add_child(n)
	for p: Array in [[&"surv_barrel", Vector3(-1.6, 0, 1.6)], [&"surv_box_large", Vector3(1.7, 0, 1.2)], [&"grain_sack", Vector3(1.6, 0, -0.6)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		cart.add_child(n)
	_sign(world, "Produce Bought", BUYER_POS + Vector3(-2.6, 0, -1.8), -0.3)


static func _lane(world: Node3D) -> void:
	var lane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 3.4)
	lane.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/farm_soil_diff.jpg")
	m.albedo_color = Color(0.85, 0.75, 0.62)
	m.uv1_scale = Vector3(40, 1.2, 1)
	m.roughness = 1.0
	lane.material_override = m
	lane.position = Vector3(0, 0.02, LANE_Z)
	world.add_child(lane)
	# A worn path from the house door to the field gate.
	var path := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(9.5, 1.6)
	path.mesh = pp
	path.material_override = m
	path.position = Vector3(-6.4, 0.025, -3.0)
	world.add_child(path)


static func _props(world: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Props"
	world.add_child(props)
	place(props, &"log_stack", -18.5, -6.2, 0.2)
	place(props, &"surv_barrel", -11.6, -0.4)
	place(props, &"food_barrel", -11.4, -6.0, 0.6)
	place(props, &"surv_box", -18.2, 0.6, 0.4)
	place(props, &"stump_round", -7.5, 6.2)
	place(props, &"surv_workbench", -10.0, -10.5, 0.4)
	place(props, &"grain_sack", -5.0, -12.5)
	place(props, &"grain_sack", -4.6, -13.1, 0.7)
	place(props, &"town_lantern", -11.0, -0.9)
	for p: Array in [[-18.5, -6.2, 1.2, 1.4], [-11.6, -0.4, 0.8, 1.0], [-11.4, -6.0, 1.0, 1.0], [-10.0, -10.5, 1.1, 1.0]]:
		solid(props, Vector3(p[2], p[3], p[2]), Vector3(p[0], 0, p[1]))


static func _scatter_nature(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var trees: Array[StringName] = [&"tree_oak", &"tree_default", &"tree_fat", &"tree_detailed", &"tree_pineRoundA"]
	var nature := Node3D.new()
	nature.name = "Nature"
	world.add_child(nature)
	var blocked := func(x: float, z: float, margin: float) -> bool:
		return x > -24.0 - margin and x < 16.0 + margin and z > -20.0 - margin and z < 18.0 + margin
	var placed := 0
	while placed < 170:
		var x := rng.randf_range(-85, 85)
		var z := rng.randf_range(-85, 85)
		if blocked.call(x, z, 2.0):
			continue
		placed += 1
		var t := place(nature, trees[rng.randi() % trees.size()], x, z, rng.randf() * TAU, rng.randf_range(0.8, 1.3))
		t.add_to_group("tree")
		solid(nature, Vector3(0.6, 3.0, 0.6), t.position)
	# Some trees closer in for shade and framing.
	for p: Array in [[-21, -10], [-20, 6], [-13, -16], [12, -14], [16, 6], [-24, -1], [3, -15]]:
		var t := place(nature, trees[rng.randi() % 4], p[0], p[1], rng.randf() * TAU, 1.1)
		t.add_to_group("tree")
		solid(nature, Vector3(0.6, 3.0, 0.6), t.position)
	var small: Array[StringName] = [&"plant_bush", &"plant_bushLarge", &"rock_smallA", &"rock_smallB", &"grass_large", &"grass", &"flower_yellowA", &"flower_redA", &"flower_purpleA", &"grass_leafs"]
	for i in 420:
		var x := rng.randf_range(-45, 45)
		var z := rng.randf_range(-40, 40)
		if blocked.call(x, z, -6.0) and not (z > LANE_Z - 3.0 and z < LANE_Z + 3.5 and false):
			# Keep the farmyard tidy, but allow tufts along its edges.
			if absf(x - FIELD_POS.x) < 9.0 and absf(z - FIELD_POS.z) < 7.0:
				continue
			if absf(z - LANE_Z) < 2.2:
				continue
			if rng.randf() < 0.75:
				continue
		place(nature, small[rng.randi() % small.size()], x, z, rng.randf() * TAU, rng.randf_range(0.8, 1.4))
	for p: Array in [[-30, 20], [26, -24], [-34, -18], [30, 22]]:
		place(nature, &"rock_largeA" if p[0] < 0 else &"rock_largeB", p[0], p[1], rng.randf() * TAU, 1.2)
