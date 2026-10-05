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
const CART_POS := Vector3(-4.5, 0.0, 1.6)
# The neighbour's smallholding, east of yours.
const NB_HOUSE := Vector3(30.0, 0.0, -9.0)
const NB_FIELD := Vector3(22.0, 0.0, 3.0)
const NB_FLOOR := Vector3(22.0, 0.0, -17.0)
const NB_WELL := Vector3(17.5, 0.0, -9.0)
const NB_CART := Vector3(29.0, 0.0, 4.0)
const NB_LAYOUT: Array[Vector2] = [Vector2(-3, -1.5), Vector2(0, -1.5), Vector2(3, -1.5), Vector2(-3, 1.5), Vector2(0, 1.5), Vector2(3, 1.5)]

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
	_sign(world, "Threshing Floor", THRESHING_POS + Vector3(3.2, 0, 2.6), -0.6)
	var piles := Piles.new()
	piles.name = "Piles"
	world.add_child(piles)
	var cart := HandCart.new()
	cart.name = "HandCart"
	world.add_child(cart)
	cart.global_position = CART_POS
	cart.global_rotation.y = PI / 2   # parked beside the garden gate, handles towards the house
	_stall(world)
	_buyer(world)
	_neighbour(world)
	_lane(world)
	_props(world)
	_scatter_nature(world)


## Why the ground at `pos` can't be dug for a plot (paths, the lane, the threshing floor), or "".
static func no_dig_reason(pos: Vector3) -> String:
	if absf(pos.z - LANE_Z) < 3.3:
		return "Not on the lane."
	if pos.x > -11.4 and pos.x < -1.4 and absf(pos.z - (-3.0)) < 2.0:
		return "Not on the path to the house."
	if Vector2(pos.x - BUYER_POS.x, pos.z - BUYER_POS.z).length() < 4.5 or Vector2(pos.x - STALL_POS.x, pos.z - STALL_POS.z).length() < 4.0:
		return "Too close to the traders."
	if Vector2(pos.x - THRESHING_POS.x, pos.z - THRESHING_POS.z).length() < 4.4:
		return "Too close to the threshing floor."
	if Vector2(pos.x, pos.z).length() > 60.0:
		return "That's too far from the farm."
	return ""


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


## The world-space bounds of a model's meshes.
static func mesh_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi: MeshInstance3D in meshes:
		var a: AABB = mi.global_transform * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


## A box collider matching a placed model's bounds, so what you see is what you bump into.
static func collide_with(parent: Node3D, n: Node3D, shrink: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var a := mesh_aabb(n)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = (a.size - shrink).max(Vector3(0.05, 0.05, 0.05))
	shape.shape = b
	body.add_child(shape)
	parent.add_child(body)
	body.global_position = a.get_center()
	return body


static func _house(world: Node3D) -> void:
	var house := _cottage(world, "House", HOUSE_POS, -PI / 2)   # door faces east, towards the field
	bed_wake_position = HOUSE_POS + house.basis * Vector3(0.9, 0.1, 1.25)
	bed_wake_yaw = -PI / 2


## A cottage with its bed, hearth and lamp. Returns the cottage node (bed at local (1.95, 0, 1.25)).
static func _cottage(world: Node3D, node_name: String, pos: Vector3, yaw: float) -> Node3D:
	var house := Node3D.new()
	house.name = node_name
	house.position = pos
	house.rotation.y = yaw
	world.add_child(house)
	var m := Models.make(&"house")
	house.add_child(m)
	# Collide with the cottage's real shape so you can walk in through the door.
	var body := StaticBody3D.new()
	body.add_to_group("wood_floor")
	house.add_child(body)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name == "fire" or mi.name == "fire":
			continue
		var shape := CollisionShape3D.new()
		shape.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		shape.transform = house.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		body.add_child(shape)
	if node_name == "House":   # only your own bed is yours to sleep in
		var bed := Bed.new()
		bed.name = "Bed"
		bed.position = Vector3(1.95, 0.0, 1.25)
		house.add_child(bed)
	var hearth := Hearth.new()
	hearth.fire = m.find_child("fire", true, false)
	hearth.position = Vector3(-2.55, 0.5, 0.9)
	house.add_child(hearth)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.0, 0.0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.35
	lamp.omni_range = 5.0
	house.add_child(lamp)
	# Rain stops at the roof.
	var roof := GPUParticlesCollisionBox3D.new()
	roof.size = Vector3(7.0, 4.8, 6.0)
	roof.position = Vector3(0, 2.2, 0)
	house.add_child(roof)
	return house


## Wynn's smallholding: cottage, well, six beds, a threshing floor, a handcart, and Wynn.
static func _neighbour(world: Node3D) -> void:
	var house := _cottage(world, "WynnHouse", NB_HOUSE, PI / 2)   # door faces west, towards the beds
	var well := Well.new()
	well.name = "WynnWell"
	well.position = NB_WELL
	world.add_child(well)
	var field := Field.new()
	field.name = "WynnField"
	field.is_players = false
	field.layout = NB_LAYOUT
	field.starters = NB_LAYOUT.size()
	field.position = NB_FIELD
	world.add_child(field)
	var tf := ThreshingFloor.new()
	tf.name = "WynnFloor"
	tf.position = NB_FLOOR
	world.add_child(tf)
	var cart := HandCart.new()
	cart.name = "WynnCart"
	cart.owner_key = &"wynn"
	world.add_child(cart)
	cart.global_position = NB_CART
	cart.global_rotation.y = PI / 2
	_sign(world, "Wynn's Farm", NB_FIELD + Vector3(-6.0, 0, 5.5), 0.4)
	var wynn := Npc.new()
	wynn.name = "Wynn"
	wynn.display_name = "Wynn"
	wynn.owner_key = &"wynn"
	wynn.bed = house.global_transform * Vector3(1.95, 0.0, 1.25)
	wynn.home = house.global_transform * Vector3(0.0, 0.0, -3.6)   # just outside the door
	wynn.tint = {"tunic": Color(0.33, 0.43, 0.3), "hair": Color(0.55, 0.36, 0.18)}
	var role := FarmerRole.new()
	role.field = field
	role.floor_ = tf
	role.cart = cart
	role.well = well
	wynn.role = role
	world.add_child(wynn)
	wynn.global_position = wynn.home
	role.stock_up()


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
			# The model's geometry isn't centred on its origin: shift it onto the fence line.
			var off := mid - mesh_aabb(f).get_center()
			f.position += Vector3(off.x, 0, off.z)
			collide_with(fence, f)
	# Gate posts.
	for z in [c.z - 1.2, c.z + 1.2]:
		var post := Models.box(Vector3(0.18, 1.4, 0.18), Color(0.33, 0.22, 0.13), Vector3(c.x - he.x, 0.7, z))
		fence.add_child(post)
		collide_with(fence, post)


static func _sign(parent: Node3D, text: String, pos: Vector3, yaw: float) -> void:
	var s := place(parent, &"signboard", pos.x, pos.z, yaw)
	collide_with(parent, s, Vector3(0.0, 0.0, 0.0))
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 48
		l.pixel_size = 0.0031
		l.modulate = Color(0.22, 0.13, 0.06)
		l.outline_size = 0
		l.double_sided = false
		l.position = Vector3(0, 1.45, 0.032 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		s.add_child(l)


static func _stall(world: Node3D) -> void:
	var stall := ToolStall.new()
	stall.name = "ToolStall"
	stall.add_to_group("stall")
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
	# Wares on the counter, and a hoe and a sickle leaning against it.
	var wares := [
		[&"seed_pouch", Vector3(-0.5, 0.97, -0.55), 0.0], [&"seed_pouch", Vector3(-0.2, 0.97, -0.65), 0.6],
		[&"seed_pouch", Vector3(0.1, 0.97, -0.5), 1.2], [&"food_loaf", Vector3(0.55, 0.97, -0.55), 0.3],
		[&"food_loaf", Vector3(0.8, 0.97, -0.45), 1.1],
	]
	for w: Array in wares:
		var n := Models.make(w[0])
		n.position = w[1]
		n.rotation.y = w[2]
		stall.add_child(n)
	var hoe := Models.make(&"hoe")
	hoe.position = Vector3(-0.9, 0.35, 1.3)
	hoe.rotation = Vector3(0.25, 0.0, 0.0)
	stall.add_child(hoe)
	var bucket := Models.make(&"bucket")
	bucket.position = Vector3(0.9, 0.45, 1.45)
	stall.add_child(bucket)
	for p: Array in [[&"barrel", Vector3(1.8, 0, 0.5)], [&"crate", Vector3(-1.8, 0, 0.8)], [&"grain_sack", Vector3(-1.7, 0, -0.3)], [&"scarecrow", Vector3(2.0, 0, -1.2)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		stall.add_child(n)
		if p[0] != &"scarecrow":
			collide_with(stall, n)
	_sign(world, "Tools & Seed", STALL_POS + Vector3(-2.6, 0, -1.8), 0.3)


static func _buyer(world: Node3D) -> void:
	var cart := ProduceBuyer.new()
	cart.name = "ProduceBuyer"
	cart.add_to_group("buyer")
	cart.position = BUYER_POS
	cart.rotation.y = PI / 2
	world.add_child(cart)
	cart.add_child(Models.make(&"farm_cart"))
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, 1.2, 2.2)
	shape.shape = b
	shape.position.y = 0.6
	cart.add_child(shape)
	for p: Array in [[&"grain_sack", Vector3(0.3, 0.79, 0.4)], [&"grain_sack", Vector3(-0.3, 0.79, 0.55)], [&"grain_sack", Vector3(0.1, 0.79, -0.3)],
			[&"cabbage", Vector3(-0.35, 0.79, -0.6)], [&"turnip", Vector3(0.35, 0.79, -0.75)], [&"turnip", Vector3(0.2, 0.79, -0.6)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		cart.add_child(n)
	for p: Array in [[&"barrel", Vector3(-1.4, 0, 1.6)], [&"crate", Vector3(1.5, 0, 1.2)], [&"grain_sack", Vector3(1.4, 0, -0.6)]]:
		var n := Models.make(p[0])
		n.position = p[1]
		cart.add_child(n)
		collide_with(cart, n)
	_sign(world, "Produce Bought", BUYER_POS + Vector3(-2.8, 0, -1.8), -0.3)


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
	var solid_props := [
		place(props, &"log_stack", -18.5, -6.2, 0.2),
		place(props, &"barrel", -11.6, -0.6),
		place(props, &"barrel", -11.5, -5.6, 0.6),
		place(props, &"crate", -18.0, 0.8, 0.4),
		place(props, &"crate", -11.4, -6.5, 0.2),
		place(props, &"stump_round", -10.0, -10.5),
	]
	place(props, &"stump_round", -7.5, 6.2)
	for n: Node3D in solid_props:
		collide_with(props, n)
	var post := place(props, &"lantern_post", -11.2, -1.4, PI)
	collide_with(props, post, Vector3(0.5, 0, 0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.4)
	glow.light_energy = 0.0
	glow.omni_range = 5.0
	glow.position = Vector3(0.5, 1.75, 0)
	glow.add_to_group("night_light")
	post.add_child(glow)


static func _scatter_nature(world: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var trees: Array[StringName] = [&"tree_oak", &"tree_default", &"tree_fat", &"tree_detailed", &"tree_pineRoundA"]
	var nature := Node3D.new()
	nature.name = "Nature"
	world.add_child(nature)
	var blocked := func(x: float, z: float, margin: float) -> bool:
		return x > -24.0 - margin and x < 36.0 + margin and z > -24.0 - margin and z < 18.0 + margin
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
