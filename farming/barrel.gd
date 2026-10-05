class_name Barrel
extends StaticBody3D
## A barrel for storing and moving produce and grain. E while carrying fills it; E with empty
## hands opens it (take an armful out, or lift the whole barrel to carry it). Set it down
## anywhere, load it into the handcart, or stand it beside the buyer to sell from it.

const CAPACITY := 24

var goods := Inventory.new()
var _top := Node3D.new()


func _ready() -> void:
	add_to_group("barrel")
	add_child(goods)
	add_child(Models.make(&"barrel"))
	_top.position.y = 0.86
	add_child(_top)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.34
	cyl.height = 0.9
	shape.shape = cyl
	shape.position.y = 0.45
	add_child(shape)
	goods.changed.connect(_refresh)
	_refresh()


static func total(inv: Inventory) -> int:
	var n := 0
	for st in inv.stacks():
		n += st.count
	return n


func count() -> int:
	return Barrel.total(goods)


func room() -> int:
	return CAPACITY - count()


func get_prompt(player: Player) -> String:
	var head := "Barrel · %d/%d" % [count(), CAPACITY]
	if player.pulling:
		return head
	if player.is_carrying():
		if player.carry_id == &"barrel":
			return head
		return "%s\n[E] Put your %s in the barrel" % [head, player.carry_text()] if room() > 0 else "%s\nIt's full." % head
	return "%s\n[E] Open it: take things out, or lift the barrel to carry it" % head


func interact(player: Player) -> void:
	if player.is_carrying():
		if player.carry_id == &"barrel":
			player.set_down()
		else:
			Barrel.fill(goods, CAPACITY, player)
			Sfx.play_at("thump", global_position, -8.0)
		return
	var hud: Hud = get_tree().current_scene.hud
	hud.open_container("Barrel", func() -> Array: return _rows(player))


## Moves what the player carries into `inv` (as much as fits; the rest stays in their arms).
static func fill(inv: Inventory, capacity: int, player: Player) -> int:
	var id := player.carry_id
	var units := player.take_carry()
	units.sort()
	units.reverse()   # best first
	var fit := mini(units.size(), capacity - Barrel.total(inv))
	for i in units.size():
		if i < fit:
			inv.add(id, 1, units[i])
		else:
			player.pick_up(id, units[i])
	player.say("Put in %d (%d/%d)." % [fit, Barrel.total(inv), capacity] if fit > 0 else "It's full.")
	return fit


## Rows for a container window: each kind of goods with "Take an armful".
static func goods_rows(inv: Inventory, player: Player, where: String = "") -> Array:
	var rows: Array = []
	var totals := {}
	for st in inv.stacks():
		totals[st.id] = int(totals.get(st.id, 0)) + int(st.count)
	for id: StringName in totals:
		rows.append({"label": "%s%s ×%d" % [where, Items.name_of(id), totals[id]], "buttons": [
			{"text": "Take an armful", "enabled": player.carry_space(id) > 0, "action": func() -> void:
				while player.carry_space(id) > 0:
					var q := inv.take_one(id, true)
					if q < -1:
						break
					player.pick_up(id, q)
				Sfx.play("rustle", -6.0)},
		]})
	return rows


func _rows(player: Player) -> Array:
	var rows := Barrel.goods_rows(goods, player)
	if rows.is_empty():
		rows.append({"label": "Empty. Put produce or grain in while carrying it (E).", "buttons": []})
	rows.append({"label": "The barrel itself (%d inside)" % count(), "buttons": [
		{"text": "Lift it and carry it", "enabled": not player.is_carrying(), "action": func() -> void: lift(player)},
	]})
	return rows


## Picks the barrel up, contents and all.
func lift(player: Player) -> void:
	player.carry_barrel(goods.to_dict())
	Sfx.play_at("thump", global_position, -6.0)
	var hud: Hud = get_tree().current_scene.hud
	hud.close_panel()
	queue_free()


func _refresh() -> void:
	for c in _top.get_children():
		c.queue_free()
	# Show what's inside heaped at the top.
	var stacks := goods.stacks()
	if stacks.is_empty():
		return
	var id: StringName = stacks[0].id
	var it := Items.item(id)
	var show_id: StringName = &"grain_pile" if it.kind == ItemData.Kind.GRAIN and not String(id).ends_with("_sheaf") else id
	var n := clampi(count() / 3, 1, 6)
	for i in n:
		var m := Models.make(show_id)
		var a := float(i) * 2.4
		m.position = Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.12) if show_id != &"grain_pile" else Vector3.ZERO
		if show_id == &"grain_pile":
			m.scale = Vector3(0.7, 0.5, 0.7)
		elif String(id).ends_with("_sheaf"):
			m.scale = Vector3.ONE * 0.6
		_top.add_child(m)
		if show_id == &"grain_pile":
			break


func to_dict() -> Dictionary:
	return {"x": global_position.x, "z": global_position.z, "goods": goods.to_dict()}
