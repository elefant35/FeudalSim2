class_name ThreshGame
extends Minigame
## Threshing: beat the sheaves with the flail in rhythm. A ring closes on the target; click
## as it meets it. Each sheaf takes a few good blows.

const BEAT := 0.9           ## Seconds per beat.
const BLOWS_PER_SHEAF := 4.0

var floor_: ThreshingFloor
var _t := 0.0
var _swung_this_beat := false
var _last := ""
var _streak := 0


func _init(f: ThreshingFloor) -> void:
	floor_ = f
	hint = "Click as the ring closes on the circle. Keep the rhythm."


func _phase() -> float:
	return fmod(_t, BEAT) / BEAT


func update(delta: float) -> void:
	var prev := _phase()
	_t += delta
	if _phase() < prev:
		if not _swung_this_beat:
			_streak = 0
		_swung_this_beat = false
	if not _swung_this_beat:
		player.viewmodel.pose_raise(_phase() * 0.9)


func press() -> void:
	if _swung_this_beat:
		return
	_swung_this_beat = true
	var off := absf(_phase() - 1.0) if _phase() > 0.5 else _phase()   # distance to the beat
	var value := 0.0
	if off < 0.09:
		value = 1.0
		_streak += 1
		_last = "Clean blow" + (" ×%d" % _streak if _streak > 1 else "")
	elif off < 0.2:
		value = 0.5
		_streak = 0
		_last = "Off the beat"
	else:
		_streak = 0
		_last = "Missed the rhythm"
	player.viewmodel.play_strike()
	player.needs.exert(0.7)
	var pos := floor_.sheaf_position()
	Sfx.play_at("thresh", pos, -2.0 if value > 0.0 else -10.0)
	if value > 0.0:
		Fx.burst(player, pos + Vector3(0, 0.15, 0), Color(0.85, 0.72, 0.42), int(10 * value) + 4, 2.0, Vector3.UP, 60.0, 0.02)
	var done := floor_.beat(value / BLOWS_PER_SHEAF, player)
	if done != "":
		player.say(done)
	if not floor_.has_sheaves():
		player.say("All the grain is threshed. Winnow it to clean out the chaff.")
		stop()


func _on_stop() -> void:
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	var target := 26.0
	var ring := lerpf(90.0, target, _phase())
	c.draw_arc(center, target, 0, TAU, 32, Color(0.45, 0.75, 0.3), 4.0)
	c.draw_arc(center, ring, 0, TAU, 40, Color(1, 0.95, 0.8, 0.85), 3.0)
	c.draw_string(ThemeDB.fallback_font, center + Vector2(-160, 120), "%s   ·   sheaf %d%%" % [_last, roundi(floor_.current_progress() * 100.0)],
		HORIZONTAL_ALIGNMENT_CENTER, 320, 16, Color(1, 0.96, 0.85))
