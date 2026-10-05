class_name HandCart
extends AnimatableBody3D
## A two-wheeled handcart. Load produce, sheaves and grain into it (E while carrying), take an
## armful back out (E), or grab the handles (E at the front) and pull it behind you. The produce
## buyer buys straight from a cart parked beside them.

const CAPACITY := 40
const SHAFT := 2.6        ## Distance from the cart's centre to where you hold the shafts.
const HANDLE_REACH := 1.4 ## How close to the shaft ends counts as "at the handles".
const MAX_BARRELS := 3

var owner_key: StringName = &"player"
var goods := Inventory.new()
var barrels: Array[Inventory] = []   ## Barrels standing in the cart, with what's in them.
var _stuck_warned := 0.0
var _visual := Node3D.new()
var _contents := Node3D.new()
var _puller: Actor = null


func _ready() -> void:
	add_to_group("cart")
	add_to_group("saveable")
	sync_to_physics = false
	add_child(goods)
	add_child(_visual)
	# The model's shafts point forward (-Z), towards whoever pulls it.
	_visual.add_child(Models.make(&"farm_cart"))
	_visual.add_child(_contents)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.7, 0.9, 2.2)
	shape.shape = b
	shape.position.y = 0.7   # clear of the ground, so only real obstacles stop it
	add_child(shape)
	goods.changed.connect(_refresh_contents)
	_refresh_contents()


func count() -> int:
	var n := 0
	for st in goods.stacks():
		n += st.count
	return n


func room() -> int:
	return CAPACITY - count()


## The point where you hold the shafts (in front of the cart).
func handle_point() -> Vector3:
	return global_position - global_basis.z * SHAFT


func _at_handles(player: Player) -> bool:
	return player.target_point.distance_to(handle_point()) < HANDLE_REACH or \
		player.global_position.distance_to(handle_point()) < HANDLE_REACH


func get_prompt(player: Player) -> String:
	var head := "Handcart · %d/%d" % [count(), CAPACITY]
	if _puller:
		return head
	if not barrels.is_empty():
		head += " · %d barrel%s" % [barrels.size(), "" if barrels.size() == 1 else "s"]
	if player.is_carrying():
		if player.carry_id == &"barrel":
			return "%s\n[E] Stand the barrel in the cart" % head if barrels.size() < MAX_BARRELS else "%s\nNo room for another barrel." % head
		return "%s\n[E] Load your %s" % [head, player.carry_text()] if room() > 0 else "%s\nIt's full." % head
	if _at_handles(player):
		return "%s\n[E] Take the handles and pull" % head
	return "%s\n[E] Look inside   ·   pull it from the handles at the front" % head


func interact(player: Player) -> void:
	if player.is_carrying():
		if player.carry_id == &"barrel":
			_load_barrel(player)
		else:
			load_from(player)
		return
	if _at_handles(player):
		grab(player)
		return
	var hud: Hud = get_tree().current_scene.hud
	hud.open_container("Handcart", func() -> Array: return _rows(player))


func _load_barrel(player: Actor) -> void:
	if barrels.size() >= MAX_BARRELS:
		player.say("There's no room for another barrel.")
		return
	var inv := Inventory.new()
	add_child(inv)
	inv.from_dict(player.carry_payload)
	inv.changed.connect(_refresh_contents)
	barrels.append(inv)
	player.take_carry()
	Sfx.play_at("thump", global_position, -6.0)
	_refresh_contents()


func _rows(player: Player) -> Array:
	var rows := Barrel.goods_rows(goods, player)
	for i in barrels.size():
		var inv := barrels[i]
		rows.append_array(Barrel.goods_rows(inv, player, "In barrel %d: " % (i + 1)))
		rows.append({"label": "Barrel %d (%d inside)" % [i + 1, Barrel.total(inv)], "buttons": [
			{"text": "Lift it out", "enabled": not player.is_carrying(), "action": func() -> void:
				player.carry_barrel(inv.to_dict())
				barrels.erase(inv)
				inv.queue_free()
				_refresh_contents()},
		]})
	if rows.is_empty():
		rows.append({"label": "Empty. Load produce, sheaves, grain or barrels into it while carrying them (E).", "buttons": []})
	return rows


## Loads what the player is carrying (as much as fits).
func load_from(player: Actor) -> void:
	var id := player.carry_id
	var units := player.take_carry()
	var fit := mini(units.size(), room())
	units.sort()
	for i in units.size():
		if i < fit:
			goods.add(id, 1, units[units.size() - 1 - i])
		else:
			player.pick_up(id, units[units.size() - 1 - i])   # the rest stays in your arms
	Sfx.play_at("thump", global_position, -6.0)
	player.say("Loaded %d into the cart (%d/%d)." % [fit, count(), CAPACITY] if fit > 0 else "The cart is full.")


## Takes the biggest stack of one kind out, as much as you can carry, best quality first.
func take_armful(player: Actor) -> void:
	var totals := {}
	for st in goods.stacks():
		totals[st.id] = int(totals.get(st.id, 0)) + int(st.count)
	var pick: StringName = &""
	for id: StringName in totals:
		if pick == &"" or totals[id] > totals[pick]:
			pick = id
	if pick == &"":
		return
	while player.carry_space(pick) > 0:
		var q := goods.take_one(pick, true)
		if q < -1:
			break
		player.pick_up(pick, q)
	Sfx.play_at("rustle", global_position)


func grab(player: Actor) -> void:
	_puller = player
	player.pulling = self
	player.add_collision_exception_with(self)
	player._carry_updated()
	Sfx.play_at("crank", global_position, -8.0)
	player.say("Pulling the handcart. E to let go.")


func release(player: Actor) -> void:
	_puller = null
	player.pulling = null
	player.remove_collision_exception_with(self)
	player._carry_updated()


## Puts the cart straight behind its puller (used when the puller moves instantly, in tests).
func trail() -> void:
	if _puller == null:
		return
	var back := _puller.global_basis.z
	var to := _puller.global_position + Vector3(back.x, 0, back.z).normalized() * SHAFT
	global_position = Vector3(to.x, Terrain.height_at(to.x, to.z), to.z)


func is_pulled() -> bool:
	return _puller != null


func _physics_process(delta: float) -> void:
	if _puller == null:
		return
	# Trailer physics: the cart's front stays at the puller's hands, and it swings in behind.
	var hitch := _puller.global_position
	var from := global_position
	var dir := Vector3(from.x - hitch.x, 0, from.z - hitch.z)
	if dir.length() < 0.01:
		dir = global_basis.z
	dir = dir.normalized()
	var to := hitch + dir * SHAFT
	to.y = Terrain.height_at(to.x, to.z)
	var motion := Vector3(to.x - from.x, 0, to.z - from.z)
	var moved := motion.length()
	var turned := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), from)
	_stuck_warned = maxf(0.0, _stuck_warned - delta)
	if moved > 0.0005 and test_move(turned, motion):
		# Snagged on a fence, a wall or a tree: the cart won't come, and it holds you back
		# (you never silently let go). Back up or turn to work it free, or E to let go.
		var away := Vector3(hitch.x - from.x, 0, hitch.z - from.z)
		if away.length() > SHAFT:
			var held := from + away.normalized() * SHAFT
			_puller.global_position = Vector3(held.x, _puller.global_position.y, held.z)
			_puller.velocity = Vector3(0, _puller.velocity.y, 0)
			if _stuck_warned <= 0.0:
				_stuck_warned = 2.5
				Sfx.play_at("thump", global_position, -6.0)
				if _puller is Player:
					(_puller as Player).viewmodel.play_jerk()
				_puller.say("The handcart is caught. Back up or turn to free it (E lets go).")
		return
	global_position = to
	global_rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	if moved > 0.02 and randf() < delta * 4.0:
		Sfx.play_at("crank", global_position, -16.0, 0.3)


func _refresh_contents() -> void:
	for c in _contents.get_children():
		c.queue_free()
	for b in barrels.size():
		var m := Models.make(&"barrel")
		m.position = Vector3(-0.35 + b * 0.35, 0.79, 0.65)
		m.scale = Vector3.ONE * 0.85
		_contents.add_child(m)
	var i := 0
	for st in goods.stacks():
		var it := Items.item(st.id)
		var sheaf := String(st.id).ends_with("_sheaf")
		var sack := it.kind == ItemData.Kind.GRAIN and not sheaf
		var shown := mini(int(st.count), 4 if sack else 10)
		for k in shown:
			if i >= 30:
				return
			var m := Models.make(&"grain_sack" if sack else st.id)
			var col := i % 4
			var row := (i / 4) % 5
			var layer := i / 20
			m.position = Vector3(-0.42 + col * 0.28, 0.82 + layer * 0.16, -0.75 + row * 0.36)
			if sheaf:
				m.rotation = Vector3(PI / 2, 0, 0)
				m.position.x = -0.2 + (i % 2) * 0.4
			else:
				m.rotation.y = i * 1.7
			if sack:
				m.scale = Vector3.ONE * 0.8
			_contents.add_child(m)
			i += 1


func to_dict() -> Dictionary:
	var bs: Array = []
	for inv in barrels:
		bs.append(inv.to_dict())
	return {"x": global_position.x, "z": global_position.z, "yaw": global_rotation.y, "goods": goods.to_dict(), "barrels": bs, "owner": String(owner_key)}


func from_dict(d: Dictionary) -> void:
	global_position = Vector3(d.x, Terrain.height_at(d.x, d.z), d.z)
	global_rotation = Vector3(0, float(d.yaw), 0)
	owner_key = StringName(d.get("owner", owner_key))
	goods.from_dict(d.get("goods", {}))
	for inv in barrels:
		inv.queue_free()
	barrels.clear()
	for bd: Dictionary in d.get("barrels", []):
		var inv := Inventory.new()
		add_child(inv)
		inv.from_dict(bd)
		inv.changed.connect(_refresh_contents)
		barrels.append(inv)
	_refresh_contents()
