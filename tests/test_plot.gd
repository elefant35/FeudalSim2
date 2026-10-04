extends TestCase

var turnip: CropData = load("res://farming/data/crops/turnip.tres")
var barley: CropData = load("res://farming/data/crops/barley.tres")
var cabbage: CropData = load("res://farming/data/crops/cabbage.tres")


func _tilled() -> PlotState:
	var p := PlotState.new()
	while not p.is_tilled():
		p.till(1.0)
	return p


## Four handfuls aimed at the quarter points cover a plot evenly.
func _sow_evenly(p: PlotState, c: CropData) -> void:
	for pt in [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]:
		p.sow(c, pt)


func test_sod_needs_several_strikes() -> void:
	var p := PlotState.new()
	check(not p.till(1.0), "one strike shouldn't break sod")
	p.till(1.0); p.till(1.0)
	check(p.till(1.0), "fourth perfect strike tills")
	check(p.is_tilled())


func test_weak_strikes_take_longer_and_lower_quality() -> void:
	var p := PlotState.new()
	var n := 0
	while not p.is_tilled():
		p.till(0.4); n += 1
	eq(n, 10, "strikes at 0.4")
	check(p.till_quality < 0.5)


func test_cannot_sow_out_of_season() -> void:
	var p := _tilled()
	check(p.sow_error(barley, Clock.Season.SUMMER) != "", "barley in summer")
	eq(p.sow_error(barley, Clock.Season.SPRING), "", "barley in spring")
	check(PlotState.new().sow_error(turnip, 0) != "", "untilled")


func test_even_sowing_fills_all_cells() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	for i in PlotState.CELLS:
		eq(p.coverage(i), 1, "cell %d" % i)


func test_one_handful_leaves_gaps() -> void:
	var p := _tilled()
	p.sow(turnip, Vector2(0.5, 0.5))
	p.daily_update(0, false, rng())
	check(p.count_plants(PlotState.Plant.ALIVE) < 9)
	check(p.evenness < 0.8)


func test_watered_crop_ripens_on_time() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	var r := rng(7)
	p.daily_update(0, false, r)  # germinate
	var days := 0
	while not p.is_ripe() and days < 20:
		p.weeds.clear()
		p.water(1.0)
		p.daily_update(0, false, r)
		days += 1
	eq(days, 5, "turnip days")
	check(p.quality() >= 2, "well-kept crop should be good or fine, got %d" % p.quality())


func test_neglect_costs_quality() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	var r := rng(3)
	p.daily_update(1, false, r)
	var days := 0
	while not p.is_ripe() and days < 30:
		p.daily_update(1, false, r)  # summer, never watered, never weeded
		days += 1
	check(p.is_ripe() or p.count_plants(PlotState.Plant.ALIVE) == 0)
	check(p.quality() <= 1, "neglected crop should be poor or fair, got %d" % p.quality())
	check(days > 5, "drought slows growth")


func test_frost_kills_barley_but_not_turnips() -> void:
	var b := _tilled()
	_sow_evenly(b, barley)
	b.daily_update(0, false, rng())
	b.daily_update(Clock.Season.WINTER, false, rng())
	eq(b.has_crop(), false, "barley gone after frost")
	check(b.last_event.contains("frost"))
	var t := _tilled()
	_sow_evenly(t, turnip)
	t.daily_update(2, false, rng())
	t.daily_update(Clock.Season.WINTER, false, rng())
	check(t.has_crop(), "turnips survive")


func test_hand_harvest_then_stubble() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	p.daily_update(0, false, rng())
	p.growth = turnip.grow_days
	var got := 0
	for i in PlotState.CELLS:
		if p.harvest_cell(i) >= 0:
			got += 1
	eq(got, 9)
	eq(p.has_crop(), false, "plot cleared")
	eq(p.is_tilled(), false, "needs re-tilling")
	eq(p.till_needed, PlotState.STUBBLE_TILL)


func test_grain_is_cut_then_bound() -> void:
	var p := _tilled()
	_sow_evenly(p, barley)
	p.daily_update(0, false, rng())
	p.growth = barley.grow_days
	check(p.harvest_cell(0) >= 0)
	eq(p.plants[0], PlotState.Plant.CUT)
	check(p.bind_cell(0) >= 0)
	eq(p.plants[0], PlotState.Plant.DONE)
	eq(p.bind_cell(0), -1, "can't bind twice")


func test_blight_kills_and_pulling_stops_it() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	p.daily_update(0, false, rng())
	p.plants[4] = PlotState.Plant.BLIGHTED
	check(p.pull_plant(4))
	eq(p.plants[4], PlotState.Plant.NONE)
	p.plants[0] = PlotState.Plant.BLIGHTED
	var r := rng(11)
	p.water(1.0); p.daily_update(0, false, r)
	p.water(1.0); p.daily_update(0, false, r)
	eq(p.plants[0], PlotState.Plant.DEAD, "unpulled blight kills")


func test_caterpillars_on_cabbage() -> void:
	var p := _tilled()
	_sow_evenly(p, cabbage)
	var r := rng(5)
	p.daily_update(0, false, r)
	for d in 8:
		p.water(1.0)
		p.daily_update(0, false, r)
	var total := 0
	for c in p.caterpillars:
		total += c
	check(total > 0, "caterpillars should appear on unattended cabbage")


func test_crows_eat_seed() -> void:
	var p := _tilled()
	_sow_evenly(p, turnip)
	var before := 0.0
	for s in p.seeds: before += s
	var r := rng()
	for k in 6: p.crow_peck(r)
	var after := 0.0
	for s in p.seeds: after += s
	check(after < before - 1.0)


func test_save_roundtrip() -> void:
	var p := _tilled()
	_sow_evenly(p, cabbage)
	p.daily_update(0, true, rng())
	p.weeds.append(Vector2(0.2, 0.3))
	var q := PlotState.new()
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), func(id: StringName) -> CropData: return cabbage)
	eq(q.crop, cabbage)
	eq(q.plants, p.plants)
	eq(q.weeds.size(), p.weeds.size())
	eq(q.moisture, p.moisture)


func test_prices_and_quality() -> void:
	eq(Items.sell_value(&"turnip", 1), 2)
	check(Items.sell_value(&"wheat", 3) > Items.sell_value(&"wheat", 1))
	eq(Items.sell_value(&"barley_sheaf", 1), 0, "buyer won't take sheaves")
	eq(Items.sell_value(&"hoe", -1), 0, "buyer won't take tools")


func test_wheat_overwinters_into_summer() -> void:
	var wheat: CropData = load("res://farming/data/crops/wheat.tres")
	var p := _tilled()
	_sow_evenly(p, wheat)
	var r := rng(2)
	var day := 12   # first day of autumn
	p.daily_update(Clock.season_of(day), false, r)
	while not p.is_ripe() and day < 60:
		day += 1
		p.weeds.clear()
		p.water(0.8)
		p.daily_update(Clock.season_of(day), false, r)
	check(p.has_crop(), "wheat survives winter")
	eq(Clock.season_of(day), Clock.Season.SUMMER, "autumn-sown wheat ripens in early summer (day %d)" % day)
