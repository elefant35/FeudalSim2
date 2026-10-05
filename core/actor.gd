class_name Actor
extends CharacterBody3D
## Anyone who lives and works in the world: the player now, villagers too. Owns the things the
## rules care about: needs, gold, a pack, and what's carried in the arms. World objects work
## with an Actor, so whoever steps into a role (farmer, baker...) uses the same rules.
## Subclasses add how they're driven (the player's input, an NPC's role).

signal message(text: String)
signal carry_changed

const POCKET_MAX := 6           ## Produce the pack can hold, for eating on the go.

var display_name: String = "Someone"
## Whose things are whose: carts, barrels and the buyer's lists go by this.
var owner_key: StringName = &"player"
var needs := Needs.new()
var wallet := Wallet.new()
var inventory := Inventory.new()
## What's in the arms: one kind of bulky item, one quality per unit.
var carry_id: StringName = &""
var carry_units: Array[int] = []
## A carried barrel's contents (an Inventory dict), when carry_id is &"barrel".
var carry_payload: Dictionary = {}
## The handcart being pulled, if any.
var pulling: Node3D = null


func _ready() -> void:
	needs.name = "Needs"
	wallet.name = "Wallet"
	inventory.name = "Inventory"
	for c: Node in [needs, wallet, inventory]:
		add_child(c)


## A line of feedback (the player's HUD shows its own; NPCs can show theirs above their head).
func say(text: String) -> void:
	message.emit(text)


# --- Carrying bulky goods in the arms ---------------------------------------------------------

func is_carrying() -> bool:
	return not carry_units.is_empty()


func carry_count() -> int:
	return carry_units.size()


## How many more of `id` the arms can take right now.
func carry_space(id: StringName) -> int:
	var it := Items.item(id)
	if it == null or it.carry_max <= 0 or pulling != null:
		return 0
	if is_carrying() and carry_id != id:
		return 0
	return it.carry_max - carry_units.size()


func pick_up(id: StringName, quality: int) -> bool:
	if carry_space(id) <= 0:
		return false
	carry_id = id
	carry_units.append(quality)
	carry_units.sort()
	_carry_updated()
	return true


## Empties the arms, returning what was carried (one quality per unit).
func take_carry() -> Array[int]:
	var units := carry_units.duplicate()
	carry_units.clear()
	carry_id = &""
	carry_payload = {}
	_carry_updated()
	return units


## Lifts a barrel (with what's in it) into the arms.
func carry_barrel(contents: Dictionary) -> void:
	carry_id = &"barrel"
	carry_units = [0]
	carry_payload = contents
	_carry_updated()


func carry_text() -> String:
	if not is_carrying():
		return ""
	if carry_id == &"barrel":
		var n := 0
		for k: String in carry_payload:
			n += int(carry_payload[k])
		return "a barrel (%d inside)" % n
	return "%d %s" % [carry_count(), Items.name_of(carry_id).to_lower() + ("s" if carry_count() > 1 and not carry_id.ends_with("y") else "")]


## Called whenever the arms change. Subclasses update what they show.
func _carry_updated() -> void:
	carry_changed.emit()


## Keeps one unit of carried grain back as seed (a sack of clean barley → 6 handfuls of seed).
func keep_as_seed() -> bool:
	var it := Items.item(carry_id) if is_carrying() else null
	if it == null or it.sow_as == &"":
		return false
	carry_units.pop_front()   # the plainest sack
	if carry_units.is_empty():
		carry_id = &""
	inventory.add(it.sow_as, it.sow_quantity)
	_carry_updated()
	say("You keep a sack back as seed: %d handfuls of %s." % [it.sow_quantity, Items.name_of(it.sow_as).to_lower()])
	return true


## Produce held in the pack.
func pocket_count() -> int:
	var n := 0
	for st in inventory.stacks():
		var it := Items.item(st.id)
		if it and it.carry_max > 0:
			n += st.count
	return n


## Moves one unit of food from the arms into the pack.
func pocket_one() -> bool:
	if not is_carrying() or Items.item(carry_id).food_value <= 0.0 or pocket_count() >= POCKET_MAX:
		return false
	var id := carry_id
	var q: int = carry_units.pop_back()
	if carry_units.is_empty():
		carry_id = &""
	inventory.add(id, 1, q)
	_carry_updated()
	return true


## Sets the load down at `at`: a barrel stays a barrel; anything else goes onto a matching pile
## nearby or starts a new one.
func set_down_at(at: Vector3) -> void:
	if not is_carrying():
		return
	at.y = Terrain.height_at(at.x, at.z)
	var piles := get_tree().get_first_node_in_group("piles")
	if piles == null:
		return
	if carry_id == &"barrel":
		var contents := carry_payload
		take_carry()
		piles.spawn_barrel(at, contents)
		Sfx.play_at("thump", at, -4.0)
		return
	var id := carry_id
	var units := take_carry()
	piles.put(id, units, at)
	Sfx.play_at("rustle", at)
	say("You set down %d %s." % [units.size(), Items.name_of(id).to_lower()])


# --- Eating ----------------------------------------------------------------------------------

## Eats the plainest food at hand: from the arms first, then the pack.
func eat_something() -> void:
	if needs.hunger >= 98.0:
		say("You're not hungry.")
		return
	if is_carrying() and Items.item(carry_id).food_value > 0.0:
		var id := carry_id
		var q: int = carry_units.pop_front()
		if carry_units.is_empty():
			carry_id = &""
		_carry_updated()
		inventory.add(id, 1, q)
		eat(id, q)
		return
	var best: ItemData = null
	for s in inventory.stacks():
		var it := Items.item(s.id)
		if it and it.food_value > 0.0 and (best == null or it.food_value < best.food_value):
			best = it
	if best == null:
		say("You have nothing to eat. Buy bread at the stall, or grow turnips.")
		return
	eat(best.id, inventory.qualities_of(best.id).front())


func eat(id: StringName, quality: int) -> void:
	var it := Items.item(id)
	if it == null or not inventory.remove(id, 1, quality):
		return
	needs.eat(it.food_value * (1.0 + 0.1 * maxi(quality, 0)))


# --- Save ------------------------------------------------------------------------------------

func actor_dict() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y,
		"needs": needs.to_dict(), "gold": wallet.gold, "inventory": inventory.to_dict(),
		"carry_id": String(carry_id), "carry_units": carry_units, "carry_payload": carry_payload,
	}


func load_actor_dict(d: Dictionary) -> void:
	global_position = Vector3(d.pos[0], d.pos[1], d.pos[2])
	rotation.y = float(d.yaw)
	needs.from_dict(d.needs)
	wallet.gold = int(d.gold)
	wallet.changed.emit(wallet.gold)
	inventory.from_dict(d.inventory)
	carry_id = StringName(d.get("carry_id", ""))
	carry_units.clear()
	for q in d.get("carry_units", []):
		carry_units.append(int(q))
	if carry_units.is_empty():
		carry_id = &""
	carry_payload = d.get("carry_payload", {})
