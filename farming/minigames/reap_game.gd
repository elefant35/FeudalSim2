class_name ReapGame
extends Minigame
## Reaping: hold the button and sweep the crosshair across the ripe grain in firm, steady
## strokes. Too slow and the stalks just bend; too wild and you miss.

const GOOD_SPEED := Vector2(500.0, 2600.0)   ## Pixels/second of mouse sweep.

var _holding := false
var _speed := 0.0
var _swing_cd := 0.0
var _cut_this_swing: Array = []


func _init() -> void:
	locks_look = false
	hint = "Hold and sweep the mouse across the grain in steady strokes."


func press() -> void:
	_holding = true
	_cut_this_swing.clear()


func release() -> void:
	_holding = false


func mouse_motion(_rel: Vector2) -> void:
	pass


func _input_speed(delta: float) -> float:
	var v := Input.get_last_mouse_velocity()
	return absf(v.x) if delta > 0 else 0.0


func update(delta: float) -> void:
	_speed = lerpf(_speed, _input_speed(delta), 0.3)
	_swing_cd -= delta
	if not _holding:
		return
	var good := _speed >= GOOD_SPEED.x and _speed <= GOOD_SPEED.y
	if good and _swing_cd <= 0.0:
		_swing_cd = 0.35
		_cut_this_swing.clear()
		player.viewmodel.play_sweep()
		Sfx.play("swish", -3.0, 0.15)
		player.needs.exert(0.25)
	if not good:
		return
	player.ray.force_raycast_update()
	var plot := FarmPlot.from_collider(player.ray.get_collider())
	if plot == null or not plot.state.is_ripe():
		return
	var c := plot.cell_under(player.ray.get_collision_point())
	var key := "%d:%d" % [plot.index, c]
	if key in _cut_this_swing:
		return
	if plot.state.harvest_cell(c) >= 0:
		_cut_this_swing.append(key)
		Sfx.play_at("cut", plot.cell_world(c), -2.0)
		Fx.burst(player, plot.cell_world(c) + Vector3(0, 0.5, 0), Color(0.85, 0.72, 0.4), 12, 1.5, Vector3.UP, 70.0, 0.025)
		plot.refresh()


func _on_stop() -> void:
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	var v := clampf(_speed / 3200.0, 0.0, 1.0)
	Minigame.draw_meter(c, center, v, GOOD_SPEED.x / 3200.0, GOOD_SPEED.y / 3200.0, "Stroke")
