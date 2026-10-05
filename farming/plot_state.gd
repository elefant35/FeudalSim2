class_name PlotState
extends RefCounted
## The farming logic of one plot: tilling, seed cover, plants, water, weeds, pests, blight, growth.
## No visuals here, so it can be tested headlessly. A plot is a 3x3 grid of plant cells;
## positions are in plot space, (0,0)..(1,1).

enum Plant { NONE, ALIVE, BLIGHTED, DEAD, CUT, DONE }

const GRID := 3
const CELLS := GRID * GRID
const SOD_TILL := 4.0          ## Strike strength needed to break fresh sod.
const STUBBLE_TILL := 2.0      ## ...and to re-till after a harvest.
const SEED_MIN := 0.6          ## Seed density for a cell to sprout.
const SEED_CROWDED := 2.6      ## Above this the cell is overcrowded.
const SEED_SPREAD := 0.22      ## How widely one handful scatters.
const DRY := 0.2
const SOGGY := 1.1
const DRY_RATE: Array[float] = [0.3, 0.45, 0.3, 0.12]
const WEED_CHANCE := 0.4
const MAX_WEEDS := 5
const CATERPILLAR_CHANCE := 0.12
const BLIGHT_KILL_DAYS := 2
const BLIGHT_SPREAD := 0.5
const ROT_AFTER_DAYS := 4
const QUALITY_THRESHOLDS: Array[float] = [0.45, 0.65, 0.85]

var till_needed: float = SOD_TILL
var till_progress: float = 0.0
var till_quality: float = 0.0
var strikes: int = 0
var crop: CropData = null
var seeds: Array[float] = []
var germinated: bool = false
var plants: Array[int] = []
var blight_days: Array[int] = []
var caterpillars: Array[int] = []
var weeds: Array[Vector2] = []
var weeds_regrowing: int = 0
var growth: float = 0.0
var moisture: float = 0.3
var health: float = 1.0
var evenness: float = 0.0
var ripe_days: int = 0
var last_event: String = ""
## What hurt the crop at the last overnight update (shown to the player).
var stress: Array[String] = []


func _init() -> void:
	_clear_cells()


func _clear_cells() -> void:
	seeds.clear()
	plants.clear()
	blight_days.clear()
	caterpillars.clear()
	for i in CELLS:
		seeds.append(0.0)
		plants.append(Plant.NONE)
		blight_days.append(0)
		caterpillars.append(0)


# --- Queries --------------------------------------------------------------------------------

func is_tilled() -> bool:
	return till_progress >= till_needed - 0.001


func has_crop() -> bool:
	return crop != null


func is_sown_not_sprouted() -> bool:
	return crop != null and not germinated


func is_ripe() -> bool:
	return crop != null and germinated and growth >= crop.grow_days


func growth_fraction() -> float:
	if crop == null or not germinated:
		return 0.0
	return clampf(growth / crop.grow_days, 0.0, 1.0)


func count_plants(state: int) -> int:
	return plants.count(state)


## 0 poor, 1 fair, 2 good, 3 fine.
func quality() -> int:
	var score := health * 0.6 + evenness * 0.25 + till_quality * 0.15
	var q := 0
	for t in QUALITY_THRESHOLDS:
		if score >= t:
			q += 1
	return q


static func cell_center(i: int) -> Vector2:
	return Vector2((i % GRID + 0.5) / GRID, (i / GRID + 0.5) / GRID)


static func cell_at(p: Vector2) -> int:
	var x := clampi(int(p.x * GRID), 0, GRID - 1)
	var y := clampi(int(p.y * GRID), 0, GRID - 1)
	return y * GRID + x


## 0 bare, 1 good, 2 overcrowded.
func coverage(i: int) -> int:
	if seeds[i] < SEED_MIN:
		return 0
	return 2 if seeds[i] > SEED_CROWDED else 1


# --- Player actions -------------------------------------------------------------------------

## One hoe strike, strength 0..1. Returns true if this strike finished the tilling.
func till(strength: float) -> bool:
	if is_tilled() or has_crop():
		return false
	strikes += 1
	till_quality += (strength - till_quality) / strikes
	till_progress = minf(till_needed, till_progress + strength)
	if is_tilled():
		weeds.clear()
		weeds_regrowing = 0
		return true
	return false


## Why this crop can't be sown here now, or "" if it can.
func sow_error(c: CropData, season: int) -> String:
	if not is_tilled():
		return "Till the soil first."
	if germinated or (crop != null and crop != c):
		return "Something is already growing here."
	if not c.can_sow_in(season):
		return "%s can't be sown in %s." % [c.display_name, Clock.SEASON_NAMES[season].to_lower()]
	return ""


## One handful of seed landing around `point`.
func sow(c: CropData, point: Vector2) -> void:
	crop = c
	for i in CELLS:
		var d := cell_center(i).distance_to(point)
		seeds[i] += exp(-(d * d) / (2.0 * SEED_SPREAD * SEED_SPREAD))


func water(amount: float) -> void:
	moisture = minf(1.3, moisture + amount)


func pick_caterpillar(i: int) -> bool:
	if caterpillars[i] <= 0:
		return false
	caterpillars[i] -= 1
	return true


## Pull a blighted or dead plant. Returns true if something was pulled.
func pull_plant(i: int) -> bool:
	if plants[i] != Plant.BLIGHTED and plants[i] != Plant.DEAD:
		return false
	plants[i] = Plant.NONE
	blight_days[i] = 0
	caterpillars[i] = 0
	_check_finished()
	return true


## Remove a weed. A snapped root grows back the next day.
func remove_weed(index: int, snapped: bool) -> void:
	if index < 0 or index >= weeds.size():
		return
	weeds.remove_at(index)
	if snapped:
		weeds_regrowing += 1


## A crow eats some seed from the plot.
func crow_peck(rng: RandomNumberGenerator) -> void:
	if not is_sown_not_sprouted():
		return
	var with_seed: Array[int] = []
	for i in CELLS:
		if seeds[i] > 0.05:
			with_seed.append(i)
	if with_seed.is_empty():
		return
	var i := with_seed[rng.randi() % with_seed.size()]
	seeds[i] = maxf(0.0, seeds[i] - 0.3)


## Harvest one cell. Root crops come out whole; grain is cut and must then be bound.
## Returns the quality of what was harvested, or -1 if nothing.
func harvest_cell(i: int) -> int:
	if not is_ripe() or plants[i] != Plant.ALIVE:
		return -1
	var q := quality()
	plants[i] = Plant.CUT if crop.harvest == CropData.Harvest.SICKLE else Plant.DONE
	_check_finished()
	return q


## Bind a cut cell of grain into a sheaf. Returns quality, or -1.
func bind_cell(i: int) -> int:
	if plants[i] != Plant.CUT:
		return -1
	var q := quality()
	plants[i] = Plant.DONE
	_check_finished()
	return q


# --- Daily simulation -----------------------------------------------------------------------

## Runs at midnight. `season` and `raining` describe the new day.
func daily_update(season: int, raining: bool, rng: RandomNumberGenerator) -> void:
	last_event = ""
	if crop != null:
		if not germinated:
			_germinate()
		else:
			_grow(season, raining, rng)
	if is_tilled() or has_crop():
		for n in weeds_regrowing:
			_add_weed(rng)
		weeds_regrowing = 0
		if weeds.size() < MAX_WEEDS and rng.randf() < WEED_CHANCE:
			_add_weed(rng)
	moisture = maxf(0.0, moisture - DRY_RATE[season])
	if raining:
		moisture = maxf(moisture, 1.0)


func _germinate() -> void:
	var good := 0
	var crowded := 0
	for i in CELLS:
		match coverage(i):
			1:
				good += 1
				plants[i] = Plant.ALIVE
			2:
				crowded += 1
				plants[i] = Plant.ALIVE
	if good + crowded == 0:
		last_event = "The seed failed to come up."
		_finish_crop()
		return
	germinated = true
	evenness = (good + crowded * 0.4) / float(CELLS)
	if moisture < DRY:
		health -= 0.1


func _grow(season: int, raining: bool, rng: RandomNumberGenerator) -> void:
	stress.clear()
	if season == Clock.Season.WINTER and not crop.hardy:
		var killed := false
		for i in CELLS:
			if plants[i] == Plant.ALIVE or plants[i] == Plant.BLIGHTED:
				plants[i] = Plant.DEAD
				killed = true
		if killed:
			last_event = "The frost killed the %s." % crop.display_name.to_lower()
		_check_finished()
		return

	var rate := crop.season_growth[season]
	if moisture < DRY:
		rate *= 0.4
		health -= 0.12
		stress.append("dry soil (growth slowed)")
	elif moisture > SOGGY:
		health -= 0.03
		stress.append("waterlogged")
	health -= 0.035 * weeds.size()
	if not weeds.is_empty():
		# Weeds steal water and light: each one slows growth by a tenth (to half at worst).
		rate *= maxf(0.5, 1.0 - 0.1 * weeds.size())
		stress.append("weeds (growth slowed)")

	if crop.gets_caterpillars and growth >= 1.0:
		for i in CELLS:
			if plants[i] == Plant.ALIVE and rng.randf() < CATERPILLAR_CHANCE:
				caterpillars[i] += 1
		var total := 0
		for i in CELLS:
			total += caterpillars[i]
			if caterpillars[i] >= 3 and plants[i] == Plant.ALIVE:
				plants[i] = Plant.DEAD
				last_event = "Caterpillars ate a %s to nothing." % crop.display_name.to_lower()
		health -= 0.025 * total
		if total > 0:
			stress.append("caterpillars")

	_spread_blight(raining, rng)

	if growth >= crop.grow_days:
		ripe_days += 1
		if ripe_days > ROT_AFTER_DAYS:
			health -= 0.1
			stress.append("left too long")
			last_event = "The %s is spoiling in the field." % crop.display_name.to_lower()
	else:
		growth += rate
	health = clampf(health, 0.0, 1.0)
	_check_finished()


func _spread_blight(raining: bool, rng: RandomNumberGenerator) -> void:
	var newly: Array[int] = []
	for i in CELLS:
		if plants[i] == Plant.BLIGHTED:
			blight_days[i] += 1
			if blight_days[i] >= BLIGHT_KILL_DAYS:
				plants[i] = Plant.DEAD
				for n in _neighbors(i):
					if plants[n] == Plant.ALIVE and rng.randf() < BLIGHT_SPREAD:
						newly.append(n)
		elif plants[i] == Plant.ALIVE and rng.randf() < crop.blight_chance * (2.0 if raining or moisture > SOGGY else 1.0):
			newly.append(i)
	for i in newly:
		plants[i] = Plant.BLIGHTED
		blight_days[i] = 0
	if not newly.is_empty():
		last_event = "Blight has appeared on the %s." % crop.display_name.to_lower()


func _neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % GRID
	var y := i / GRID
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if nx >= 0 and nx < GRID and ny >= 0 and ny < GRID:
			out.append(ny * GRID + nx)
	return out


func _add_weed(rng: RandomNumberGenerator) -> void:
	if weeds.size() >= MAX_WEEDS:
		return
	# Weeds come up between the plant rows.
	weeds.append(Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.08, 0.92)))


## When nothing is left growing or lying cut, the plot returns to stubble.
func _check_finished() -> void:
	if crop == null or not germinated:
		return
	for p in plants:
		if p == Plant.ALIVE or p == Plant.BLIGHTED or p == Plant.CUT:
			return
	_finish_crop()


func _finish_crop() -> void:
	crop = null
	germinated = false
	_clear_cells()
	growth = 0.0
	health = 1.0
	evenness = 0.0
	ripe_days = 0
	stress.clear()
	till_needed = STUBBLE_TILL
	till_progress = 0.0
	till_quality = 0.0
	strikes = 0


# --- Save -----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var w: Array = []
	for p in weeds:
		w.append([p.x, p.y])
	return {
		"till_needed": till_needed, "till_progress": till_progress, "till_quality": till_quality,
		"strikes": strikes, "crop": String(crop.id) if crop else "", "seeds": seeds.duplicate(),
		"germinated": germinated, "plants": plants.duplicate(), "blight_days": blight_days.duplicate(),
		"caterpillars": caterpillars.duplicate(), "weeds": w, "weeds_regrowing": weeds_regrowing,
		"growth": growth, "moisture": moisture, "health": health, "evenness": evenness,
		"ripe_days": ripe_days,
	}


func from_dict(d: Dictionary, crop_lookup: Callable) -> void:
	till_needed = float(d.till_needed)
	till_progress = float(d.till_progress)
	till_quality = float(d.till_quality)
	strikes = int(d.strikes)
	crop = crop_lookup.call(StringName(d.crop)) if String(d.crop) != "" else null
	germinated = bool(d.germinated)
	for i in CELLS:
		seeds[i] = float(d.seeds[i])
		plants[i] = int(d.plants[i])
		blight_days[i] = int(d.blight_days[i])
		caterpillars[i] = int(d.caterpillars[i])
	weeds.clear()
	for p: Array in d.weeds:
		weeds.append(Vector2(p[0], p[1]))
	weeds_regrowing = int(d.weeds_regrowing)
	growth = float(d.growth)
	moisture = float(d.moisture)
	health = float(d.health)
	evenness = float(d.evenness)
	ripe_days = int(d.ripe_days)
