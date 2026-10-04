class_name Minigame
extends RefCounted
## A short hands-on task (a hoe strike, winding a well, tugging a weed). While one runs, the
## player's mouse buttons (and optionally mouse movement) go to it, and the HUD calls `draw`.
## Right-click or E always stops it.

signal finished

var player: Player
var locks_movement: bool = true
var locks_look: bool = true
var hint: String = ""
var done: bool = false


func start(p: Player) -> void:
	player = p
	_on_start()


func stop() -> void:
	if done:
		return
	done = true
	_on_stop()
	finished.emit()


# Overridables --------------------------------------------------------------------------------

func _on_start() -> void:
	pass


func _on_stop() -> void:
	pass


func press() -> void:
	pass


func release() -> void:
	pass


## Only delivered while `locks_look` is true.
func mouse_motion(_rel: Vector2) -> void:
	pass


func update(_delta: float) -> void:
	pass


## Draw the HUD overlay. `c` is a full-screen Control; `center` is the screen centre.
func draw(_c: Control, _center: Vector2) -> void:
	pass


# Drawing helpers shared by minigames ---------------------------------------------------------

## A horizontal meter with a highlighted zone and a marker, centred under the crosshair.
static func draw_meter(c: Control, center: Vector2, value: float, zone_from: float, zone_to: float,
		label: String, zone_color: Color = Color(0.45, 0.75, 0.3)) -> void:
	var w := 320.0
	var h := 18.0
	var r := Rect2(center + Vector2(-w / 2, 70), Vector2(w, h))
	c.draw_rect(r.grow(3), Color(0.12, 0.09, 0.06, 0.85))
	c.draw_rect(r, Color(0.32, 0.25, 0.17))
	c.draw_rect(Rect2(r.position + Vector2(w * zone_from, 0), Vector2(w * (zone_to - zone_from), h)), zone_color)
	var x := r.position.x + w * clampf(value, 0.0, 1.0)
	c.draw_rect(Rect2(x - 2, r.position.y - 5, 4, h + 10), Color(0.98, 0.94, 0.82))
	if label != "":
		c.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, -8), label, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 0.96, 0.85))


## A vertical fill bar to the right of the crosshair.
static func draw_fill(c: Control, center: Vector2, value: float, label: String, color: Color,
		target_from: float = -1.0, target_to: float = -1.0) -> void:
	var r := Rect2(center + Vector2(60, -80), Vector2(16, 160))
	c.draw_rect(r.grow(3), Color(0.12, 0.09, 0.06, 0.85))
	c.draw_rect(r, Color(0.32, 0.25, 0.17))
	if target_from >= 0.0:
		var ty := r.end.y - r.size.y * target_to
		c.draw_rect(Rect2(r.position.x - 4, ty, r.size.x + 8, r.size.y * (target_to - target_from)), Color(1, 1, 1, 0.18))
	var fh := r.size.y * clampf(value, 0.0, 1.0)
	c.draw_rect(Rect2(r.position.x, r.end.y - fh, r.size.x, fh), color)
	c.draw_string(ThemeDB.fallback_font, r.position + Vector2(26, r.size.y / 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.96, 0.85))
