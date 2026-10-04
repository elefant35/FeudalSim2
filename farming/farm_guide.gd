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


## The most useful next step, in the order the work flows.
static func next_step(player: Player, field: Field, floor_: ThreshingFloor) -> String:
	var inv := player.inventory
	if player.needs.hunger < Needs.HUNGRY:
		return "You're hungry. Press F to eat."
	if player.needs.energy < Needs.TIRED:
		return "You're exhausted. Go home and sleep in your bed (E)."

	# Grain, from field to market.
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
	if _count_any(inv, SHEAVES) > 0:
		return "Take your sheaves to the threshing floor (north-west of the house) and press E to lay them out."
	if floor_.has_sheaves():
		if not inv.has(&"flail"):
			return "Buy a flail at Tools & Seed to thresh the sheaves on the threshing floor."
		return "Thresh: hold the flail at the threshing floor and click as the ring closes."
	if _count_any(inv, CHAFF) > 0:
		if not inv.has(&"winnowing_basket"):
			return "Buy a winnowing basket at Tools & Seed to clean your threshed grain."
		return "Winnow: hold the basket at the threshing floor; release to toss when the pennant gusts."
	if ripe_grain:
		if not inv.has(&"sickle"):
			return "Your %s is ripe. Buy a sickle at Tools & Seed to reap it." % ripe_grain.state.crop.display_name.to_lower()
		return "Your %s is ripe: hold the sickle and sweep across it." % ripe_grain.state.crop.display_name.to_lower()
	if ripe_roots:
		return "Your %s is ripe: pull it by hand (hold left click)." % ripe_roots.state.crop.display_name.to_lower()
	var to_sell := 0
	for s in inv.stacks():
		if Items.sell_value(s.id, s.quality) > 0 and Items.item(s.id).kind != ItemData.Kind.FOOD:
			to_sell += s.count
	if _count_any(inv, CLEAN) > 0 or to_sell >= 6:
		return "Sell your produce and grain at the Produce Bought cart down the lane."
	if dry > 0:
		return "%d plot%s dry. Fill your bucket at the well and water them." % [dry, " is" if dry == 1 else "s are"]
	if tilled_empty > 0 and not player.seed_kinds().is_empty():
		return "Sow seed on your tilled plot%s (choose your seed in the hotbar)." % ("" if tilled_empty == 1 else "s")
	if player.seed_kinds().is_empty() and tilled_empty > 0:
		return "Buy seed at Tools & Seed. Check the field guide (G) for what grows this season."
	if growing == 0:
		return "Till a plot with your hoe."
	if Clock.hour() >= 18.0:
		return "Your crops are tended. Sleep in your bed to start a new day."
	return "Tend your crops: pull weeds, pick off pests, keep the soil moist. Till more plots if you like."


static func sections() -> Array:
	var season := Clock.SEASON_NAMES[Clock.season()]
	return [
		["This season: %s" % season, _sowable_now()],
		["The working year",
			"Till → sow → water → tend → harvest → sell. Each season lasts 6 days. Crops that grow through two seasons (or over winter) pay best."],
		["Root crops: turnips and cabbage",
			"Pull them by hand when ripe (hold left click), then sell them at the Produce Bought cart or eat them. Turnips: spring to autumn, ~3 days, survive frost. Cabbage: spring or summer, ~5 days; pick caterpillars off the leaves."],
		["Grain: barley and wheat",
			"1. Reap: hold the sickle over the ripe plot and sweep the mouse across it in steady strokes.\n2. Bind: switch to your hands (1) and click each cut bundle to tie it into a sheaf.\n3. Thresh: at the threshing floor (north-west of the house) press E to lay the sheaves out, then hold the flail and click as the ring closes.\n4. Winnow: hold the winnowing basket there; hold the button to lift, release to toss when the pennant shows a gust. The chaff blows away.\n5. Sell the clean grain at the Produce Bought cart.\nBarley: spring only, ~5 days, killed by frost. Wheat: sow in autumn; it grows slowly over winter and ripens in spring."],
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
