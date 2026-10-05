class_name HandCart
extends AnimatableBody3D
## A two-wheeled handcart. Load produce, sheaves and grain into it (E while carrying), take an
## armful back out (E), or grab the handles (E at the front) and pull it behind you. The produce
## buyer buys straight from a cart parked beside them.

const CAPACITY := 40
const SHAFT := 2.6        ## Distance from the cart's centre to where you hold the shafts.
const HANDLE_REACH := 1.4 ## How close to the shaft ends counts as "at the handles".

var goods := Inventory.new()
var _visual := Node3D.new()
var _contents := Node3D.new()
var _puller: Player = null


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
	b.size = Vector3(1.7, 1.1, 2.2)
	shape.shape = b
	shape.position.y = 0.6
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
	if player.is_carrying():
		return "%s\n[E] Load your %s" % [head, player.carry_text()] if room() > 0 else "%s\nIt's full." % head
	if _at_handles(player):
		return "%s\n[E] Take the handles and pull" % head
	if count() > 0:
		return "%s\n[E] Take an armful out   ·   pull it from the handles at the front" % head
	return "%s\nEmpty. Load produce into it, then pull it from the handles at the front." % head


func interact(player: Player) -> void:
	if player.is_carrying():
		load_from(player)
		return
	if _at_handles(player):
		grab(player)
		return
	take_armful(player)


## Loads what the player is carrying (as much as fits).
func load_from(player: Player) -> void:
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
func take_armful(player: Player) -> void:
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


func grab(player: Player) -> void:
	_puller = player
	player.pulling = self
	player.add_collision_exception_with(self)
	player.viewmodel.set_held(player.held())
	player.hotbar_changed.emit()
	Sfx.play_at("crank", global_position, -8.0)
	player.say("Pulling the handcart. E to let go.")


func release(player: Player) -> void:
	_puller = null
	player.pulling = null
	player.remove_collision_exception_with(self)
	player.viewmodel.set_held(player.held())
	player.hotbar_changed.emit()


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
	var moved := Vector2(to.x - from.x, to.z - from.z).length()
	global_position = to
	global_rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	if moved > 0.02 and randf() < delta * 4.0:
		Sfx.play_at("crank", global_position, -16.0, 0.3)


func _refresh_contents() -> void:
	for c in _contents.get_children():
		c.queue_free()
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
	return {"x": global_position.x, "z": global_position.z, "yaw": global_rotation.y, "goods": goods.to_dict()}


func from_dict(d: Dictionary) -> void:
	global_position = Vector3(d.x, Terrain.height_at(d.x, d.z), d.z)
	global_rotation = Vector3(0, float(d.yaw), 0)
	goods.from_dict(d.get("goods", {}))
