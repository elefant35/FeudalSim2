class_name FarmGuide
extends RefCounted
## Tells the player what to do next on the farm (the HUD's "Next:" line) and writes the field
## guide (G). Pure reading of game state; it changes nothing.

const CHAFF := [&"barley_chaff", &"wheat_chaff"]
const SHEAVES := [&"barley_sheaf", &"wheat_sheaf"]
const CLEAN := [&"barley", &"wheat"]


static func _count_any(inv: Inventory, ids: Array) -> int:
	var n := 0
	for id: StringName in ids:
		n += inv.count(id)
	return n


## Eating and sleeping come before any work.
static func needs_step(player: Player) -> String:
	if player.needs.hunger < Needs.HUNGRY:
		return "You're hungry. Press F to eat."
	if player.needs.energy < Needs.TIRED:
		return "You're exhausted. Go home and sleep in your bed (E)."
	return ""


## The most useful next step, in the order the work flows.
static func next_step(player: Player, field: Field, floor_: ThreshingFloor, piles: Piles, cart: HandCart) -> String:
	var inv := player.inventory
	var need := needs_step(player)
	if need != "":
		return need

	var cart_goods := 0
	var cart_grain := 0
	if cart:
		for st in cart.goods.stacks():
			if ProduceBuyer.buys(st.id):
				cart_goods += st.count
			elif FarmGuide.CLEAN.has(st.id):
				cart_grain += st.count
	var buyer := player.get_tree().get_first_node_in_group("buyer") as Node3D
	var cart_at_buyer := cart != null and buyer != null and cart.global_position.distance_to(buyer.global_position) < ProduceBuyer.CART_RANGE
	if player.pulling:
		if cart_goods > 0 and not cart_at_buyer:
			return "Pull the handcart to the Produce Bought cart on the lane, and let go (E) beside it."
		if cart_goods > 0:
			return "Let go of the handcart (E), then sell from it at the Produce Buyer (E)."
		return "Pull the handcart where you need it. E lets go."
	if player.is_carrying():
		if FarmGuide.SHEAVES.has(player.carry_id):
			return "Lay your sheaves on the threshing floor (E there), or stack them on the grass (E)."
		if FarmGuide.CLEAN.has(player.carry_id):
			return "Take the grain to a mill: your windmill's hopper, or Osric's grain store. (Or load the handcart first.)"
		return "Set your %s down: in the handcart (E on it), or on the grass as a pile (E)." % player.carry_text()

	var cut := 0
	var ripe_grain: FarmPlot = null
	var ripe_roots: FarmPlot = null
	var dry := 0
	var tilled_empty := 0
	var growing := 0
	for p in field.plots:
		var s := p.state
		cut += s.count_plants(PlotState.Plant.CUT)
		if s.is_ripe():
			if s.crop.harvest == CropData.Harvest.SICKLE:
				ripe_grain = p
			else:
				ripe_roots = p
		if s.has_crop():
			growing += 1
			if s.moisture < PlotState.DRY:
				dry += 1
		elif s.is_tilled():
			tilled_empty += 1
	if cut > 0:
		return "Bind the %d cut bundle%s into sheaves: hands (1), click each one." % [cut, "" if cut == 1 else "s"]
	if floor_.has_sheaves():
		if not inv.has(&"flail"):
			return "Buy a flail at Tools & Seed to thresh the sheaves on the threshing floor."
		return "Thresh: hold the flail at the threshing floor; move the mouse up to raise it, then swing it down hard."
	if floor_.heap_count() > 0:
		if not inv.has(&"winnowing_basket"):
			return "Buy a winnowing basket at Tools & Seed to clean the threshed grain."
		return "Winnow: hold the basket at the threshing floor; release to toss when the pennant gusts."
	var sheaf_piles := 0
	var produce_piles := 0
	var grain_piles := 0
	for pile in piles.all_piles():
		if FarmGuide.SHEAVES.has(pile.id):
			sheaf_piles += 1
		elif FarmGuide.CLEAN.has(pile.id):
			grain_piles += 1
		else:
			produce_piles += 1
	if grain_piles > 0:
		return "Pick up the sacks of clean grain (E) and take them to a mill: yours, or Osric's."
	if sheaf_piles > 0:
		return "Carry the sheaves from your stack to the threshing floor (E to pick up, E at the floor to lay them)."
	if ripe_grain:
		if not inv.has(&"sickle"):
			return "Your %s is ripe. Buy a sickle at Tools & Seed to reap it." % ripe_grain.state.crop.display_name.to_lower()
		return "Your %s is ripe: hold the sickle and sweep across it." % ripe_grain.state.crop.display_name.to_lower()
	if ripe_roots and ripe_roots.state.is_bolted():
		return "Your %ss have gone to seed: pull them to gather seed for next time." % ripe_roots.state.crop.display_name.to_lower()
	if ripe_roots:
		return "Your %s is ripe: pull it by hand (hold left click). It goes into your arms." % ripe_roots.state.crop.display_name.to_lower()
	if produce_piles > 0:
		return "Load your piles into the handcart (E on a pile, then E on the cart)."
	if cart_goods > 0:
		if cart_at_buyer:
			return "Sell from your handcart at the Produce Buyer (E)."
		return "Pull your handcart (E at its handles) to the Produce Bought cart on the lane and sell."
	if cart_grain > 0:
		return "Your handcart has grain in it: pull it to a windmill to grind it, or to Osric's store to sell it."
	if dry > 0:
		return "%d plot%s dry. Fill your bucket at the well and water them." % [dry, " is" if dry == 1 else "s are"]
	if tilled_empty > 0 and not player.seed_kinds().is_empty():
		return "Sow seed on your tilled plot%s (pick your seed on the hotbar)." % ("" if tilled_empty == 1 else "s")
	if player.seed_kinds().is_empty() and tilled_empty > 0:
		return "Buy seed at Tools & Seed. Check the field guide (G) for what grows this season."
	if growing == 0:
		return "Till a plot in the garden with your hoe, or aim the hoe at open grass to break new ground."
	if Clock.hour() >= 18.0:
		return "Your crops are tended. Sleep in your bed to start a new day."
	return "Tend your crops: pull weeds, pick off pests, keep the soil moist. Dig more plots if you like."


static func sections() -> Array:
	var season := Clock.SEASON_NAMES[Clock.season()]
	return [
		["This season: %s" % season, _sowable_now()],
		["The working year",
			"Till → sow → water → tend → harvest → sell. Aim your hoe at open grass to break a new plot anywhere (the green outline shows where it'll go). Each season lasts 6 days. Crops that grow through two seasons (or over winter) pay best."],
		["Carrying the harvest",
			"Produce goes into your arms as you harvest: up to 8 turnips, 4 cabbages, 3 sheaves or 4 sacks of grain. Press E to set it down: in the handcart, on the threshing floor (sheaves), or on the grass as a pile or stack. E on a pile or the cart picks an armful back up. Grab the handcart by its handles (E at the front) to pull it, and park it beside the Produce Buyer to sell straight from it. Barrels (from the stall) hold 24 of anything: fill one with E while carrying, open it with E to take things out or lift it, contents and all, to carry it or stand it in the cart. Your pack holds up to 6 produce for eating."],
		["Root crops: turnips and cabbage",
			"Pull them by hand when ripe (hold left click); they go into your arms. Sell them at the Produce Bought cart, or eat them. Turnips: spring to autumn, ~3 days, survive frost. Cabbage: spring or summer, ~5 days; pick caterpillars off the leaves."],
		["Grain: barley and wheat",
			"1. Reap: hold the sickle over the ripe plot and sweep the mouse across it in steady strokes.\n2. Bind: switch to your hands (1) and click each cut bundle to tie it into a sheaf; sheaves go into your arms (3 at a time). Stack them on the grass (E) or load the handcart.\n3. Thresh: carry sheaves to the threshing floor (north-west of the house) and press E to lay them out, then hold the flail: move the mouse up to raise it and swing it down hard onto the sheaf. The grain stays on the floor with its chaff.\n4. Winnow: hold the winnowing basket at the floor; hold the button to lift, release to toss when the pennant shows a gust. Each clean measure is bagged and set beside the floor.\n5. Pick up the sacks (E) and take them to a mill: grind them in your windmill (see Milling), or sell them to Osric the miller.\nBarley: spring only, ~5 days, killed by frost. Wheat: sow in autumn; it grows slowly over winter and ripens in spring."],
		["Saving seed",
			"You needn't buy seed forever. Turnips and cabbages: leave a ripe one in the ground and after a few days it bolts, sending up a flowering stalk. Pull it then to shake out 2 handfuls of seed (you lose the vegetable). Barley and wheat: the grain is the seed. While carrying a sack of clean grain, open your pack (Tab) and keep it as seed: 6 handfuls."],
		["Keeping crops healthy",
			"Water: keep the soil in the marked band; rain does it for you. Weeds: pull them, easing off before the strain hits red. Blight (brown, spotted plants): pull the sick plant with your hands before it spreads to its neighbours; that's all it takes. Crows: they eat fresh seed; walk up to scare them, or set up a scarecrow. Better care means better quality, and better quality sells for more."],
		["Looking after yourself",
			"Eat with F (or from your pack, Tab). Sleep in your bed after 18:00; the game saves when you sleep. Work yourself to exhaustion and you'll collapse."],
	]


static func _sowable_now() -> String:
	var season := Clock.season()
	var lines: Array[String] = []
	for id: StringName in [&"turnip", &"cabbage", &"barley", &"wheat"]:
		var c := Items.crop(id)
		lines.append("%s: %s" % [c.display_name, "sow now" if c.can_sow_in(season) else "not this season"])
	return "  ·  ".join(lines)
