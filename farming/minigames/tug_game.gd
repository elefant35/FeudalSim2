class_name TugGame
extends Minigame
## Pulling something out by the roots: hold to pull, but the strain builds. Let go before it
## hits the red or the stem snaps. Used for weeds, blighted plants and root crops.

enum Kind { WEED, BLIGHT, HARVEST }

var plot: FarmPlot
var kind: Kind
var index: int
var _pull := 0.0
var _strain := 0.0
var _holding := false
var _need := 1.0
var _strain_rate := 0.8
var _wobble := 0.0


static func weed(p: FarmPlot, i: int) -> TugGame:
	var g := TugGame.new()
	g.plot = p
	g.kind = Kind.WEED
	g.index = i
	g._strain_rate = randf_range(0.9, 1.3)
	g._need = randf_range(1.0, 1.4)
	g.hint = "Hold to pull. Ease off before the strain reaches the red, or the root snaps and it grows back."
	return g


static func blighted(p: FarmPlot, i: int) -> TugGame:
	var g := TugGame.new()
	g.plot = p
	g.kind = Kind.BLIGHT
	g.index = i
	g._strain_rate = 0.7
	g.hint = "Pull the diseased plant before the blight spreads to its neighbours."
	return g


static func harvest(p: FarmPlot, i: int) -> TugGame:
	var g := TugGame.new()
	g.plot = p
	g.kind = Kind.HARVEST
	g.index = i
	g._strain_rate = 0.55
	g._need = 0.8
	g.hint = "Hold to ease it out of the ground."
	return g


func press() -> void:
	_holding = true


func release() -> void:
	_holding = false


func update(delta: float) -> void:
	var f := player.needs.speed_factor()
	if _holding:
		_pull += delta * 0.9 * f
		_wobble += delta * 7.0
		_strain += delta * _strain_rate * (1.0 + 0.35 * sin(_wobble))
		if randf() < delta * 3.0:
			Sfx.play_at("rustle", _where(), -8.0, 0.2)
	else:
		_strain = maxf(0.0, _strain - delta * 1.6)
	player.viewmodel.pose_pull(1.0, _strain if _holding else 0.0)
	if _strain >= 1.0:
		_snap()
	elif _pull >= _need:
		_succeed()


func _where() -> Vector3:
	if kind == Kind.WEED and index < plot.state.weeds.size():
		return plot.to_world(plot.state.weeds[index])
	return plot.cell_world(index)


func _succeed() -> void:
	var pos := _where()
	player.needs.exert(0.4)
	Sfx.play_at("pull", pos)
	Fx.dirt(player, pos, 10)
	match kind:
		Kind.WEED:
			plot.state.remove_weed(index, false)
		Kind.BLIGHT:
			plot.state.pull_plant(index)
			player.say("Diseased plant pulled. That stops it spreading; keep an eye on its neighbours.")
		Kind.HARVEST:
			plot.harvest_by_hand(player, index)
	plot.refresh()
	stop()


func _snap() -> void:
	var pos := _where()
	Sfx.play_at("snap", pos)
	match kind:
		Kind.WEED:
			plot.state.remove_weed(index, true)
			player.say("The stem snapped. The root will send up a new weed.")
		Kind.BLIGHT:
			plot.state.pull_plant(index)
		Kind.HARVEST:
			plot.harvest_by_hand(player, index)
			player.say("A bit bruised, but out.")
	plot.refresh()
	stop()


func _on_stop() -> void:
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	Minigame.draw_meter(c, center, _strain, 0.82, 1.0, "Strain", Color(0.8, 0.25, 0.2))
	Minigame.draw_fill(c, center, _pull / _need, "Pulled", Color(0.45, 0.7, 0.3))
