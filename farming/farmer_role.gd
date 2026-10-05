class_name FarmerRole
extends Role
## Farming as a villager's trade. Reads its own field, threshing floor, handcart and well and
## hands out the next job, in the order a farmer would see to things. Every job goes through the
## same world objects and rules as the player's: where the player's skill shows in a minigame,
## a villager's comes from SKILL with a little luck.

const SKILL := 0.75
## Which crop goes in each bed, by season (spring, summer, autumn, winter).
const PLAN := {
	0: [&"barley", &"barley", &"turnip", &"turnip", &"cabbage", &"cabbage"],
	1: [&"turnip", &"cabbage", &"turnip", &"cabbage", &"turnip", &"cabbage"],
	2: [&"wheat", &"wheat", &"wheat", &"turnip", &"turnip", &"turnip"],
	3: [],
}
const SELL_AT := 10        ## Goods in the cart that make a trip to market worthwhile.
const WATER_TO := 0.9       ## Top the soil up to moist; more than this risks soggy.
const SOW_POINTS: Array[Vector2] = [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]
const CHAFF_TO_CLEAN := {&"barley_chaff": &"barley", &"wheat_chaff": &"wheat"}

var field: Field
var floor_: ThreshingFloor
var cart: HandCart
var well: Well
var water := 0.0            ## How full the bucket is.
var seed_bed := -1          ## A bed left to go to seed (index into field.plots), or -1.
var sold_today := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	title = "farmer"
	rng.randomize()


## A working farmer's kit, seed and a little money.
func stock_up() -> void:
	for id: StringName in [&"hoe", &"bucket", &"sickle", &"flail", &"winnowing_basket"]:
		npc.inventory.add(id)
	npc.inventory.add(&"turnip_seed", 12)
	npc.inventory.add(&"barley_seed", 12)
	npc.inventory.add(&"cabbage_seed", 6)
	npc.inventory.add(&"bread", 4)
	npc.wallet.add(20)


# --- Deciding --------------------------------------------------------------------------------

func next_task() -> Task:
	if npc.pulling:
		return null   # mid-trip; the trip's own steps drive this
	if npc.is_carrying():
		var more := _gather_more_of(npc.carry_id) if npc.carry_space(npc.carry_id) > 0 else null
		return more if more else _deliver()
	for step: Callable in [_shoo, _bind, _harvest, _reap, _thresh, _winnow, _fetch_piles, _market, _tend, _water, _sow, _till]:
		var t: Task = step.call()
		if t:
			return t
	return null


## Crows at the seed: hurry over waving and shouting. (They flee from anyone who comes close.)
func _shoo() -> Task:
	var crows := field.pecking_crows()
	if crows.is_empty():
		return null
	var crow := crows[0]
	return _job("Shooing crows", crow.global_position, &"shoo", 1.2, func() -> void:
		if is_instance_valid(crow) and crow.state == Crow.State.PECKING:
			crow.flee()
		npc.say("Go on, get off it!"), &"", 3.5)


## With room in the arms, keep picking the same thing before carrying it off.
func _gather_more_of(id: StringName) -> Task:
	if FarmGuide.SHEAVES.has(id):
		return _bind()
	var it := Items.item(id)
	if it and it.kind == ItemData.Kind.PRODUCE:
		return _harvest(id)
	return null


func _job(what: String, where: Vector3, anim: StringName, seconds: float, done: Callable, tool: StringName = &"", near: float = 1.0) -> Task:
	var steps: Array[Task] = [GoTo.new(where, near, what), Work.new(what, anim, seconds, done, tool, where)]
	return Sequence.new(what, steps)


func _deliver() -> Task:
	var id := npc.carry_id
	if FarmGuide.SHEAVES.has(id):
		if floor_.sheaves.size() < ThreshingFloor.CAPACITY:
			return _job("Laying out the sheaves", floor_.global_position, &"crouch", 1.5,
				func() -> void: floor_.lay_sheaves(npc), &"", 2.2)
		# Floor full: stack them beside it, ready for when there's room (never in the cart).
		return _job("Stacking sheaves by the floor", _sheaf_stack_spot(), &"crouch", 1.0,
			func() -> void: npc.set_down_at(_sheaf_stack_spot()), &"", 1.0)
	return _job("Loading the cart", cart.global_position, &"crouch", 1.2, func() -> void:
		if npc.is_carrying() and npc.carry_id != &"barrel":
			cart.load_from(npc)
		if npc.is_carrying():   # cart full: leave it in a pile beside the cart
			npc.set_down_at(cart.global_position + Vector3(1.6, 0, 0)), &"", 2.0)


func _bind() -> Task:
	for p in field.plots:
		for c in PlotState.CELLS:
			if p.state.plants[c] == PlotState.Plant.CUT:
				return _job("Binding sheaves", p.cell_world(c), &"crouch", 1.0, func() -> void: p.bind(npc, c))
	return null


## Root crops: pull the ripe ones (or gather seed from a bed left to bolt).
func _harvest(only: StringName = &"") -> Task:
	for i in field.plots.size():
		var p := field.plots[i]
		var s := p.state
		if not s.is_ripe() or s.crop.harvest != CropData.Harvest.HANDS:
			continue
		if only != &"" and (s.is_bolted() or s.crop.product_item != only):
			continue
		if not s.is_bolted():
			# Seed running low? Leave this bed in the ground to go to seed.
			if seed_bed == -1 and npc.inventory.count(s.crop.seed_item) < 6:
				seed_bed = i
				npc.say("I'll let this %s bed go to seed." % s.crop.display_name.to_lower())
			if seed_bed == i:
				continue
		for c in PlotState.CELLS:
			if s.plants[c] == PlotState.Plant.ALIVE:
				var what := "Gathering %s seed" % s.crop.display_name.to_lower() if s.is_bolted() else "Pulling %ss" % s.crop.display_name.to_lower()
				return _job(what, p.cell_world(c), &"crouch", 1.2, func() -> void:
					p.harvest_by_hand(npc, c)
					if seed_bed == i and not p.state.has_crop():
						seed_bed = -1)
	return null


func _reap() -> Task:
	if not npc.inventory.has(&"sickle"):
		return null
	for p in field.plots:
		var s := p.state
		if s.is_ripe() and s.crop.harvest == CropData.Harvest.SICKLE and s.count_plants(PlotState.Plant.ALIVE) > 0:
			return _job("Reaping the %s" % s.crop.display_name.to_lower(), p.global_position, &"reap", 5.0, func() -> void:
				for c in PlotState.CELLS:
					p.state.harvest_cell(c)
				p.refresh(), &"sickle", 1.6)
	return null


func _thresh() -> Task:
	if not floor_.has_sheaves() or not npc.inventory.has(&"flail"):
		return null
	return _job("Threshing", floor_.global_position, &"flail", 4.0, func() -> void:
		var before := floor_.sheaves.size()
		while floor_.has_sheaves() and floor_.sheaves.size() == before:
			floor_.beat(clampf(SKILL + rng.randf_range(-0.2, 0.2), 0.2, 1.0) / ThreshGame.BLOWS_PER_SHEAF, npc), &"flail", 2.2)


func _winnow() -> Task:
	if floor_.heap_count() == 0 or not npc.inventory.has(&"winnowing_basket"):
		return null
	return _job("Winnowing", floor_.global_position, &"winnow", 3.5, func() -> void:
		var m := floor_.take_from_heap()
		if not m.is_empty():
			floor_.add_clean(CHAFF_TO_CLEAN[m.id], m.quality), &"winnowing_basket", 2.2)


func _sheaf_stack_spot() -> Vector3:
	return floor_.global_position + Vector3(3.4, 0, 1.5)


## Sacks of clean grain by the floor, or anything left in a pile near the farm: into the cart.
## Stacked sheaves go back onto the floor once it has room.
func _fetch_piles() -> Task:
	var piles: Piles = npc.get_tree().get_first_node_in_group("piles")
	var floor_room := floor_.sheaves.size() < ThreshingFloor.CAPACITY
	for pile in piles.all_piles():
		if FarmGuide.SHEAVES.has(pile.id):
			if floor_room and pile.global_position.distance_to(floor_.global_position) < 6.0:
				return _job("Fetching sheaves for the floor", pile.global_position, &"crouch", 0.8,
					func() -> void:
						if is_instance_valid(pile):
							pile.take_armful(npc), &"", 1.2)
			continue
		if cart.room() <= 0:
			continue
		var near_floor := pile.global_position.distance_to(floor_.global_position) < 6.0
		var near_cart := pile.global_position.distance_to(cart.global_position) < 4.0
		if near_floor or near_cart:
			return _job("Fetching the %s" % Items.name_of(pile.id).to_lower(), pile.global_position, &"crouch", 0.8,
				func() -> void:
					if is_instance_valid(pile):
						pile.take_armful(npc), &"", 1.2)
	return null


func _sellable_in_cart() -> int:
	var n := 0
	for st in cart.goods.stacks():
		if Items.sell_value(st.id, st.quality) > 0:
			n += st.count
	return n


## A trip to market: pull the cart to the buyer, sell, shop at the stall, bring the cart home.
func _market() -> Task:
	var h := Clock.hour()
	var goods := _sellable_in_cart()
	if h < 8.0 or h > 16.0 or goods == 0 or cart.is_pulled():
		return null
	if goods < SELL_AT and not (h > 14.0 and goods >= 4):
		return null
	var buyer: ProduceBuyer = npc.get_tree().get_first_node_in_group("buyer")
	var home_spot := FarmLayout.NB_CART
	var steps: Array[Task] = [
		GoTo.new(cart.handle_point(), 0.6, "Fetching the handcart"),
		DoNow.new("", func() -> void: cart.grab(npc)),
		GoTo.new(buyer.global_position + Vector3(4.5, 0, 2.6), 1.2, "Taking the harvest to market"),
		DoNow.new("", func() -> void: cart.release(npc)),
		Work.new("Selling", &"idle", 2.0, func() -> void:
			var earned := buyer.sell_everything(npc)
			sold_today += earned
			npc.say("That's %d gold for my trouble." % earned)
			_shop()),
		_ToCart.new(cart),   # back round to the handles, wherever the cart ended up
		DoNow.new("", func() -> void: cart.grab(npc)),
		# Coming up from the lane, the cart trails behind (south), so stop a shaft short of its spot.
		GoTo.new(home_spot - Vector3(0, 0, HandCart.SHAFT), 1.0, "Bringing the cart home"),
		DoNow.new("", func() -> void: cart.release(npc)),
	]
	return Sequence.new("Going to market", steps)


## Buys what's needed while at the stall: seed for the beds, and bread if the larder's bare.
func _shop() -> void:
	var stall: ToolStall = npc.get_tree().get_first_node_in_group("stall")
	if stall == null:
		return
	var season := Clock.season()
	for next_season: int in [season, (season + 1) % 4]:
		for crop_id: StringName in PLAN[next_season]:
			var c := Items.crop(crop_id)
			var seed := Items.item(c.seed_item)
			var need := 8
			while npc.inventory.count(c.seed_item) < need and npc.wallet.gold >= seed.buy_price + 4:
				stall._buy(npc, seed)
	while npc.inventory.count(&"bread") < 3 and npc.wallet.can_afford(Items.item(&"bread").buy_price):
		stall._buy(npc, Items.item(&"bread"))


func _tend() -> Task:
	for p in field.plots:
		var s := p.state
		if not s.has_crop():
			continue
		for c in PlotState.CELLS:
			if s.plants[c] == PlotState.Plant.BLIGHTED:
				return _job("Pulling a blighted plant", p.cell_world(c), &"crouch", 1.2, func() -> void:
					p.state.pull_plant(c)
					p.refresh())
			if s.caterpillars[c] > 0:
				return _job("Picking off caterpillars", p.cell_world(c), &"crouch", 1.2, func() -> void:
					while p.state.pick_caterpillar(c):
						pass
					p.refresh())
		if not s.weeds.is_empty():
			return _job("Weeding", p.to_world(s.weeds[0]), &"crouch", 1.5, func() -> void:
				p.state.remove_weed(0, rng.randf() > SKILL)
				p.refresh())
	return null


func _water() -> Task:
	if Clock.raining or not npc.inventory.has(&"bucket"):
		return null
	for p in field.plots:
		# Water what will be dry by tomorrow, and only up to moist (never soggy).
		if p.state.has_crop() and p.state.dry_by_tomorrow(Clock.season()):
			if water <= 0.0:
				return _job("Drawing water", well.global_position, &"crank", 4.0,
					func() -> void: water = 1.0, &"", 1.7)
			return _job("Watering", p.global_position, &"pour", 2.5, func() -> void:
				var amount := clampf(WATER_TO - p.state.moisture, 0.0, water / PourGame.BUCKET_PER_MOISTURE)
				p.state.water(amount)
				water = maxf(0.0, water - amount * PourGame.BUCKET_PER_MOISTURE)
				p.refresh(), &"bucket", 1.6)
	return null


func _crop_for(i: int) -> CropData:
	var plan: Array = PLAN[Clock.season()]
	if plan.is_empty():
		return null
	return Items.crop(plan[i % plan.size()])


func _sow() -> Task:
	for i in field.plots.size():
		var p := field.plots[i]
		if not p.state.is_tilled() or p.state.has_crop():
			continue
		var c := _crop_for(i)
		if c == null or p.state.sow_error(c, Clock.season()) != "":
			continue
		if npc.inventory.count(c.seed_item) < SOW_POINTS.size():
			var trip := _seed_trip(c)
			if trip:
				return trip
			continue
		var sigma := 0.04 + (1.0 - SKILL) * 0.1
		return _job("Sowing %s" % c.display_name.to_lower(), p.global_position, &"sow", 3.0, func() -> void:
			for pt in SOW_POINTS:
				if npc.inventory.remove(c.seed_item, 1):
					p.state.sow(c, pt + Vector2(rng.randfn(0.0, sigma), rng.randfn(0.0, sigma)))
			p.refresh(), &"seed_pouch", 1.4)
	return null


## Out of seed for a bed: walk to the stall and buy some, if there's money for it.
func _seed_trip(c: CropData) -> Task:
	var stall: ToolStall = npc.get_tree().get_first_node_in_group("stall")
	var price := Items.item(c.seed_item).buy_price
	var h := Clock.hour()
	if stall == null or npc.wallet.gold < price + 2 or h < 7.0 or h > 17.0:
		return null
	return _job("Off to buy %s seed" % c.display_name.to_lower(), stall.global_position + Vector3(0, 0, -2.2), &"idle", 1.0,
		func() -> void:
			_shop()
			npc.say("Seed for the beds, and that's my coin gone." if npc.wallet.gold < 5 else "That'll do for seed."), &"", 1.5)


func _till() -> Task:
	for i in field.plots.size():
		var p := field.plots[i]
		if p.state.has_crop() or p.state.is_tilled() or _crop_for(i) == null:
			continue
		return _job("Tilling", p.global_position, &"hoe", 4.0, func() -> void:
			while not p.state.is_tilled():
				p.state.till(clampf(rng.randf_range(SKILL - 0.25, SKILL + 0.25), 0.2, 1.0))
			p.refresh(), &"hoe", 1.4)
	return null


# --- Food, talk, save ------------------------------------------------------------------------

func fetch_food() -> Task:
	for id: StringName in [&"turnip", &"cabbage"]:
		if cart.goods.has(id):
			return _job("Fetching something to eat", cart.global_position, &"crouch", 0.8, func() -> void:
				var q := cart.goods.take_one(id)
				if q > -2:
					npc.inventory.add(id, 1, q), &"", 2.0)
	var stall: ToolStall = npc.get_tree().get_first_node_in_group("stall")
	if stall and npc.wallet.can_afford(Items.item(&"bread").buy_price):
		return _job("Buying bread", stall.global_position + Vector3(0, 0, -2.2), &"idle", 1.0, func() -> void:
			while npc.inventory.count(&"bread") < 3 and npc.wallet.can_afford(Items.item(&"bread").buy_price):
				stall._buy(npc, Items.item(&"bread")), &"", 1.5)
	return null


func chat_line() -> String:
	var season := Clock.SEASON_NAMES[Clock.season()].to_lower()
	var doing := npc.activity().to_lower()
	var lines: Array[String] = []
	if doing != "":
		lines.append("Can't stop long, I'm %s." % doing)
	if sold_today > 0:
		lines.append("Took %d gold at market today. Not bad." % sold_today)
	if seed_bed >= 0:
		lines.append("I've left a bed to go to seed. Saves buying it.")
	if Clock.raining:
		lines.append("Rain does my watering for me today.")
	match Clock.season():
		0: lines.append("Barley in early, that's the trick in %s." % season)
		1: lines.append("Turnips and cabbages through the summer. Keep the water on them.")
		2: lines.append("Wheat goes in now. It'll sit through the winter.")
		3: lines.append("Not much to do in winter but mend and wait.")
	return lines[rng.randi() % lines.size()]


func on_day_started() -> void:
	sold_today = 0


func to_dict() -> Dictionary:
	return {"water": water, "seed_bed": seed_bed}


func from_dict(d: Dictionary) -> void:
	water = float(d.get("water", 0.0))
	seed_bed = int(d.get("seed_bed", -1))


## Walk to wherever the cart's handles are now (they move when the cart is parked).
class _ToCart extends GoTo:
	var _cart: HandCart

	func _init(c: HandCart) -> void:
		super(Vector3.ZERO, 0.6, "Going back for the cart")
		_cart = c

	func start(npc: Npc) -> void:
		target = _cart.handle_point()
		super(npc)
