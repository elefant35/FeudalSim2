class_name ProduceBuyer
extends StaticBody3D
## The miller's cart: buys produce and clean grain. Better quality fetches more.


func get_prompt(_player: Player) -> String:
	return "Produce Buyer\n[E] Sell"


func interact(player: Player) -> void:
	Sfx.play_at("coins", global_position, -6.0)
	var hud: Hud = get_tree().current_scene.hud
	hud.open_trade("Produce Buyer", func() -> Array: return _rows(player))


func _rows(player: Player) -> Array:
	var rows: Array = []
	for s in player.inventory.stacks():
		var it := Items.item(s.id)
		if it == null or it.kind == ItemData.Kind.TOOL or it.kind == ItemData.Kind.SEED or it.kind == ItemData.Kind.PLACEABLE:
			continue
		var each := Items.sell_value(s.id, s.quality)
		if each <= 0:
			if it.kind == ItemData.Kind.GRAIN:
				rows.append({"label": "%s ×%d · not wanted until threshed and winnowed" % [Items.name_of(s.id, s.quality), s.count], "buttons": []})
			continue
		var id: StringName = s.id
		var q: int = s.quality
		rows.append({"label": "%s ×%d · %d gold each" % [Items.name_of(id, q), s.count, each], "buttons": [
			{"text": "Sell 1", "enabled": true, "action": func() -> void: _sell(player, id, q, 1)},
			{"text": "Sell all", "enabled": true, "action": func() -> void: _sell(player, id, q, player.inventory.count(id, q))},
		]})
	return rows


func _sell(player: Player, id: StringName, q: int, n: int) -> void:
	if n <= 0 or not player.inventory.remove(id, n, q):
		return
	var total := Items.sell_value(id, q) * n
	player.wallet.add(total)
	Sfx.play("coins", -4.0)
	player.say("Sold for %d gold." % total)
