class_name ThreshGame
extends Minigame
## Threshing: swing the flail yourself. Move the mouse up to raise it overhead, then sweep it
## down hard: the swingle (the loose beater) whips over and cracks onto the sheaf. The faster
## the downswing, the harder the blow; a lazy swing barely loosens any grain.

const RAISED := 0.6          ## How high (0..1) the flail must go before a blow counts.
const STRIKE := 0.1          ## Below this height on the way down, the swingle hits the sheaf.
const SENSITIVITY := 0.0035  ## Height per pixel of mouse movement.
const BLOWS_PER_SHEAF := 3.0 ## Hard blows to thresh one sheaf.

var floor_: ThreshingFloor
var height := 0.35           ## 0 = beater on the floor, 0.35 = resting, 1 = overhead.
var _prev_height := 0.35
var _peak := 0.35            ## Highest point since the last blow.
var _down_speed := 0.0       ## Fastest downswing (height/second) since the last blow.
var _swing := 2.4            ## Swingle angle on its leather link (radians); animates the whip.
var _swing_vel := 0.0
var _last := ""
var _last_strength := 0.0


func _init(f: ThreshingFloor) -> void:
	floor_ = f
	hint = "Move the mouse UP to raise the flail, then swing it DOWN hard onto the sheaf."


func mouse_motion(rel: Vector2) -> void:
	height = clampf(height - rel.y * SENSITIVITY, 0.0, 1.0)


func update(delta: float) -> void:
	if delta <= 0.0:
		return
	var v := (height - _prev_height) / delta     # positive going up
	_peak = maxf(_peak, height)
	if v < 0.0:
		_down_speed = maxf(_down_speed, -v)
	# The swingle lags behind the handle and whips over on a fast downswing.
	var rest := lerpf(2.4, 2.9, height)
	_swing_vel += (-60.0 * (_swing - rest) - 6.0 * _swing_vel + v * 9.0) * delta
	_swing = clampf(_swing + _swing_vel * delta, 0.2, 3.1)
	if _prev_height >= STRIKE and height < STRIKE and v < 0.0:
		_blow()
	_prev_height = height
	player.viewmodel.pose_flail(height, _swing)


func _blow() -> void:
	if _peak < RAISED:
		_last = "Raise it higher first"
		_last_strength = 0.0
		_reset_swing()
		return
	var strength := clampf((_down_speed - 1.2) / 3.5, 0.0, 1.0)
	_last_strength = strength
	if strength >= 0.75:
		_last = "Crack! A hard blow"
	elif strength >= 0.35:
		_last = "A fair blow"
	else:
		_last = "Too gentle: swing down harder"
		strength = maxf(strength, 0.1)
	player.needs.exert(0.4 + strength * 0.5)
	var pos := floor_.sheaf_position()
	Sfx.play_at("thresh", pos, -12.0 + strength * 12.0)
	Fx.burst(player, pos + Vector3(0, 0.15, 0), Color(0.85, 0.72, 0.42), int(6 + strength * 18), 1.0 + strength * 2.0, Vector3.UP, 60.0, 0.02)
	_swing_vel = 25.0   # the beater bounces off the sheaf
	var done := floor_.beat(strength / BLOWS_PER_SHEAF, player)
	if done != "":
		player.say(done)
	_reset_swing()
	if not floor_.has_sheaves():
		player.say("All threshed. Now winnow the grain on the floor with your basket.")
		stop()


func _reset_swing() -> void:
	_peak = height
	_down_speed = 0.0


func _on_stop() -> void:
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	# A height gauge to the left: raise into the marked band, then bring it down.
	var r := Rect2(center + Vector2(-230, -90), Vector2(16, 180))
	c.draw_rect(r.grow(3), Color(0.12, 0.09, 0.06, 0.85))
	c.draw_rect(r, Color(0.32, 0.25, 0.17))
	var band_top := r.position.y
	var band_h := r.size.y * (1.0 - RAISED)
	c.draw_rect(Rect2(r.position.x, band_top, r.size.x, band_h), Color(0.45, 0.75, 0.3, 0.6))
	var y := r.end.y - r.size.y * height
	c.draw_rect(Rect2(r.position.x - 5, y - 2, r.size.x + 10, 4), Color(1, 0.95, 0.8))
	var font := ThemeDB.fallback_font
	c.draw_string(font, r.position + Vector2(-46, 14), "raise", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.85))
	c.draw_string(font, Vector2(r.position.x - 46, r.end.y), "swing", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.85))
	# Last blow and how far the sheaf has come.
	Minigame.draw_meter(c, center, floor_.current_progress(), 0.0, 0.0,
		"%s   ·   sheaf %d%%   ·   %d left" % [_last if _last != "" else "Raise the flail", roundi(floor_.current_progress() * 100.0), floor_.sheaves.size()])
