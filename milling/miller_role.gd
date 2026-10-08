class_name MillerRole
extends Role
## Milling as a villager's trade. The miller buys grain at his store (farmers bring it), and
## works his windmill by the same rules as the player: walks the tailpole round to face the
## wind, brakes to set the cloth for the wind's strength, carries sacks up to the hopper, lets
## the sails go, and tends the stones by feeling the meal at the spout. Flour goes down to his
## handcart and off to the buyer. His judgement of the wind and the meal comes from SKILL.

const SKILL := 0.75
const SELL_AT := 8              ## Sacks of flour in the cart that make a trip worthwhile.
const WORK_FROM := 6.0          ## Hours he'll work the mill.
const WORK_TO := 19.5
const MIN_WIND := 0.16          ## Below this there's no point setting the sails.
const OFF_WIND := deg_to_rad(18.0)   ## Off the wind by more than this: walk her round.
## Sail speeds he's happy grinding at. Much faster than 0.6 and no gap between the stones keeps
## the meal both fine and cool, so a good miller reefs in.
const SPEED_BAND := Vector2(0.32, 0.6)
const TEND_EVERY := 40.0        ## Game minutes between feeling the meal when it's right.

var mill: PostMill
var cart: HandCart
var sold_today := 0
var ground_today := 0
var _tended_at := -1000.0
var _last_reading := ""
var rng := RandomNumberGenerator.new()


func _init() -> void:
	title = "miller"
	rng.randomize()


## A miller's start: money to buy grain, bread, and a few sacks already in the store.
func stock_up() -> void:
	npc.wallet.add(60)
	npc.inventory.add(&"bread", 4)
	mill.store.add(&"wheat", 4, 1)
	mill.store.add(&"barley", 2, 1)
	mill.ground.connect(func(_id: StringName, _q: int) -> void: ground_today += 1)


# --- Deciding --------------------------------------------------------------------------------

func next_task() -> Task:
	if npc.pulling:
		return null   # mid-trip or on the tailpole: that task drives
	if npc.is_carrying():
		return _deliver()
	for step: Callable in [_close_up, _sell_trip, _empty_bin, _luff, _set_sails, _fetch_grain, _start, _tend, _stop, _watch]:
		var t: Task = step.call()
		if t:
			return t
	return null


func _working_hours() -> bool:
	var h := Clock.hour()
	return h >= WORK_FROM and h < WORK_TO


func _grain_to_mill() -> int:
	return mill.hopper_count() + mill.store_count() + (0 if mill.current.is_empty() else 1)


func wants_to_mill() -> bool:
	return _working_hours() and Clock.wind_strength() >= MIN_WIND and _grain_to_mill() > 0 and mill.bin_count() < PostMill.BIN_MAX


## The cloth he'd set for the wind as he judges it: whatever brings the sails nearest a steady pace.
func cloth_for_wind() -> int:
	var felt := Clock.wind_strength() + rng.randfn(0.0, (1.0 - SKILL) * 0.12)
	var best := 0
	for i in PostMill.CLOTH_AREA.size():
		if absf(felt * PostMill.CLOTH_AREA[i] * PostMill.POWER * 0.88 - 0.5) < absf(felt * PostMill.CLOTH_AREA[best] * PostMill.POWER * 0.88 - 0.5):
			best = i
	return best


## How fast he reckons the sails would turn on cloth `c` (grinding takes a little off).
func _expected_speed(c: int) -> float:
	return Clock.wind_strength() * PostMill.CLOTH_AREA[c] * PostMill.POWER * 0.88


## Carrying something: grain goes up to the hopper, flour down to the cart.
func _deliver() -> Task:
	var it := Items.item(npc.carry_id)
	if it and it.mills_to != &"" and mill.hopper_count() < PostMill.HOPPER_MAX:
		return _inside(&"hopper", "Carrying grain up to the hopper", &"pour", 1.5, func() -> void: mill.tip_in(npc))
	if it and it.kind == ItemData.Kind.FLOUR:
		return _outside("Loading flour into the cart", cart.global_position, &"crouch", 1.2, func() -> void:
			cart.load_from(npc)
			if npc.is_carrying():
				npc.set_down_at(cart.global_position + Vector3(1.6, 0, 0)), 1.6)
	# Grain with the hopper full: back to the store.
	return _outside("Putting the sacks back", _store_spot(), &"crouch", 1.0, func() -> void:
		var id := npc.carry_id
		for q in npc.take_carry():
			mill.store.add(id, 1, q), 1.2)


## End of the day: brake the mill before going home.
func _close_up() -> Task:
	if _working_hours() or mill.brake_on:
		return null
	return _inside(&"brake", "Braking the mill for the night", &"crank", 1.2, func() -> void: mill.set_brake(npc, true))


func _flour_in_cart() -> int:
	var n := 0
	for st in cart.goods.stacks():
		if Items.item(st.id).kind == ItemData.Kind.FLOUR:
			n += st.count
	return n


## Enough flour in the cart: off to the buyer with it (stopping the mill first).
func _sell_trip() -> Task:
	var h := Clock.hour()
	var sacks := _flour_in_cart()
	if h < 8.0 or h > 16.5 or sacks == 0 or cart.is_pulled():
		return null
	if sacks < SELL_AT and not (h > 15.0 and sacks >= 3):
		return null
	if not mill.brake_on:
		return _inside(&"brake", "Stopping the mill to go to market", &"crank", 1.2, func() -> void: mill.set_brake(npc, true))
	var buyer: ProduceBuyer = npc.get_tree().get_first_node_in_group("buyer")
	var sell := Work.new("Selling flour", &"idle", 2.0, func() -> void:
		var earned := buyer.sell_everything(npc)
		sold_today += earned
		npc.say("%d gold for the flour." % earned)
		_buy_bread())
	var steps: Array[Task] = _climb_down()
	steps.append(CartTrip.make("Taking flour to market", npc, cart, buyer.global_position + Vector3(4.5, 0, 2.6), sell, FarmLayout.MILLER_CART))
	return Sequence.new("Taking flour to market", steps)


## Flour piling up in the bin: carry an armful down to the cart.
func _empty_bin() -> Task:
	var n := mill.bin_count()
	if n == 0 or cart.room() <= 0:
		return null
	if n < 4 and mill.is_grinding() and n < PostMill.BIN_MAX:
		return null
	return _inside(&"bin", "Bagging the flour", &"crouch", 1.2, func() -> void: mill.take_flour(npc))


## The sails are off the wind: down to the tailpole and walk her round.
func _luff() -> Task:
	if not wants_to_mill() or mill.off_wind() < OFF_WIND:
		return null
	var steps: Array[Task] = _climb_down()
	steps.append(GoTo.new(mill.tail_point(), 0.6, "Going to the tailpole"))
	steps.append(LuffTask.new(mill))
	return Sequence.new("Turning the mill into the wind", steps)


## The cloth is wrong for the wind: brake, wait for the sails to stop, reef or spread, done.
func _set_sails() -> Task:
	if not wants_to_mill():
		return null
	var speed := _expected_speed(mill.cloth)
	if speed >= SPEED_BAND.x and speed <= SPEED_BAND.y:
		return null
	var want := cloth_for_wind()
	if want == mill.cloth:
		return null
	var steps: Array[Task] = []
	if not mill.brake_on:
		steps.append_array(_route_in(&"brake"))
		steps.append(Work.new("Braking to set the sails", &"crank", 1.2, func() -> void: mill.set_brake(npc, true), &"", mill.body.to_global(PostMill.SPOTS[&"brake"][1])))
	steps.append_array(_climb_down())
	var at_sails := mill.body.to_global(PostMill.HUB * Vector3(1, 0, 1) + Vector3(0.9, 0, -1.4))
	steps.append(GoTo.new(at_sails, 0.6, "Going out to the sails"))
	steps.append(WaitUntil.new("Waiting for the sails to stop", func() -> bool: return mill.speed <= 0.04, &"idle", 90.0))
	steps.append(Work.new("Setting the cloth to %s" % PostMill.CLOTH_NAMES[want], &"reap", 3.0, func() -> void:
		while mill.cloth != want and mill.change_cloth(npc, signi(want - mill.cloth)):
			pass, &"", mill.body.to_global(PostMill.HUB)))
	return Sequence.new("Setting the sails", steps)


## Room in the hopper and grain in the store: carry up an armful.
func _fetch_grain() -> Task:
	if mill.store_count() == 0 or mill.hopper_count() >= PostMill.HOPPER_MAX or not _working_hours():
		return null
	if mill.hopper_count() >= 2 and not mill.current.is_empty():
		return null   # plenty to be going on with
	return _outside("Fetching grain from the store", _store_spot(), &"crouch", 1.0, func() -> void: mill.take_from_store(npc, PostMill.HOPPER_MAX - mill.hopper_count()), 1.2)


## All set: let the brake off.
func _start() -> Task:
	if not mill.brake_on or not wants_to_mill() or mill.off_wind() >= OFF_WIND:
		return null
	if mill.hopper_count() == 0 and mill.current.is_empty():
		return null
	var speed := _expected_speed(mill.cloth)
	if speed < SPEED_BAND.x * 0.8 or speed > SPEED_BAND.y * 1.15:
		return null   # the sails want setting first (or the wind's too light to bother)
	return _inside(&"brake", "Letting the sails go", &"crank", 1.2, func() -> void:
		mill.set_brake(npc, false)
		npc.say("There she goes."))


## Grinding: feel the meal at the spout now and then, and move the stones the way it says.
func _tend() -> Task:
	if not mill.is_grinding():
		return null
	var since := Clock.total_minutes - _tended_at
	if since < 6.0 or (since < TEND_EVERY and _last_reading == "just right"):
		return null
	var steps: Array[Task] = _route_in(&"spout")
	steps.append(Work.new("Feeling the meal", &"crouch", 1.0, func() -> void:
		_last_reading = mill.feel_short()
		_tended_at = Clock.total_minutes, &"", mill.body.to_global(PostMill.SPOTS[&"spout"][1])))
	steps.append(_OnlyIf.new(func() -> bool: return _last_reading != "just right",
		_steps_to(&"tenter", Work.new("Setting the stones", &"crank", 1.2, func() -> void:
			var step := 0.1 if _last_reading in ["hot", "gritty"] else 0.05
			step *= 1.0 + rng.randf_range(-(1.0 - SKILL), 1.0 - SKILL)
			mill.set_gap(mill.gap + (step if _last_reading in ["hot", "warm", "dusty"] else -step)), &"", mill.body.to_global(PostMill.SPOTS[&"tenter"][1])))))
	return Sequence.new("Tending the stones", steps)


## Nothing left to grind: brake rather than let the stones run dry.
func _stop() -> Task:
	if mill.brake_on:
		return null
	if mill.hopper_count() > 0 or not mill.current.is_empty():
		if Clock.wind_strength() >= MIN_WIND * 0.7:
			return null
	return _inside(&"brake", "Stopping the mill", &"crank", 1.2, func() -> void: mill.set_brake(npc, true))


## The mill's running and all's well: stay up by the stones and keep an ear on them.
func _watch() -> Task:
	if mill.brake_on:
		return null
	return _inside(&"hopper", "Minding the mill", &"idle", 15.0, Callable())


# --- Getting about the mill -------------------------------------------------------------------

## Is he up in the mill's body?
func is_inside() -> bool:
	var p := mill.body.to_local(npc.global_position)
	return p.y > PostMill.FLOOR_Y - 0.6 and absf(p.x) < PostMill.HALF.x + 0.3 and absf(p.z) < PostMill.HALF.y + 0.3


## Up the steps (if he isn't already inside) and over to a part.
func _route_in(part: StringName) -> Array[Task]:
	var steps: Array[Task] = []
	if not is_inside():
		steps.append(GoTo.new(mill.body.to_global(PostMill.STEPS_FOOT), 0.6, "Climbing up into the mill"))
		steps.append(GoTo.new(mill.body.to_global(PostMill.DOOR), 0.35, "Climbing up into the mill", true))
	steps.append(GoTo.new(mill.body.to_global(PostMill.AISLE), 0.35, "", true))
	steps.append(GoTo.new(mill.body.to_global(PostMill.SPOTS[part][0]), 0.3, "", true))
	return steps


## Down the steps, if he's up in the mill.
func _climb_down() -> Array[Task]:
	var steps: Array[Task] = []
	if is_inside():
		steps.append(GoTo.new(mill.body.to_global(PostMill.AISLE), 0.35, "Climbing down", true))
		steps.append(GoTo.new(mill.body.to_global(PostMill.DOOR), 0.35, "Climbing down", true))
		steps.append(GoTo.new(mill.body.to_global(PostMill.STEPS_FOOT + Vector3(0, 0, 0.6)), 0.5, "Climbing down", true))
	return steps


func _steps_to(part: StringName, work: Task) -> Sequence:
	var steps: Array[Task] = [GoTo.new(mill.body.to_global(PostMill.AISLE), 0.35, "", true),
		GoTo.new(mill.body.to_global(PostMill.SPOTS[part][0]), 0.3, "", true), work]
	return Sequence.new(work.label, steps)


func _inside(part: StringName, what: String, anim: StringName, seconds: float, done: Callable) -> Task:
	var steps: Array[Task] = _route_in(part)
	steps.append(Work.new(what, anim, seconds, done, &"", mill.body.to_global(PostMill.SPOTS[part][1])))
	return Sequence.new(what, steps)


func _outside(what: String, where: Vector3, anim: StringName, seconds: float, done: Callable, near: float = 1.0) -> Task:
	var steps: Array[Task] = _climb_down()
	steps.append(GoTo.new(where, near, what))
	steps.append(Work.new(what, anim, seconds, done, &"", where))
	return Sequence.new(what, steps)


func _store_spot() -> Vector3:
	return mill.to_global(PostMill.STORE_AT + Vector3(-1.3, 0, 0))


# --- Food, talk, save ------------------------------------------------------------------------

func _buy_bread() -> void:
	var stall: ToolStall = npc.get_tree().get_first_node_in_group("stall")
	if stall == null:
		return
	while npc.inventory.count(&"bread") < 4 and npc.wallet.gold >= Items.item(&"bread").buy_price + 30:
		stall._buy(npc, Items.item(&"bread"))


func fetch_food() -> Task:
	var stall: ToolStall = npc.get_tree().get_first_node_in_group("stall")
	if stall == null or not npc.wallet.can_afford(Items.item(&"bread").buy_price):
		return null
	var steps: Array[Task] = _climb_down()
	steps.append(GoTo.new(stall.global_position + Vector3(0, 0, -2.2), 1.0, "Buying bread"))
	steps.append(Work.new("Buying bread", &"idle", 1.5, func() -> void:
		while npc.inventory.count(&"bread") < 3 and npc.wallet.can_afford(Items.item(&"bread").buy_price):
			stall._buy(npc, Items.item(&"bread"))))
	return Sequence.new("Buying bread", steps)


func chat_line() -> String:
	var lines: Array[String] = []
	var doing := npc.activity().to_lower()
	if doing != "":
		lines.append("Can't stop long, I'm %s." % doing)
	var s := Clock.wind_strength()
	if s < MIN_WIND:
		lines.append("No wind, no milling. I'll wait on the weather.")
	elif s > 0.8:
		lines.append("A wind like this, you reef right down or she'll run away with you.")
	else:
		lines.append("%s. %s." % [Clock.wind_string(), "I've her on %s" % PostMill.CLOTH_NAMES[mill.cloth]])
	if mill.store_count() == 0 and mill.hopper_count() == 0:
		lines.append("Nothing to grind. Bring me grain and I'll pay you fair for it.")
	else:
		lines.append("Wheat's %d gold a sack to me, barley %d. Fair quality, mind." % [Items.sell_value(&"wheat", 1), Items.sell_value(&"barley", 1)])
	if mill.is_grinding():
		lines.append("Feel the meal now and then. Too close and it scorches, too wide and it's grit.")
	if ground_today > 0:
		lines.append("%d sacks ground today." % ground_today)
	if sold_today > 0:
		lines.append("Took %d gold for flour today." % sold_today)
	return lines[rng.randi() % lines.size()]


func debug_status() -> String:
	return "[wind %.2f off %d° cloth %d brake %s speed %.2f hopper %d cur %s bin %d store %d gap %.2f feel %s]" % [
		Clock.wind_strength(), roundi(rad_to_deg(mill.off_wind())), mill.cloth, mill.brake_on, mill.speed,
		mill.hopper_count(), mill.current.get("id", "-"), mill.bin_count(), mill.store_count(), mill.gap, mill.feel_short()]


func on_day_started() -> void:
	sold_today = 0
	ground_today = 0


func to_dict() -> Dictionary:
	return {"ground_today": ground_today, "sold_today": sold_today}


func from_dict(d: Dictionary) -> void:
	ground_today = int(d.get("ground_today", 0))
	sold_today = int(d.get("sold_today", 0))


## Runs a task only if a condition holds when it's reached (e.g. the meal needed changing).
class _OnlyIf extends Task:
	var cond: Callable
	var inner: Task
	var _on := false

	func _init(c: Callable, t: Task) -> void:
		cond = c
		inner = t
		label = t.label

	func start(npc: Npc) -> void:
		_on = cond.call()
		if _on:
			inner.start(npc)

	func update(npc: Npc, delta: float) -> bool:
		return not _on or inner.update(npc, delta)

	func cancel(npc: Npc) -> void:
		if _on:
			inner.cancel(npc)
