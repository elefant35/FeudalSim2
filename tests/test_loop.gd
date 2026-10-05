extends TestCase
## End-to-end: loads the real world scene and plays through the farming loop by driving the
## same objects the player uses (minigames are fed button presses directly).


func _world() -> Node3D:
	var w: Node3D = load("res://world/world.tscn").instantiate()
	tree.root.add_child(w)
	tree.current_scene = w
	return w


func _finish(w: Node3D) -> void:
	tree.root.remove_child(w)
	w.free()


## Presses a TillGame's button only when its marker is in the green.
func _till(g: TillGame) -> void:
	var guard := 0
	while not g.done and guard < 2000:
		g.update(0.05)
		if g._value() >= TillGame.GOOD.x + 0.02 and g._value() <= TillGame.GOOD.y - 0.02 and g._cooldown <= 0.0:
			g.press()
		guard += 1


func test_turnip_loop_till_sow_grow_harvest_sell() -> void:
	var w := _world()
	var player: Player = w.player
	var field: Field = tree.get_first_node_in_group("field")
	var plot := field.plots[0]
	eq(player.wallet.gold, w.START_GOLD, "starting gold")
	check(player.inventory.has(&"hoe"), "starts with a hoe")

	# Till.
	player.select_slot(player.hotbar.find(&"hoe"))
	var g: Minigame = plot.use(player)
	check(g is TillGame, "hoe on sod starts tilling")
	player.start_minigame(g)
	_till(g)
	check(plot.state.is_tilled(), "plot tilled")
	eq(player.minigame, null, "minigame ended")

	# Sow four handfuls at the quarter points.
	player.select_slot(player.hotbar.find(&"turnip_seed"))
	var crop := Items.crop(&"turnip")
	for pt in [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]:
		check(player.inventory.remove(&"turnip_seed", 1))
		plot.state.sow(crop, pt)
	plot.refresh()

	# Five days of watering (as if by bucket) through midnight rollovers.
	for d in 7:
		plot.state.water(0.8)
		Clock.skip_to_hour(6.0)
		if plot.state.is_ripe():
			break
	check(plot.state.is_ripe(), "turnips ripen within a week (growth %.1f)" % plot.state.growth)

	# Harvest every plant by hand (TugGame).
	player.select_slot(0)
	var had := player.inventory.count(&"turnip")
	var pulled := 0
	for c in PlotState.CELLS:
		if plot.state.plants[c] != PlotState.Plant.ALIVE:
			continue
		var tg := TugGame.harvest(plot, c)
		player.start_minigame(tg)
		tg.press()
		var guard := 0
		while not tg.done and guard < 400:
			tg.update(0.05)
			if tg._strain > 0.7:
				tg.release()
			elif not tg._holding:
				tg.press()
			guard += 1
		pulled += 1
	for c in PlotState.CELLS:
		plot.state.pull_plant(c)   # any blighted plants (rain makes blight likelier)
	var turnips := player.inventory.count(&"turnip") - had
	eq(turnips, pulled, "one turnip per plant")
	check(turnips >= 5, "good sowing gives most of a plot (%d)" % turnips)
	eq(plot.state.has_crop(), false, "plot back to stubble")

	# Sell them all.
	var buyer: ProduceBuyer = w.get_node("ProduceBuyer")
	var before := player.wallet.gold
	for row: Dictionary in buyer._rows(player):
		if row.label.contains("urnip"):
			row.buttons[1].action.call()
	check(player.wallet.gold > before, "selling earns gold")
	eq(player.inventory.count(&"turnip"), 0, "all sold")
	_finish(w)


func test_buy_tool_and_draw_water() -> void:
	var w := _world()
	var player: Player = w.player
	check(player.inventory.has(&"bucket"), "starts with a bucket")
	player.wallet.add(20)
	var stall: ToolStall = w.get_node("ToolStall")
	for row: Dictionary in stall._rows(player):
		if row.label.begins_with("Winnowing"):
			row.buttons[0].action.call()
	check(player.inventory.has(&"winnowing_basket"), "bought a basket")
	var well: Well = w.get_node("Well")
	player.select_slot(player.hotbar.find(&"bucket"))
	var g: Minigame = well.use(player)
	check(g is WellGame, "well starts winding")
	player.start_minigame(g)
	g.press()
	# Circle the mouse.
	var a := 0.0
	for k in 400:
		if g.done:
			break
		var d := Vector2(cos(a), sin(a)) * 8.0
		g.mouse_motion(d)
		g.update(0.016)
		a += 0.25
	eq(player.bucket_water(), 1.0, "bucket filled")
	_finish(w)


func test_grain_chain_thresh_winnow_sell() -> void:
	var w := _world()
	var player: Player = w.player
	player.inventory.add(&"flail")
	player.inventory.add(&"winnowing_basket")
	player.inventory.add(&"barley_sheaf", 2, 2)
	var tf: ThreshingFloor = w.get_node("ThreshingFloor")
	tf.interact(player)
	eq(tf.sheaves.size(), 2, "sheaves laid")
	player.select_slot(player.hotbar.find(&"flail"))
	var g: ThreshGame = tf.use(player)
	player.start_minigame(g)
	var guard := 0
	while not g.done and guard < 3000:
		g.update(0.02)
		if g._phase() > 0.97 or g._phase() < 0.03:
			g.press()
		guard += 1
	eq(player.inventory.count(&"barley_chaff", 2), 2, "threshed into unwinnowed barley")

	player.select_slot(player.hotbar.find(&"winnowing_basket"))
	var wg: WinnowGame = tf.use(player)
	player.start_minigame(wg)
	guard = 0
	while not wg.done and guard < 3000:
		tf.wind = 0.9 if (guard / 40) % 2 == 0 else 0.1
		wg.update(0.05)
		if not wg._holding:
			wg.press()
		elif wg._lift >= 1.0 and tf.wind > 0.6:
			wg.release()
		guard += 1
	eq(player.inventory.count(&"barley", 2), 2, "two measures of clean good barley")
	eq(player.inventory.count(&"barley_chaff"), 0, "no chaff left")
	check(Items.sell_value(&"barley", 2) > Items.sell_value(&"barley", 0), "quality pays")
	_finish(w)


func test_sleep_advances_day_and_restores_energy() -> void:
	var w := _world()
	var player: Player = w.player
	player.needs.energy = 20.0
	var day := Clock.day()
	Clock.total_minutes = day * Clock.MINUTES_PER_DAY + 21 * 60
	var hours := Clock.skip_to_hour(6.0)
	player.needs.sleep(hours)
	eq(Clock.day(), day + 1, "next day")
	check(player.needs.energy > 95.0, "rested")
	check(player.needs.hunger < 85.0, "woke hungrier")
	_finish(w)


func test_needs_drain_and_collapse() -> void:
	var n := Needs.new()
	var collapsed := [false]
	n.collapsed.connect(func(_r: String) -> void: collapsed[0] = true)
	n.pass_hours(10.0)
	check(n.hunger < 85.0 and n.energy < 100.0, "needs drain")
	check(n.speed_factor() == 1.0, "not slowed yet")
	n.pass_hours(9.5)
	check(n.speed_factor() < 1.0, "tired slows you")
	n.pass_hours(2.0)
	check(collapsed[0], "collapse when energy runs out")
	n.free()


func test_save_and_load_roundtrip() -> void:
	var w := _world()
	var player: Player = w.player
	var field: Field = tree.get_first_node_in_group("field")
	field.plots[3].state.till(1.0)
	player.wallet.add(17)
	field.place_scarecrow(field.global_position + Vector3(0, 0, 5.4))
	var data := {"clock": Clock.to_dict(), "player": player.to_dict(), "field": field.to_dict()}
	var json: Dictionary = JSON.parse_string(JSON.stringify(data))
	var gold := player.wallet.gold
	_finish(w)
	var w2 := _world()
	var f2: Field = tree.get_first_node_in_group("field")
	w2.player.from_dict(json.player)
	f2.from_dict(json.field)
	eq(w2.player.wallet.gold, gold, "gold restored")
	eq(f2.plots[3].state.till_progress, 1.0, "plot restored")
	eq(f2.scarecrows.size(), 1, "scarecrow restored")
	_finish(w2)


## A sensible new player (buys a bucket, eats when hungry, sleeps at dusk, works ~2h a day)
## must reach the first turnip harvest without collapsing or starving.
func test_first_week_is_survivable() -> void:
	var n := Needs.new()
	var gold := 12
	var bread := 5
	var bread_price := Items.item(&"bread").buy_price
	var collapsed := [false]
	n.collapsed.connect(func(_r: String) -> void: collapsed[0] = true)
	var turnip_harvest_day := 5     # sown day 1, sprouts overnight, ~3 days' growth
	var lowest := 100.0
	for day in turnip_harvest_day:
		for hour in 12:             # 06:00 to 18:00 awake
			n.pass_hours(1.0)
			if hour < 3:
				n.exert(1.5)        # tilling, drawing water, pouring
			if n.hunger < 35.0:
				if bread == 0 and gold >= bread_price:
					gold -= bread_price
					bread += 1
				if bread > 0:
					bread -= 1
					n.eat(Items.item(&"bread").food_value)
			lowest = minf(lowest, n.hunger)
		n.sleep(12.0)
	check(not collapsed[0], "collapsed during the first week")
	check(lowest > 0.0, "starved in the first week (lowest hunger %.0f)" % lowest)
	n.free()


func test_hotbar_is_player_arranged() -> void:
	var w := _world()
	var player: Player = w.player
	eq(player.hotbar.size(), Player.HOTBAR_SIZE)
	eq(player.hotbar[0], Player.HANDS, "slot 1 is hands")
	eq(player.hotbar.slice(1, 4), [&"hoe", &"bucket", &"turnip_seed"], "starting kit auto-filled in order")
	player.inventory.add(&"sickle")
	eq(player.hotbar[4], &"sickle", "new tools go in the first free slot")
	player.assign_slot(1, &"sickle")
	eq(player.hotbar[1], &"sickle", "assigned")
	eq(player.hotbar[4], &"hoe", "swapped with its old slot")
	player.clear_slot(4)
	eq(player.hotbar[4], &"", "cleared")
	player.select_slot(4)
	eq(player.held(), Player.HANDS, "an empty slot means bare hands")
	player.assign_slot(5, &"bread")
	eq(player.hotbar[5], &"", "food can't go on the hotbar")
	# Using up seed keeps the slot (greyed) but leaves your hands empty.
	player.select_slot(3)
	player.inventory.remove(&"turnip_seed", player.inventory.count(&"turnip_seed"))
	eq(player.hotbar[3], &"turnip_seed", "slot kept for when you buy more")
	eq(player.held(), Player.HANDS, "nothing in hand")
	# The layout survives a save.
	var d: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	_finish(w)
	var w2 := _world()
	w2.player.from_dict(d)
	eq(w2.player.hotbar[1], &"sickle", "layout restored")
	eq(w2.player.hotbar[4], &"", "emptied slot stays empty after loading")
	_finish(w2)


func test_next_step_walks_through_the_grain_chain() -> void:
	var w := _world()
	var player: Player = w.player
	var field: Field = w.get_node("Field")
	var tf: ThreshingFloor = w.get_node("ThreshingFloor")
	var s := field.plots[0].state
	while not s.is_tilled():
		s.till(1.0)
	for pt in [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]:
		s.sow(Items.crop(&"barley"), pt)
	s.daily_update(0, false, field.rng)
	s.growth = 99.0
	check(FarmGuide.next_step(player, field, tf).contains("sickle"), "ripe grain → get/use a sickle")
	s.harvest_cell(4)
	check(FarmGuide.next_step(player, field, tf).contains("Bind"), "cut stalks → bind")
	for c in PlotState.CELLS:
		s.harvest_cell(c)
		s.bind_cell(c)
	player.inventory.add(&"barley_sheaf", 2, 1)
	check(FarmGuide.next_step(player, field, tf).contains("threshing floor"), "sheaves → threshing floor")
	player.inventory.remove(&"barley_sheaf", player.inventory.count(&"barley_sheaf", 1), 1)
	for q in [0, 1, 2, 3]:
		player.inventory.remove(&"barley_sheaf", player.inventory.count(&"barley_sheaf", q), q)
	player.inventory.add(&"barley_chaff", 1, 1)
	check(FarmGuide.next_step(player, field, tf).contains("winnowing basket"), "chaff → winnow")
	check(FarmGuide.sections().size() >= 5, "guide has sections")
	_finish(w)


func test_break_new_ground_anywhere() -> void:
	var w := _world()
	var field: Field = w.get_node("Field")
	eq(field.plots.size(), Field.STARTER_COUNT, "a few starter plots")
	var spot := field.snap(Vector3(20.2, 0, -10.1))
	eq(field.placement_error(spot), "", "open grass east of the garden is diggable")
	var p := field.add_plot(spot)
	check(field.placement_error(spot + Vector3(1.0, 0, 0)) != "", "can't overlap a plot")
	check(field.placement_error(field.snap(Vector3(0, 0, FarmLayout.LANE_Z))) != "", "not on the lane")
	p.state.till(1.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(field.to_dict()))
	_finish(w)
	var w2 := _world()
	var f2: Field = w2.get_node("Field")
	f2.from_dict(d)
	eq(f2.plots.size(), Field.STARTER_COUNT + 1, "plots recreated on load")
	var found := false
	for q in f2.plots:
		if q.global_position.distance_to(spot) < 0.01:
			found = q.state.till_progress == 1.0
	check(found, "new plot restored with its state")
	_finish(w2)
