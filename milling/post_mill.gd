class_name PostMill
extends Node3D
## A post windmill. The whole body turns on its great post: take the tailpole and walk it round
## to face the sails into the wind. Spread more or less cloth on the sails for the strength of
## the wind (only with the brake on: nobody reefs a turning sail). Tip sacks of clean grain into
## the hopper, let the brake off, and the stones grind it into the meal bin: wheat into flour,
## barley into meal.
## The miller's craft is the gap between the stones (the tentering lever). Close stones grind
## fine but slowly; too close and they grind the bran in with the flour (dusty, dark meal), and
## they heat the meal, the more so the faster the sails turn. Wide stones grind quickly but
## coarse. Feel the meal at the spout ("rule of thumb") to judge it: fine, cool, clean meal keeps
## the grain's quality; gritty, dusty or scorched meal loses some. The best miller grinds as wide
## as the meal allows, because that's quickest.
## The mill runs on game minutes (Clock), so a villager miller works one by the same rules.

signal ground(id: StringName, quality: int)   ## A sack's worth went into the meal bin.

const CLOTH_NAMES: Array[String] = ["bare", "first reef", "sword point", "dagger point", "full sail"]
const CLOTH_AREA: Array[float] = [0.1, 0.35, 0.55, 0.75, 1.0]
const POWER := 1.3            ## Sail speed per unit of wind on a full sail, square to the wind.
const GRIND_MIN := 0.22       ## Slower than this, the stones barely turn.
const RUNAWAY := 0.85         ## Faster than this, the sails are running away.
const SACKS_PER_HOUR := 1.8   ## Grinding rate at full speed with the stones half open.
const FINE_ENOUGH := 0.75     ## Coarser than this, the meal is rough.
const TOO_FINE := 0.93        ## Finer than this, the stones are grinding the bran in: dusty meal.
const HOPPER_MAX := 4
const BIN_MAX := 8
const STORE_MAX := 24
const TURN_RATE := 0.22       ## How fast (radians/second) the body can be walked round.
const TAIL_SLACK := 1.3       ## How far from the tailpole's end you can get before it holds you.
# Body layout (local to the body, which turns; the sails face -Z, the steps and tailpole +Z).
const FLOOR_Y := 2.6
const HALF := Vector2(1.8, 2.2)            ## Body half-width (x) and half-depth (z).
const HUB := Vector3(0, 5.4, -2.75)       ## Where the sails turn.
const TAIL_END := Vector3(0.8, 0.9, 6.4)  ## Where you take hold of the tailpole (beside the steps).
const STEPS_FOOT := Vector3(0, 0, 5.9)
const DOOR := Vector3(0, FLOOR_Y, 1.7)     ## Just inside the door.
## Where to stand to work each part, and the point to face (body-local). Inside, villagers walk
## via AISLE (the open middle by the door), which has a clear line to every spot.
const SPOTS := {
	&"hopper": [Vector3(0.1, FLOOR_Y, 0.05), Vector3(0, FLOOR_Y, -1.0)],
	&"bin": [Vector3(1.3, FLOOR_Y, -0.15), Vector3(1.2, FLOOR_Y, -1.0)],
	&"spout": [Vector3(1.3, FLOOR_Y, -0.15), Vector3(0.95, FLOOR_Y, -1.0)],
	&"brake": [Vector3(-1.15, FLOOR_Y, -0.6), Vector3(-1.35, FLOOR_Y, -1.35)],
	&"tenter": [Vector3(-0.7, FLOOR_Y, 0.45), Vector3(-0.95, FLOOR_Y, -0.15)],
}
const AISLE := Vector3(0, FLOOR_Y, 0.7)
## The grain store and its sign stand here (local to the mill, clear of the sails' sweep).
const STORE_AT := Vector3(7.5, 0, 1.0)

var owner_key: StringName = &"player"
var keeper: Actor = null      ## Who buys grain at the store and pays for it (the miller), if anyone.
var title: String = "Your windmill"
var heading := 0.0            ## The body's yaw. Facing the wind means heading == -Clock.wind_from().
var brake_on := true
var cloth := 2                ## Index into CLOTH_NAMES; the same on all four sails.
var gap := 0.5                ## 0 = stones almost touching (fine, hot) .. 1 = wide (coarse, quick).
var speed := 0.0              ## How fast the sails turn, 0..1 (1 = flat out).
var hopper := Inventory.new() ## Grain waiting to be ground.
var bin := Inventory.new()    ## Sacks of flour or meal, ground and ready.
var store := Inventory.new()  ## Grain the miller has bought in.
var current: Dictionary = {}  ## The measure on the stones now: {id, quality}.
var progress := 0.0           ## How much of it is ground (0..1).
var running_dry := false      ## Stones turning with nothing between them.
## The body that turns. A plain static body that we move: it only turns slowly while someone
## is outside on the tailpole, and nobody should be carried or flung by it.
var body: StaticBody3D

var _score_sum := 0.0
var _score_w := 0.0
var _puller: Actor = null
var _tug_warned := 0.0
var _spin := 0.0
var _sails: Node3D
var _cloths: Array[Node3D] = []
var _grain_fill: Node3D
var _meal_fill: Node3D
var _brake_lever: Node3D
var _tenter_lever: Node3D
var _store_visual := Node3D.new()
var _pennant := Node3D.new()
var _flap := 0.0
var _sail_sound := AudioStreamPlayer3D.new()
var _stone_sound := AudioStreamPlayer3D.new()


func _ready() -> void:
	add_to_group("mill")
	add_to_group("saveable")
	for inv: Inventory in [hopper, bin, store]:
		add_child(inv)
	_build_trestle()
	_build_body()
	_build_store()
	hopper.changed.connect(_refresh)
	bin.changed.connect(_refresh)
	store.changed.connect(_refresh_store)
	Clock.minutes_passed.connect(simulate)
	_refresh()
	_refresh_store()
	_place_body()


# --- Building --------------------------------------------------------------------------------

func _build_trestle() -> void:
	var trestle := StaticBody3D.new()
	trestle.name = "Trestle"
	add_child(trestle)
	trestle.add_child(Models.make(&"post_mill_trestle"))
	# The crosstrees and quarterbars under the body: a low solid block, and the post itself.
	for s: Array in [[Vector3(4.6, 0.8, 4.6), Vector3(0, 0.4, 0)], [Vector3(0.7, FLOOR_Y - 0.2, 0.7), Vector3(0, FLOOR_Y / 2.0 - 0.1, 0)]]:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = s[0]
		shape.shape = b
		shape.position = s[1]
		trestle.add_child(shape)


func _build_body() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	# Layer 2 only: people bump into it, but it stays out of the baked navigation (it turns).
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("wood_floor")
	add_child(body)
	var visual := Models.make(&"post_mill_body")
	body.add_child(visual)
	_grain_fill = visual.find_child("grain", true, false)
	_meal_fill = visual.find_child("meal", true, false)
	_brake_lever = visual.find_child("brake_lever", true, false)
	_tenter_lever = visual.find_child("tenter_lever", true, false)
	_sails = Models.make(&"post_mill_sails")
	_sails.position = HUB
	body.add_child(_sails)
	for i in 4:
		var c := _sails.find_child("cloth_%d" % i, true, false)
		if c:
			_cloths.append(c)
	# Solid parts: floor, walls (a door at the back), roof, the stones' platform, the bin, the steps.
	var t := 0.12
	var h := 2.7
	_solid(Vector3(HALF.x * 2, t, HALF.y * 2), Vector3(0, FLOOR_Y - t / 2, 0))
	_solid(Vector3(HALF.x * 2, t, HALF.y * 2 + 0.4), Vector3(0, FLOOR_Y + h + t / 2, 0))
	_solid(Vector3(t, h, HALF.y * 2), Vector3(-HALF.x, FLOOR_Y + h / 2, 0))
	_solid(Vector3(t, h, HALF.y * 2), Vector3(HALF.x, FLOOR_Y + h / 2, 0))
	_solid(Vector3(HALF.x * 2, h, t), Vector3(0, FLOOR_Y + h / 2, -HALF.y))
	var side := (HALF.x * 2 - 1.0) / 2.0
	for sx: float in [-1.0, 1.0]:
		_solid(Vector3(side, h, t), Vector3(sx * (0.5 + side / 2), FLOOR_Y + h / 2, HALF.y))
	_solid(Vector3(1.0, h - 1.95, t), Vector3(0, FLOOR_Y + 1.95 + (h - 1.95) / 2, HALF.y))
	_solid(Vector3(1.3, 0.85, 1.3), Vector3(0, FLOOR_Y + 0.425, -1.0))     # the stones in their vat
	_solid(Vector3(0.55, 0.6, 0.7), Vector3(1.2, FLOOR_Y + 0.3, -1.0))     # the meal bin
	# The steps: a ramp from the door down to the ground.
	var top := Vector3(0, FLOOR_Y, HALF.y)
	var run := STEPS_FOOT - top
	var ramp := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(1.0, 0.1, run.length() + 0.3)
	ramp.shape = rb
	ramp.position = (top + STEPS_FOOT) / 2.0 + Vector3(0, -0.06, 0)
	ramp.rotation.x = atan2(-run.y, run.z)
	body.add_child(ramp)
	# Rain stops at the roof.
	var roof := GPUParticlesCollisionBox3D.new()
	roof.size = Vector3(HALF.x * 2, 3.0, HALF.y * 2)
	roof.position = Vector3(0, FLOOR_Y + 1.5, 0)
	body.add_child(roof)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, FLOOR_Y + 2.2, 0.6)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 0.5
	lamp.omni_range = 4.5
	body.add_child(lamp)
	# A pennant on the roof that streams downwind: face the sails the other way.
	var pole := Models.box(Vector3(0.05, 1.2, 0.05), Color(0.33, 0.22, 0.13), Vector3(0, 6.95, HALF.y - 0.1))
	body.add_child(pole)
	_pennant.position = Vector3(0, 7.45, HALF.y - 0.1)
	body.add_child(_pennant)
	_pennant.add_child(Models.box(Vector3(0.8, 0.28, 0.02), Color(0.7, 0.18, 0.14), Vector3(0.4, 0, 0)))
	# Things to aim at.
	for p: Array in [
		[&"tailpole", Vector3(0.5, 0.7, 1.8), TAIL_END + Vector3(0, 0.1, -0.6)],
		[&"sails", Vector3(3.0, 3.6, 0.8), HUB + Vector3(0, -3.2, -0.2)],
		[&"brake", Vector3(0.35, 1.6, 0.35), Vector3(-1.35, FLOOR_Y + 0.8, -1.35)],
		[&"tenter", Vector3(0.35, 1.3, 0.35), Vector3(-0.95, FLOOR_Y + 0.65, -0.15)],
		[&"hopper", Vector3(0.9, 0.55, 0.9), Vector3(0, FLOOR_Y + 1.3, -1.0)],
		[&"spout", Vector3(0.4, 0.3, 0.3), Vector3(0.8, FLOOR_Y + 0.6, -1.0)],
		[&"bin", Vector3(0.6, 0.65, 0.75), Vector3(1.2, FLOOR_Y + 0.33, -1.0)],
	]:
		body.add_child(MillPart.make(self, p[0], p[1], p[2]))
	for a: AudioStreamPlayer3D in [_sail_sound, _stone_sound]:
		a.unit_size = 7.0
		a.volume_db = -80.0
		body.add_child(a)
	_sail_sound.stream = Sfx.stream("mill_sails")
	_sail_sound.position = HUB + Vector3(0, -2.0, -0.3)
	_stone_sound.stream = Sfx.stream("mill_stones")
	_stone_sound.position = Vector3(0, FLOOR_Y + 0.5, -1.0)


func _solid(size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = at
	body.add_child(shape)


## The miller's grain store: sacks he's bought, stacked on a pallet clear of the sails.
func _build_store() -> void:
	_store_visual.position = STORE_AT
	add_child(_store_visual)


# --- The wind and the sails ------------------------------------------------------------------

## How far the sails face off the wind (radians, 0..PI).
func off_wind() -> float:
	return absf(angle_difference(heading, -Clock.wind_from()))


## How much of the wind the sails catch: 1 square on, nothing at 60 degrees or more off.
func facing() -> float:
	return clampf((cos(off_wind()) - 0.5) / 0.5, 0.0, 1.0)


## The speed the sails would settle at with the brake off.
func target_speed() -> float:
	var s := Clock.wind_strength() * CLOTH_AREA[cloth] * facing() * POWER
	if not hopper.stacks().is_empty() or not current.is_empty():
		s *= 0.88   # grinding takes some of the power
	return clampf(s, 0.0, 1.2)


## Game time passing: the sails speed up or slow down, and the stones grind.
func simulate(minutes: float) -> void:
	while minutes > 0.0:
		var m := minf(minutes, 5.0)
		minutes -= m
		var target := 0.0 if brake_on else target_speed()
		speed = lerpf(speed, target, 1.0 - exp(-m / (1.0 if brake_on else 4.0)))
		if target == 0.0 and speed < 0.01:
			speed = 0.0
		_grind(m)


func is_grinding() -> bool:
	return not brake_on and speed >= GRIND_MIN and not current.is_empty() and bin_count() < BIN_MAX


func _grind(minutes: float) -> void:
	running_dry = false
	if brake_on or speed < GRIND_MIN or bin_count() >= BIN_MAX:
		return
	if current.is_empty():
		current = _next_from_hopper()
		if current.is_empty():
			running_dry = true   # the stones turn on nothing
			return
	var r := pace() / 60.0 * minutes
	_score_sum += meal_score() * r
	_score_w += r
	progress += r
	if progress < 1.0:
		return
	var out := Items.item(StringName(current.id)).mills_to
	var q := flour_quality(int(current.quality), _score_sum / maxf(_score_w, 0.0001))
	bin.add(out, 1, q)
	ground.emit(out, q)
	current = {}
	progress = 0.0
	_score_sum = 0.0
	_score_w = 0.0


func _next_from_hopper() -> Dictionary:
	for st in hopper.stacks():
		var q := hopper.take_one(st.id, true)
		if q > -2:
			return {"id": String(st.id), "quality": q}
	return {}


# --- The meal: fineness, heat, and the miller's rule of thumb ---------------------------------

## How fine the meal comes out (1 = soft as silk).
func fineness() -> float:
	return clampf(1.05 - gap * 0.9 - maxf(0.0, 0.4 - speed) * 0.8, 0.0, 1.0)


## How hot it runs (over 0.4 starts to scorch it).
func heat() -> float:
	return clampf(speed * 1.2 - gap * 0.9 - 0.05, 0.0, 1.0)


## Sacks an hour the stones would grind at this speed and gap (wider is quicker).
func pace() -> float:
	return SACKS_PER_HOUR * speed * lerpf(0.6, 1.4, gap) if speed >= GRIND_MIN else 0.0


## How good the meal is, 0..1: fine but not dusty, and cool.
func meal_score() -> float:
	var f := fineness()
	var grade := minf(f, 1.0 - (f - 0.88) * 5.0)   # past 0.93 the bran comes through
	return clampf(grade - maxf(0.0, heat() - 0.4) * 2.0, 0.0, 1.0)


## Fine, cool meal keeps the grain's quality; rough meal loses a grade, poor meal two.
static func flour_quality(grain_quality: int, score: float) -> int:
	var lost := 0 if score >= 0.75 else (1 if score >= 0.55 else 2)
	return maxi(0, grain_quality - lost)


## A word for the meal as it is now.
func feel_short() -> String:
	if heat() > 0.55:
		return "hot"
	if heat() > 0.4:
		return "warm"
	if fineness() > TOO_FINE:
		return "dusty"
	if fineness() < 0.55:
		return "gritty"
	if fineness() < FINE_ENOUGH:
		return "rough"
	return "just right"


## What the meal feels like, rubbed between finger and thumb.
func feel() -> String:
	if not is_grinding():
		if running_dry:
			return "Nothing's coming through: the stones are running dry. Fill the hopper or brake."
		return "Nothing's coming through."
	match feel_short():
		"hot": return "Hot to the touch! The stones are too close for this speed. Open them up, or take in cloth."
		"warm": return "Warm. It's starting to scorch: open the stones a touch."
		"dusty": return "Floury dust, and dark with it: the stones are so close they're grinding the bran in. Open them a touch (it'll grind quicker too)."
		"gritty": return "Gritty and coarse. Bring the stones closer."
		"rough": return "A bit rough. The stones could come a little closer."
	return "Cool and soft as silk. Just right. (Open the stones as far as it stays like this: wider grinds quicker.)"


func pace_text() -> String:
	return "grinding about %.1f sacks an hour" % pace() if is_grinding() else "not grinding"


func speed_text() -> String:
	if speed < 0.03:
		return "stopped" if brake_on else "barely stirring"
	if speed < GRIND_MIN:
		return "barely turning"
	if speed > RUNAWAY:
		return "running away!"
	if speed > 0.65:
		return "running fast"
	return "turning steadily"


func facing_text() -> String:
	var d := roundi(rad_to_deg(off_wind()))
	if d < 10:
		return "square into the wind"
	if d < 30:
		return "a little off the wind (%d°)" % d
	if d < 60:
		return "well off the wind (%d°)" % d
	if d < 120:
		return "side-on to the wind (%d°)" % d
	return "away from the wind"


func gap_text() -> String:
	return "close" if gap < 0.3 else ("wide" if gap > 0.62 else "half open")


func bin_count() -> int:
	var n := 0
	for st in bin.stacks():
		n += st.count
	return n


func hopper_count() -> int:
	var n := 0
	for st in hopper.stacks():
		n += st.count
	return n


func store_count() -> int:
	var n := 0
	for st in store.stacks():
		n += st.count
	return n


# --- Working the mill (any actor) ------------------------------------------------------------

func is_owner(actor: Actor) -> bool:
	return actor.owner_key == owner_key


func set_brake(actor: Actor, on: bool) -> void:
	if brake_on == on:
		return
	brake_on = on
	Sfx.play_at("brake", body.to_global(Vector3(-1.35, FLOOR_Y + 1.0, -1.35)), -4.0)
	if actor is Player:
		actor.say("The brake is on: the sails slow and stop." if on else "You let the brake off. The sails take the wind.")


## Spread (+1) or take in (-1) a step of cloth on every sail. Only with the sails stopped.
func change_cloth(actor: Actor, step: int) -> bool:
	if speed > 0.04 or not brake_on:
		actor.say("Brake the mill and let the sails stop before you touch the cloth.")
		return false
	var n := clampi(cloth + step, 0, CLOTH_AREA.size() - 1)
	if n == cloth:
		actor.say("The sails are already %s." % ("bare" if step < 0 else "at full sail"))
		return false
	cloth = n
	Sfx.play_at("cloth", body.to_global(HUB + Vector3(0, -3.5, 0)), -2.0)
	_refresh()
	actor.say("Sails set to %s." % CLOTH_NAMES[cloth])
	return true


func set_gap(g: float) -> void:
	gap = clampf(g, 0.0, 1.0)
	_refresh()


## Tips the actor's sacks of grain into the hopper (as many as fit). Returns how many.
func tip_in(actor: Actor) -> int:
	var it := Items.item(actor.carry_id) if actor.is_carrying() else null
	if it == null or it.mills_to == &"":
		return 0
	var id := actor.carry_id
	var units := actor.take_carry()
	var n := 0
	for q in units:
		if hopper_count() < HOPPER_MAX:
			hopper.add(id, 1, q)
			n += 1
		else:
			actor.pick_up(id, q)
	if n > 0:
		Sfx.play_at("grain", body.to_global(Vector3(0, FLOOR_Y + 1.4, -1.0)), -2.0)
	actor.say("You tip %d sack%s into the hopper." % [n, "" if n == 1 else "s"] if n > 0 else "The hopper is full.")
	return n


## Lifts an armful of flour sacks from the bin. Returns how many.
func take_flour(actor: Actor) -> int:
	var n := 0
	for st in bin.stacks():
		while actor.carry_space(st.id) > 0:
			var q := bin.take_one(st.id, true)
			if q < -1:
				break
			actor.pick_up(st.id, q)
			n += 1
		if n > 0:
			break
	if n > 0:
		Sfx.play_at("rustle", body.to_global(Vector3(1.2, FLOOR_Y + 0.5, -1.0)))
	return n


## Takes an armful of grain from the store (the miller, carrying it up to the hopper), no more
## than `limit` sacks.
func take_from_store(actor: Actor, limit: int = 99) -> int:
	var n := 0
	for st in store.stacks():
		while actor.carry_space(st.id) > 0 and n < limit:
			var q := store.take_one(st.id, true)
			if q < -1:
				break
			actor.pick_up(st.id, q)
			n += 1
		if n > 0:
			break
	return n


# --- The tailpole: walking the body round -----------------------------------------------------

## Where to stand to take the tailpole (on the ground).
func tail_point() -> Vector3:
	var p := body.to_global(TAIL_END)
	return Vector3(p.x, global_position.y, p.z)


## How far round from straight back the tailpole's end sits (it runs beside the steps).
static func tail_angle() -> float:
	return atan2(TAIL_END.x, TAIL_END.z)


## The heading that faces the sails square into the wind.
func wind_heading() -> float:
	return wrapf(-Clock.wind_from(), -PI, PI)


func grab(actor: Actor) -> void:
	_puller = actor
	actor.pulling = self
	actor._carry_updated()
	Sfx.play_at("crank", tail_point(), -6.0)
	actor.say("You lean on the tailpole. Walk it round to bring the sails into the wind (E lets go).")


func release(actor: Actor) -> void:
	if _puller == actor:
		_puller = null
	actor.pulling = null
	actor._carry_updated()


func is_pulled() -> bool:
	return _puller != null


## Swings the body straight to a heading (villagers in tests; loading).
func turn_to(h: float) -> void:
	heading = wrapf(h, -PI, PI)
	_place_body()


func _physics_process(delta: float) -> void:
	_tug_warned = maxf(0.0, _tug_warned - delta)
	if _puller == null:
		return
	# The tail swings round after whoever holds it, slowly: it's the whole mill turning.
	var d := _puller.global_position - global_position
	var want := atan2(d.x, d.z) - tail_angle()
	var before := heading
	# (A villager's work runs at the game's speed; the player turns it at their own pace.)
	var rate := TURN_RATE * (float(Clock.speed()) if _puller is Npc else 1.0)
	heading = rotate_toward(heading, want, rate * delta)
	heading = wrapf(heading, -PI, PI)
	_place_body()
	if absf(angle_difference(before, heading)) > 0.0005 and randf() < delta * 3.0:
		Sfx.play_at("creak", tail_point(), -6.0, 0.15)
	# Get too far ahead and the tailpole holds you back.
	var hold := tail_point()
	var away := Vector3(_puller.global_position.x - hold.x, 0, _puller.global_position.z - hold.z)
	if away.length() > TAIL_SLACK:
		var at := hold + away.normalized() * TAIL_SLACK
		_puller.global_position = Vector3(at.x, _puller.global_position.y, at.z)
		_puller.velocity = Vector3(0, _puller.velocity.y, 0)
		if _tug_warned <= 0.0 and _puller is Player:
			_tug_warned = 3.0
			(_puller as Player).viewmodel.play_jerk()
			_puller.say("Heavy going: the whole mill turns on its post. Slow and steady.")


func _place_body() -> void:
	if body:
		body.rotation.y = heading


# --- Per frame: sails turning, levers, sound --------------------------------------------------

func _process(delta: float) -> void:
	_spin += speed * 2.2 * delta * Clock.speed()
	if _sails:
		_sails.rotation.z = _spin
	var dir := Clock.wind_dir()
	var s := Clock.wind_strength()
	_flap += delta * (4.0 + s * 10.0)
	_pennant.global_rotation = Vector3(0, atan2(-dir.z, dir.x), lerpf(-1.3, -0.05, clampf(s * 1.6, 0.0, 1.0)) + sin(_flap) * 0.08 * (0.3 + s))
	var loud := clampf(speed / 0.6, 0.0, 1.0)
	_set_loop(_sail_sound, loud > 0.05, linear_to_db(maxf(loud, 0.001)) - 4.0, 0.7 + speed * 0.6)
	_set_loop(_stone_sound, is_grinding(), -6.0, 0.8 + speed * 0.4)


func _set_loop(p: AudioStreamPlayer3D, on: bool, db: float, pitch: float) -> void:
	if p.stream == null:
		return
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
	p.volume_db = db
	p.pitch_scale = pitch


func _refresh() -> void:
	if _grain_fill:
		var g := hopper_count() + (1 if not current.is_empty() else 0)
		_grain_fill.visible = g > 0
		_grain_fill.scale = Vector3.ONE * clampf(sqrt(float(g) / HOPPER_MAX), 0.3, 1.0)   # the level drops down the funnel
	if _meal_fill:
		var m := bin_count()
		_meal_fill.visible = m > 0
		_meal_fill.scale = Vector3(1, clampf(float(m) / BIN_MAX, 0.1, 1.0), 1)
	if _brake_lever:
		_brake_lever.rotation.x = -0.5 if brake_on else 0.35
	if _tenter_lever:
		_tenter_lever.rotation.x = lerpf(0.35, -0.35, gap)
	for c in _cloths:
		c.scale = Vector3(CLOTH_AREA[cloth] if cloth > 0 else 0.02, 1, 1)


func _refresh_store() -> void:
	for c in _store_visual.get_children():
		c.queue_free()
	if keeper == null:
		return
	var pallet := Models.box(Vector3(1.6, 0.12, 1.2), Color(0.45, 0.32, 0.2), Vector3(0, 0.06, 0))
	_store_visual.add_child(pallet)
	var n := mini(store_count(), 12)
	for i in n:
		var m := Models.make(&"grain_sack")
		m.position = Vector3((i % 3) * 0.48 - 0.48, 0.12 + (i / 6) * 0.5, ((i / 3) % 2) * 0.5 - 0.25)
		m.rotation.y = i * 1.3
		_store_visual.add_child(m)


# --- What the player sees and does ----------------------------------------------------------

func part_prompt(part: StringName, player: Player) -> String:
	if part == &"store":
		return _store_prompt(player)
	if not is_owner(player):
		return "%s\nIt's not your mill to work." % title
	match part:
		&"tailpole":
			var lines := ["Tailpole · %s · the sails face %s" % [Clock.wind_string(), facing_text()]]
			if _puller == player:
				lines.append("Walk round slowly to swing the sails into the wind   ·   [E] Let go")
			else:
				lines.append("[E] Take hold and walk the mill round into the wind")
			return "\n".join(lines)
		&"sails":
			var head := "Sails · %s · %s · %s" % [CLOTH_NAMES[cloth], speed_text(), Clock.wind_string().to_lower()]
			if speed > 0.04 or not brake_on:
				return "%s\nBrake the mill (the lever inside) before you touch the cloth." % head
			return "%s\n[E] Spread more cloth   ·   [Click] Take some in" % head
		&"brake":
			return "Brake lever · sails %s\n[E] %s" % [speed_text(), "Let the brake off" if brake_on else "Put the brake on"]
		&"tenter":
			return "Tentering lever · the stones are %s · the meal is %s · %s\n[Click] Set the gap: closer is finer but slower, wider is quicker but coarser" % [gap_text(), feel_short() if is_grinding() else "not running", pace_text()]
		&"hopper":
			var head := "Hopper · %d/%d sacks waiting%s" % [hopper_count(), HOPPER_MAX, " · %s on the stones" % Items.name_of(StringName(current.id)).to_lower() if not current.is_empty() else ""]
			if player.is_carrying():
				var it := Items.item(player.carry_id)
				if it and it.mills_to != &"":
					return "%s\n[E] Tip your %s in" % [head, player.carry_text()] if hopper_count() < HOPPER_MAX else "%s\nThe hopper is full." % head
				return "%s\nOnly clean grain goes in the hopper." % head
			return "%s\nCarry sacks of clean grain up here and tip them in." % head
		&"spout":
			return "Meal spout · %s\n[E] Feel the meal (the rule of thumb)" % ("meal running" if is_grinding() else "nothing coming through")
		&"bin":
			var head := "Meal bin · %s" % _bin_text()
			if is_grinding():
				head += " · grinding %d%%" % roundi(progress * 100.0)
			if bin_count() >= BIN_MAX:
				head += "\nThe bin is full: the stones won't grind on until you take some out."
			if bin_count() > 0 and not player.is_carrying():
				return "%s\n[E] Take an armful of sacks" % head
			return head
	return title


func _bin_text() -> String:
	if bin.stacks().is_empty():
		return "empty"
	var parts: Array[String] = []
	for st in bin.stacks():
		parts.append("%d %s" % [st.count, Items.name_of(st.id, st.quality).to_lower()])
	return ", ".join(parts)


func part_interact(part: StringName, player: Player) -> void:
	if part == &"store":
		_store_interact(player)
		return
	if not is_owner(player):
		player.say("That's not your mill. Best leave the miller's stones alone.")
		return
	match part:
		&"tailpole":
			if _puller == player:
				release(player)
			elif player.is_carrying():
				player.say("Put down what you're carrying first.")
			else:
				grab(player)
		&"sails":
			change_cloth(player, 1)
		&"brake":
			set_brake(player, not brake_on)
		&"hopper":
			if player.is_carrying():
				tip_in(player)
		&"spout":
			Sfx.play_at("grain", body.to_global(Vector3(0.8, FLOOR_Y + 0.6, -1.0)), -12.0)
			player.say(feel())
		&"bin":
			if not player.is_carrying() and take_flour(player) == 0:
				player.say("Nothing in the bin yet.")
		&"tenter":
			player.say("Click and move the mouse to set the stones.")


func part_use(part: StringName, player: Player) -> Minigame:
	if part == &"store" or not is_owner(player):
		return null
	match part:
		&"sails":
			change_cloth(player, -1)
		&"tenter":
			return TenterGame.new(self)
	return null


# --- The miller's grain store: selling grain to the miller ------------------------------------

## The grain an actor could sell here: from their arms and their own handcart parked close by.
func buy_grain(seller: Actor) -> int:
	if keeper == null:
		return 0
	var paid := 0
	if seller.is_carrying() and _wanted(seller.carry_id):
		var id := seller.carry_id
		for q in seller.take_carry():
			if not _buy_one(id, q):
				seller.pick_up(id, q)
				continue
			paid += Items.sell_value(id, q)
	var cart := _seller_cart(seller)
	if cart:
		for st in cart.goods.stacks():
			if not _wanted(st.id):
				continue
			for k in st.count:
				if store_count() >= STORE_MAX or keeper.wallet.gold < Items.sell_value(st.id, st.quality):
					break
				if cart.goods.remove(st.id, 1, st.quality) and _buy_one(st.id, st.quality):
					paid += Items.sell_value(st.id, st.quality)
	if paid > 0:
		seller.wallet.add(paid)
		Sfx.play_at("coins", global_position + STORE_AT, -6.0)
	return paid


func _wanted(id: StringName) -> bool:
	var it := Items.item(id)
	return it != null and it.mills_to != &""


func _buy_one(id: StringName, q: int) -> bool:
	var price := Items.sell_value(id, q)
	if store_count() >= STORE_MAX or not keeper.wallet.spend(price):
		return false
	store.add(id, 1, q)
	return true


func _seller_cart(seller: Actor) -> HandCart:
	for c: HandCart in get_tree().get_nodes_in_group("cart"):
		if c.owner_key == seller.owner_key and c.global_position.distance_to(to_global(STORE_AT)) < 9.0:
			return c
	return null


func _store_prompt(player: Player) -> String:
	if keeper == null:
		return title
	var head := "%s's grain store · %d/%d sacks · %s pays %d gold for wheat, %d for barley (fair)" % [
		keeper.display_name, store_count(), STORE_MAX, keeper.display_name, Items.sell_value(&"wheat", 1), Items.sell_value(&"barley", 1)]
	if player.is_carrying() and _wanted(player.carry_id):
		return "%s\n[E] Sell your %s" % [head, player.carry_text()]
	if _seller_cart(player):
		return "%s\n[E] Sell the grain in your handcart" % head
	return "%s\nBring sacks of clean grain in your arms or your handcart to sell." % head


func _store_interact(player: Player) -> void:
	if keeper == null:
		return
	var before := store_count()
	var paid := buy_grain(player)
	if paid > 0:
		player.say("%s pays you %d gold for %d sack%s." % [keeper.display_name, paid, store_count() - before, "" if store_count() - before == 1 else "s"])
	elif store_count() >= STORE_MAX:
		player.say("The store is full. %s will take more once he's milled some." % keeper.display_name)
	elif keeper.wallet.gold <= 0:
		player.say("%s can't pay for more grain just now." % keeper.display_name)
	else:
		player.say("Bring clean grain: threshed and winnowed, in sacks.")


## Adds the grain store's own aim box and sign (only for a mill with a miller who buys).
func open_store(keeper_actor: Actor) -> void:
	keeper = keeper_actor
	var part := MillPart.make(self, &"store", Vector3(1.8, 1.2, 1.4), STORE_AT + Vector3(0, 0.6, 0))
	add_child(part)
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 0.6, 1.2)
	shape.shape = b
	shape.position = STORE_AT + Vector3(0, 0.3, 0)
	solid.add_child(shape)
	add_child(solid)
	_refresh_store()


# --- Save ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"heading": heading, "brake": brake_on, "cloth": cloth, "gap": gap, "speed": speed,
		"hopper": hopper.to_dict(), "bin": bin.to_dict(), "store": store.to_dict(),
		"current": current, "progress": progress, "score_sum": _score_sum, "score_w": _score_w,
	}


func from_dict(d: Dictionary) -> void:
	turn_to(float(d.get("heading", 0.0)))
	brake_on = bool(d.get("brake", true))
	cloth = int(d.get("cloth", 2))
	gap = float(d.get("gap", 0.5))
	speed = float(d.get("speed", 0.0))
	hopper.from_dict(d.get("hopper", {}))
	bin.from_dict(d.get("bin", {}))
	store.from_dict(d.get("store", {}))
	current = d.get("current", {})
	if not current.is_empty():
		current = {"id": String(current.id), "quality": int(current.quality)}
	progress = float(d.get("progress", 0.0))
	_score_sum = float(d.get("score_sum", 0.0))
	_score_w = float(d.get("score_w", 0.0))
	_refresh()
	_refresh_store()
