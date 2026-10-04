class_name TillGame
extends Minigame
## Hoeing: a marker swings along a bar; click when it's in the green for a strong strike.
## Fresh sod takes about four good strikes, stubble two.

const PERIOD := 1.35
const GOOD := Vector2(0.68, 0.9)
const OK_LOW := 0.45
const COOLDOWN := 0.45

var plot: FarmPlot
var _t := 0.0
var _cooldown := 0.0
var _last := ""


func _init(p: FarmPlot) -> void:
	plot = p
	hint = "Click when the marker is in the green. Weak strikes still count, just less."


func _value() -> float:
	return 0.5 - 0.5 * cos(_t / PERIOD * TAU)


func update(delta: float) -> void:
	_t += delta * player.needs.speed_factor()
	_cooldown -= delta
	if _cooldown <= 0.0:
		player.viewmodel.pose_raise(_value() * 0.8)


func press() -> void:
	if _cooldown > 0.0:
		return
	var v := _value()
	var strength := 0.3
	_last = "Glancing blow"
	if v >= GOOD.x and v <= GOOD.y:
		strength = 1.0
		_last = "Good strike!"
	elif v >= OK_LOW:
		strength = 0.6
		_last = "Fair strike"
	_cooldown = COOLDOWN
	player.viewmodel.play_strike()
	player.needs.exert(0.6)
	var pos := player.target_point
	Sfx.play_at("hoe_strike", pos, -2.0 + strength * 3.0)
	Fx.dirt(player, pos, int(8 + strength * 14))
	if plot.state.till(strength):
		plot.refresh()
		player.say("The plot is tilled. Now sow it.")
		stop()
	else:
		plot.refresh()


func _on_stop() -> void:
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	var progress := plot.state.till_progress / plot.state.till_needed
	Minigame.draw_meter(c, center, _value(), GOOD.x, GOOD.y, "%s   ·   tilled %d%%" % [_last, roundi(progress * 100.0)])
