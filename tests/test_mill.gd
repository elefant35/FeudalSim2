extends TestCase
## The windmill: wind, sails, grinding, the meal's quality, the tailpole, the miller, and the
## grain trade between Wynn and the miller.


func _world() -> Node3D:
	var w: Node3D = load("res://world/world.tscn").instantiate()
	tree.root.add_child(w)
	tree.current_scene = w
	return w


func _finish(w: Node3D) -> void:
	Clock.set_wind(0.0, -1.0)
	tree.root.remove_child(w)
	w.free()


## A mill ready to grind: facing a steady fresh breeze, dagger-point sails, stones nicely set.
func _ready_mill(w: Node3D) -> PostMill:
	var mill: PostMill = w.get_node("Windmill")
	Clock.total_minutes = Clock.day() * Clock.MINUTES_PER_DAY + 9 * 60
	Clock.set_wind(PI * 1.5, 0.5)   # from the west
	mill.turn_to(mill.wind_heading())
	mill.cloth = 3
	mill.set_gap(0.2)
	return mill


func test_the_wind_blows_from_somewhere_and_changes() -> void:
	Clock.set_wind(PI / 2, 0.7)
	eq(Clock.compass_name(Clock.wind_from()), "east")
	check(Clock.wind_dir().x < -0.99, "an east wind blows towards the west")
	check(Clock.wind_string().begins_with("A strong breeze"), Clock.wind_string())
	Clock.set_wind(0.0, -1.0)
	var lo := 1.0
	var hi := 0.0
	var start := Clock.total_minutes
	for i in 24 * 24:
		Clock.total_minutes = start + i * 60.0
		lo = minf(lo, Clock.wind_strength())
		hi = maxf(hi, Clock.wind_strength())
	Clock.total_minutes = start
	check(lo < 0.2, "calm spells over a year (lowest %.2f)" % lo)
	check(hi > 0.75, "and blustery ones (highest %.2f)" % hi)


func test_a_mill_grinds_grain_into_flour_you_can_sell() -> void:
	var w := _world()
	var player: Player = w.player
	var mill := _ready_mill(w)
	for k in 2:
		player.pick_up(&"wheat", 2)
	eq(mill.tip_in(player), 2, "two sacks into the hopper")
	eq(player.is_carrying(), false)
	mill.simulate(30.0)
	eq(mill.progress, 0.0, "nothing ground with the brake on")
	mill.set_brake(player, false)
	for i in 60:
		mill.simulate(5.0)
	eq(mill.bin.count(&"wheat_flour"), 2, "both sacks ground")
	eq(mill.bin.count(&"wheat_flour", 2), 2, "fine, cool meal keeps good grain good")
	eq(mill.take_flour(player), 2, "an armful of flour")
	eq(player.carry_id, &"wheat_flour")
	var buyer: ProduceBuyer = w.get_node("ProduceBuyer")
	check(ProduceBuyer.buys(&"wheat_flour"), "the buyer takes flour")
	check(not ProduceBuyer.buys(&"wheat"), "but not raw grain")
	var before := player.wallet.gold
	buyer.sell_everything(player)
	eq(player.wallet.gold - before, Items.sell_value(&"wheat_flour", 2) * 2)
	check(Items.sell_value(&"wheat_flour", 2) > Items.sell_value(&"wheat", 2), "milling adds value")
	_finish(w)


func test_no_grinding_off_the_wind_or_in_a_calm() -> void:
	var w := _world()
	var mill := _ready_mill(w)
	mill.hopper.add(&"barley", 2, 1)
	mill.brake_on = false
	mill.turn_to(mill.wind_heading() + PI / 2)
	mill.simulate(60.0)
	eq(mill.speed, 0.0, "side-on to the wind the sails won't turn")
	mill.turn_to(mill.wind_heading())
	Clock.set_wind(PI * 1.5, 0.05)
	mill.simulate(60.0)
	check(mill.speed < PostMill.GRIND_MIN, "a calm barely stirs them")
	eq(mill.progress, 0.0, "nothing ground")
	Clock.set_wind(PI * 1.5, 0.5)
	mill.simulate(60.0)
	check(mill.progress > 0.0, "a fresh breeze, square on, grinds")
	_finish(w)


func test_the_gap_between_the_stones_matters() -> void:
	var w := _world()
	var mill := _ready_mill(w)
	mill.brake_on = false
	mill.cloth = 4
	Clock.set_wind(PI * 1.5, 0.65)
	mill.simulate(60.0)   # sails up to speed
	mill.set_gap(0.0)
	eq(mill.feel_short(), "hot", "close stones at speed scorch the meal")
	mill.set_gap(1.0)
	eq(mill.feel_short(), "gritty", "wide stones grind coarse")
	eq(PostMill.flour_quality(3, 0.3), 1, "poor meal loses two grades")
	eq(PostMill.flour_quality(3, 0.6), 2, "rough meal loses one")
	eq(PostMill.flour_quality(0, 0.1), 0, "never below poor")
	# There's a setting that's right for this speed... though at this pace, only just.
	var best := 0.0
	for g in 21:
		mill.set_gap(g / 20.0)
		best = maxf(best, mill.meal_score())
	check(best < 0.75, "running this fast, no gap gives the best meal (%.2f): reef in" % best)
	mill.cloth = 2
	mill.simulate(60.0)
	best = 0.0
	for g in 21:
		mill.set_gap(g / 20.0)
		best = maxf(best, mill.meal_score())
	check(best >= 0.75, "at a steady pace the right gap gives fine meal (%.2f)" % best)
	_finish(w)


func test_cloth_only_changes_with_the_sails_stopped() -> void:
	var w := _world()
	var player: Player = w.player
	var mill := _ready_mill(w)
	mill.brake_on = false
	mill.simulate(30.0)
	eq(mill.change_cloth(player, 1), false, "can't touch a turning sail")
	mill.set_brake(player, true)
	mill.simulate(10.0)
	eq(mill.speed, 0.0, "the brake stops them")
	eq(mill.change_cloth(player, 1), true)
	eq(mill.cloth, 4, "full sail")
	eq(mill.change_cloth(player, 1), false, "no more cloth to spread")
	_finish(w)


func test_the_tailpole_walks_the_mill_round() -> void:
	var w := _world()
	var player: Player = w.player
	var mill := _ready_mill(w)
	mill.turn_to(0.0)
	player.global_position = mill.tail_point()
	mill.grab(player)
	eq(player.held(), Player.TAILPOLE)
	# Walk a quarter of the way round; the body follows behind, slowly.
	var target := PI / 2 + PostMill.tail_angle()
	var r := Vector2(PostMill.TAIL_END.x, PostMill.TAIL_END.z).length()
	for i in 200:
		var a := lerpf(PostMill.tail_angle(), target, minf(1.0, i / 120.0))
		player.global_position = mill.global_position + Vector3(sin(a), 0, cos(a)) * r
		mill._physics_process(0.05)
	check(absf(angle_difference(mill.heading, PI / 2)) < 0.1, "the sails came round with you (%.2f)" % mill.heading)
	check(player.global_position.distance_to(mill.tail_point()) <= PostMill.TAIL_SLACK + 0.01, "the tailpole holds you close")
	mill.release(player)
	eq(player.pulling, null)
	_finish(w)


func test_mill_state_saves_and_loads() -> void:
	var w := _world()
	var mill := _ready_mill(w)
	mill.hopper.add(&"wheat", 3, 2)
	mill.brake_on = false
	mill.simulate(40.0)
	var d := mill.to_dict()
	var w2 := _world()
	var mill2: PostMill = w2.get_node("Windmill")
	mill2.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(absf(mill2.heading - mill.heading) < 0.0001, "facing the same way")
	eq(mill2.cloth, 3)
	eq(mill2.brake_on, false)
	eq(mill2.hopper_count(), mill.hopper_count())
	eq(mill2.current.id, mill.current.id)
	check(absf(mill2.progress - mill.progress) < 0.0001, "progress kept")
	var c := Clock.to_dict()
	check(c.has("wind_seed"), "the wind's seed is saved")
	tree.root.remove_child(w2)
	w2.free()
	_finish(w)


func test_you_sell_grain_to_the_miller_but_cant_work_his_mill() -> void:
	var w := _world()
	var player: Player = w.player
	var mill: PostMill = w.get_node("OsricMill")
	var osric: Npc = w.get_node("Osric")
	for k in 3:
		player.pick_up(&"barley", 1)
	var gold := player.wallet.gold
	var his := osric.wallet.gold
	var store := mill.store_count()
	mill.part_interact(&"store", player)
	eq(player.wallet.gold - gold, Items.sell_value(&"barley", 1) * 3, "paid for three sacks")
	eq(his - osric.wallet.gold, Items.sell_value(&"barley", 1) * 3, "out of the miller's own purse")
	eq(mill.store_count(), store + 3)
	var brake := mill.brake_on
	mill.part_interact(&"brake", player)
	eq(mill.brake_on, brake, "his brake isn't yours to pull")
	eq(mill.part_use(&"tenter", player), null)
	_finish(w)


func test_wynn_carts_his_grain_to_the_miller() -> void:
	var w := _world()
	var wynn: Npc = w.get_node("Wynn")
	var mill: PostMill = w.get_node("OsricMill")
	var cart: HandCart = w.get_node("WynnCart")
	wynn.instant = true
	cart.goods.add(&"wheat", 6, 1)
	Clock.total_minutes = Clock.day() * Clock.MINUTES_PER_DAY + 10 * 60
	var trip: Task = wynn.role.next_task()
	check(trip != null and trip.label == "Taking grain to the mill", "off to the mill (%s)" % (trip.label if trip else "nothing"))
	var gold := wynn.wallet.gold
	var store := mill.store_count()
	trip.start(wynn)
	var guard := 0
	while not trip.update(wynn, 0.1) and guard < 50:
		guard += 1
	eq(mill.store_count(), store + 6, "the miller has the grain")
	eq(wynn.wallet.gold - gold, Items.sell_value(&"wheat", 1) * 6, "and Wynn has the money")
	eq(cart.goods.count(&"wheat"), 0)
	eq(cart.is_pulled(), false, "the cart's back and let go")
	_finish(w)


func test_the_miller_works_a_week() -> void:
	var w := _world()
	var osric: Npc = w.get_node("Osric")
	var role: MillerRole = osric.role
	var mill: PostMill = w.get_node("OsricMill")
	var cart: HandCart = w.get_node("OsricCart")
	osric.instant = true
	mill.store.add(&"wheat", 14, 2)
	mill.store.add(&"barley", 8, 1)
	var start_gold := osric.wallet.gold
	var labels := {}
	var ground := [0, 0]   # sacks, total quality
	mill.ground.connect(func(_id: StringName, q: int) -> void:
		ground[0] += 1
		ground[1] += q)
	var night_brake_ok := true
	var winds := [[PI * 1.5, 0.5], [PI, 0.8], [PI * 0.25, 0.3], [PI * 1.5, 0.05], [PI * 1.2, 0.62], [PI * 0.6, 0.45]]
	for day in 6:
		Clock.set_wind(winds[day][0], winds[day][1])
		var guard := 0
		while Clock.hour() < 21.0 and guard < 300:
			guard += 1
			var t: Task = osric._think()
			if t == null:
				Clock.advance(10.0)
				continue
			labels[t.label] = int(labels.get(t.label, 0)) + 1
			t.start(osric)
			var g2 := 0
			while not t.update(osric, 0.1) and g2 < 60:
				g2 += 1
			Clock.advance(10.0)
		if not mill.brake_on:
			night_brake_ok = false
		Clock.skip_to_hour(6.0)
	print("MILLER week: ground %d sacks (avg quality %.1f), gold %d -> %d, cart %d, store %d, labels: %s" % [
		ground[0], float(ground[1]) / maxf(ground[0], 1), start_gold, osric.wallet.gold, cart.count(), mill.store_count(), labels.keys()])
	check(ground[0] >= 8, "ground plenty over the week (%d sacks)" % ground[0])
	check(float(ground[1]) / maxf(ground[0], 1) >= 1.2, "mostly kept the grain's quality")
	check(labels.has("Turning the mill into the wind"), "turned the mill to the wind")
	check(labels.has("Setting the sails"), "set the sails for the wind")
	check(labels.has("Tending the stones"), "tended the stones")
	check(labels.has("Taking flour to market"), "took flour to market")
	check(osric.wallet.gold > start_gold, "made money (%d -> %d)" % [start_gold, osric.wallet.gold])
	check(night_brake_ok, "braked the mill every night")
	_finish(w)
