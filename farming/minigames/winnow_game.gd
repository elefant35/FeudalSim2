class_name WinnowGame
extends Minigame
## Winnowing: hold to lift the basket, release to toss the grain up. Toss when the wind gusts
## and the chaff blows away; in still air it just falls back in.

const GUST := 0.6

var floor_: ThreshingFloor
var item: StringName       ## The unwinnowed grain being cleaned, e.g. barley_chaff.
var quality: int = 0
var _loaded := false       ## One measure is in the basket (taken from the pack).
var _clean := 0.0
var _lift := 0.0
var _holding := false
var _last := ""


func _init(f: ThreshingFloor, chaff_item: StringName) -> void:
	floor_ = f
	item = chaff_item
	hint = "Hold to lift, release to toss. Toss when the wind gusts (watch the pennant)."


func _load_next() -> bool:
	var q := player.inventory.take_one(item, true)
	if q < -1:
		return false
	quality = q
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
		player.inventory.add(clean_item, 1, quality)
		Sfx.play("grain", -4.0)
		player.say("A measure of clean %s." % clean_item)
		_loaded = false
		if not _load_next():
			player.say("All your grain is winnowed. Sell it at the produce cart.")
			stop()


func update(delta: float) -> void:
	_lift = move_toward(_lift, 1.0 if _holding else 0.0, delta * 2.5)
	if _holding:
		player.viewmodel.pose_lift(_lift)


func _on_stop() -> void:
	if _loaded:
		player.inventory.add(item, 1, quality)
		_loaded = false
	player.viewmodel.pose_rest()
	var g := player.viewmodel.held_model()
	if g:
		var grain := g.find_child("grain", true, false) as Node3D
		if grain:
			grain.visible = false


func draw(c: Control, center: Vector2) -> void:
	Minigame.draw_meter(c, center, floor_.wind, GUST, 1.0, "Wind   ·   %s" % _last, Color(0.55, 0.75, 0.9))
	Minigame.draw_fill(c, center, _clean, "Clean", Color(0.85, 0.72, 0.4))
