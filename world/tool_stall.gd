class_name ToolStall
extends StaticBody3D
## The travelling ironmonger's stall: tools, seed, bread. Prices come from item data.


func get_prompt(_player: Player) -> String:
	return "Tools & Seed\n[E] Trade"


func interact(player: Player) -> void:
	Sfx.play_at("coins", global_position, -6.0)
	var hud: Hud = get_tree().current_scene.hud
	hud.open_trade("Tools & Seed", func() -> Array: return _rows(player))


func _rows(player: Player) -> Array:
	var rows: Array = []
	var items := Items.all_items().filter(func(it: ItemData) -> bool: return it.buy_price > 0)
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.kind != b.kind:
			return a.kind < b.kind
		return a.buy_price < b.buy_price)
	for it: ItemData in items:
		var owned := it.kind == ItemData.Kind.TOOL and player.inventory.has(it.id)
		var qty := " (%d handfuls)" % it.buy_quantity if it.kind == ItemData.Kind.SEED else ""
		var have := "" if it.kind == ItemData.Kind.TOOL else "   you have %d" % player.inventory.count(it.id)
		var label := "%s%s · %d gold%s" % [it.display_name, qty, it.buy_price, have]
		var btn := {"text": "Owned" if owned else "Buy", "enabled": not owned and player.wallet.can_afford(it.buy_price),
			"action": func() -> void: _buy(player, it)}
		rows.append({"label": label, "tooltip": it.description, "buttons": [btn]})
	return rows


func _buy(player: Player, it: ItemData) -> void:
	if not player.wallet.spend(it.buy_price):
		return
	player.inventory.add(it.id, it.buy_quantity)
	Sfx.play("coins", -4.0)
	player.say("Bought %s." % it.display_name.to_lower())
