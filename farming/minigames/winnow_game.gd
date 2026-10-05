class_name WinnowGame
extends Minigame
## Winnowing: hold to lift the basket, release to toss the grain up. Toss when the wind gusts
## and the chaff blows away; in still air it just falls back in.

const GUST := 0.6

var floor_: ThreshingFloor
var item: StringName = &""  ## The unwinnowed grain in the basket, e.g. barley_chaff.
var quality: int = 0
var _loaded := false       ## One measure is in the basket (taken from the floor's heap).
var _bagged := 0           ## Sacks filled this session.
var _clean := 0.0
var _lift := 0.0
var _holding := false
var _last := ""


func _init(f: ThreshingFloor) -> void:
	floor_ = f
	hint = "Hold to lift, release to toss. Toss when the wind gusts (watch the pennant)."


func _load_next() -> bool:
	var m := floor_.take_from_heap()
	if m.is_empty():
		return false
	item = m.id
	quality = m.quality
	_loaded = true
	_clean = 0.0
	return true


func _on_start() -> void:
	_load_next()
	var g := player.viewmodel.held_model()
	if g:
		var grain := g.find_child("grain", true, false) as Node3D
		if grain:
			grain.visible = true


func press() -> void:
	_holding = true


func release() -> void:
	if not _holding:
		return
	_holding = false
	if _lift < 0.5:
		return
	var wind := floor_.wind
	var gain := 0.05
	_last = "Still air: the chaff fell back in"
	if wind >= GUST:
		gain = 0.4
		_last = "The wind took the chaff!"
	elif wind >= GUST * 0.6:
		gain = 0.2
		_last = "Some chaff blew off"
	_clean += gain
	player.viewmodel.play_toss()
	player.needs.exert(0.4)
	Sfx.play("toss", -4.0)
	var hand := player.camera.global_transform * Vector3(0, 0.0, -0.6)
	Fx.burst(player, hand, Color(0.8, 0.7, 0.45), int(30 * gain) + 6, 1.5 + wind * 3.0, floor_.wind_dir() + Vector3.UP * 0.6, 25.0, 0.02, 1.5, 1.6)
	if _clean >= 1.0:
		var clean_item := StringName(String(item).trim_suffix("_chaff"))
		var pile := floor_.add_clean(clean_item, quality)
		_bagged += 1
		Sfx.play("grain", -4.0)
		Sfx.play_at("thump", pile.global_position, -8.0)
		player.say("Clean %s bagged and set beside the floor (%d there now)." % [clean_item, pile.units.size()])
		_loaded = false
		if not _load_next():
			player.say("All winnowed. The sacks stand beside the floor: pick them up (E) and take them to the cart or buyer.")
			stop()


func update(delta: float) -> void:
	_lift = move_toward(_lift, 1.0 if _holding else 0.0, delta * 2.5)
	if _holding:
		player.viewmodel.pose_lift(_lift)


func _on_stop() -> void:
	if _loaded:
		floor_.return_to_heap(item, quality)
		_loaded = false
	player.viewmodel.pose_rest()
	var g := player.viewmodel.held_model()
	if g:
		var grain := g.find_child("grain", true, false) as Node3D
		if grain:
			grain.visible = false


func draw(c: Control, center: Vector2) -> void:
	Minigame.draw_meter(c, center, floor_.wind, GUST, 1.0, "Wind   ·   %s" % _last, Color(0.55, 0.75, 0.9))
	Minigame.draw_fill(c, center, _clean, "Clean: %d bagged" % _bagged, Color(0.85, 0.72, 0.4))
