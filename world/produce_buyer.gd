class_name ProduceBuyer
extends StaticBody3D
## The miller's cart: buys produce and clean grain from your arms, your pack, or a handcart
## parked beside it. Better quality fetches more.

const CART_RANGE := 9.0


func get_prompt(player: Player) -> String:
	var cart := nearby_cart()
	var extra := "  ·  your handcart is close enough to sell from" if cart and cart.count() > 0 else ""
	if player.pulling and not extra:
		extra = "  ·  let go of the handcart here to sell from it"
	return "Produce Buyer\n[E] Sell%s" % extra


func interact(player: Player) -> void:
	Sfx.play_at("coins", global_position, -6.0)
	var hud: Hud = get_tree().current_scene.hud
	hud.open_trade("Produce Buyer", func() -> Array: return _rows(player))


## A handcart parked within reach of the buyer (and not being pulled).
func nearby_cart() -> HandCart:
	for c: HandCart in get_tree().get_nodes_in_group("cart"):
		if c.global_position.distance_to(global_position) < CART_RANGE:
			return c
	return null


func _rows(player: Player) -> Array:
	var rows: Array = []
	# In your arms.
	if player.is_carrying():
		var counts := {}
		for q in player.carry_units:
			counts[q] = int(counts.get(q, 0)) + 1
		for q: int in counts:
			_add_row(rows, "In your arms", player.carry_id, q, counts[q], func(n: int) -> void: _sell_from_arms(player, q, n))
	# In your pack.
	for st in player.inventory.stacks():
		var id: StringName = st.id
		var q: int = st.quality
		_add_row(rows, "In your pack", id, q, st.count, func(n: int) -> void: _sell_from(player, player.inventory, id, q, n))
	# In the handcart (loose and in its barrels), and in barrels set down nearby.
	var sources: Array = []
	var cart := nearby_cart()
	if cart:
		sources.append(["In the handcart", cart.goods])
		for i in cart.barrels.size():
			sources.append(["In barrel %d on the handcart" % (i + 1), cart.barrels[i]])
	for b: Barrel in get_tree().get_nodes_in_group("barrel"):
		if b.global_position.distance_to(global_position) < CART_RANGE:
			sources.append(["In a barrel beside the buyer", b.goods])
	for src: Array in sources:
		var inv: Inventory = src[1]
		for st in inv.stacks():
			var id: StringName = st.id
			var q: int = st.quality
			_add_row(rows, src[0], id, q, st.count, func(n: int) -> void: _sell_from(player, inv, id, q, n))
	if rows.is_empty() and not player.is_carrying():
		rows.append({"label": "Bring produce or clean grain in your arms, or park your handcart (or a barrel) beside the buyer.", "buttons": []})
	return rows


func _add_row(rows: Array, where: String, id: StringName, q: int, count: int, sell: Callable) -> void:
	var it := Items.item(id)
	if it == null or it.kind in [ItemData.Kind.TOOL, ItemData.Kind.SEED, ItemData.Kind.PLACEABLE, ItemData.Kind.FOOD]:
		return
	var each := Items.sell_value(id, q)
	if each <= 0:
		if it.kind == ItemData.Kind.GRAIN:
			rows.append({"label": "%s ×%d · not wanted until threshed and winnowed" % [Items.name_of(id, q), count], "tooltip": where, "buttons": []})
		return
	rows.append({"label": "%s ×%d · %d gold each" % [Items.name_of(id, q), count, each], "tooltip": where, "buttons": [
		{"text": "Sell 1", "enabled": true, "action": func() -> void: sell.call(1)},
		{"text": "Sell all (%d g)" % (each * count), "enabled": true, "action": func() -> void: sell.call(count)},
	]})


func _sell_from(player: Player, source: Inventory, id: StringName, q: int, n: int) -> void:
	if n <= 0 or not source.remove(id, n, q):
		return
	_paid(player, Items.sell_value(id, q) * n)


func _sell_from_arms(player: Player, q: int, n: int) -> void:
	var id := player.carry_id
	var units := player.take_carry()
	var sold := 0
	for u in units:
		if u == q and sold < n:
			sold += 1
		else:
			player.pick_up(id, u)
	_paid(player, Items.sell_value(id, q) * sold)


func _paid(player: Player, total: int) -> void:
	if total <= 0:
		return
	player.wallet.add(total)
	Sfx.play("coins", -4.0)
	player.say("Sold for %d gold." % total)
