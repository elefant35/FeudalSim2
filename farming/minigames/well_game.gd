class_name WellGame
extends Minigame
## Drawing water: hold the button and circle the mouse to wind the crank. Let go and the
## bucket slowly slips back down.

const TURNS_NEEDED := 3.0

var well: Well
var _holding := false
var _progress := 0.0       ## 0 = bucket at the water, 1 = at the top
var _angle := 0.0
var _last_dir := Vector2.ZERO
var _creak := 0.0


func _init(w: Well) -> void:
	well = w
	hint = "Hold and circle the mouse to wind the bucket up."


func press() -> void:
	_holding = true


func release() -> void:
	_holding = false


func mouse_motion(rel: Vector2) -> void:
	if not _holding or rel.length() < 2.0:
		return
	var dir := rel.normalized()
	if _last_dir != Vector2.ZERO:
		var turn := absf(_last_dir.angle_to(dir))
		if turn < 1.2:
			_angle += turn
			_progress += turn / (TAU * TURNS_NEEDED) * player.needs.speed_factor()
			_creak += turn
			if _creak > PI * 0.5:
				_creak = 0.0
				Sfx.play_at("crank", well.global_position + Vector3(0, 1.6, 0), -6.0, 0.15)
	_last_dir = dir


func update(delta: float) -> void:
	if not _holding:
		_progress = maxf(0.0, _progress - delta * 0.06)
		_last_dir = Vector2.ZERO
	well.set_crank(_angle, _progress)
	player.viewmodel.pose_crank(_angle)
	if _progress >= 1.0:
		player.set_bucket_water(1.0)
		player.needs.exert(1.0)
		Sfx.play_at("splash", well.global_position + Vector3(0, 1.0, 0))
		player.say("You fill your bucket.")
		stop()


func _on_stop() -> void:
	well.lower_bucket()
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	Minigame.draw_fill(c, center, _progress, "Bucket rising", Color(0.45, 0.6, 0.85))
	var r := 38.0
	c.draw_arc(center, r, 0, TAU, 32, Color(1, 1, 1, 0.25), 3.0)
	var p := center + Vector2(cos(_angle), sin(_angle)) * r
	c.draw_circle(p, 6.0, Color(1, 0.95, 0.8))
