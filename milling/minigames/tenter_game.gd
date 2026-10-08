class_name TenterGame
extends Minigame
## Tentering: the lever that lifts or lowers the runner stone. Move the mouse up to open the
## stones (coarser, quicker, cooler), down to close them (finer, slower, hotter; too close and the
## bran is ground in). The meal at the spout tells you how it's going, a moment after each change;
## the faster the sails turn, the wider the stones must be to keep it cool. Grind as wide as the
## meal stays right: that's the quickest.

const SENSITIVITY := 0.0018   ## Gap per pixel of mouse movement.
const READ_EVERY := 0.8       ## Seconds between feeling the meal.

var mill: PostMill
var _reading := ""
var _pace := 0.0
var _t := 0.0


func _init(m: PostMill) -> void:
	mill = m
	hint = "Mouse UP opens the stones (quicker, coarser), DOWN closes them (finer, slower; too close grinds the bran in or scorches). Find the widest gap where the meal is just right. E or right-click when done."


func _on_start() -> void:
	_read()


func mouse_motion(rel: Vector2) -> void:
	mill.set_gap(mill.gap - rel.y * SENSITIVITY)


func update(delta: float) -> void:
	_t += delta
	if _t >= READ_EVERY:
		_t = 0.0
		_read()


func _read() -> void:
	_reading = mill.feel_short() if mill.is_grinding() else "no meal coming"
	_pace = mill.pace() if mill.is_grinding() else 0.0


func draw(c: Control, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(center + Vector2(-230, -90), Vector2(16, 180))
	c.draw_rect(r.grow(3), Color(0.12, 0.09, 0.06, 0.85))
	c.draw_rect(r, Color(0.32, 0.25, 0.17))
	var y := r.end.y - r.size.y * mill.gap
	c.draw_rect(Rect2(r.position.x - 5, y - 2, r.size.x + 10, 4), Color(1, 0.95, 0.8))
	c.draw_string(font, r.position + Vector2(-50, 14), "wide", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.85))
	c.draw_string(font, Vector2(r.position.x - 50, r.end.y), "close", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.85))
	var col := Color(0.6, 0.9, 0.45) if _reading == "just right" else (Color(1.0, 0.55, 0.35) if _reading in ["hot", "warm", "dusty"] else Color(1, 0.9, 0.6))
	var lines := [
		"Stones %s   ·   sails %s" % [mill.gap_text(), mill.speed_text()],
		"The meal feels: %s" % _reading,
		"Pace: about %.1f sacks an hour" % _pace if _pace > 0.0 else "Pace: not grinding",
	]
	for i in lines.size():
		c.draw_string(font, center + Vector2(-220, 92 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 440, 20, col if i == 1 else Color(1, 0.96, 0.85))
