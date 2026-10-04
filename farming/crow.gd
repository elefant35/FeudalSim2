class_name Crow
extends Node3D
## A crow that flies in to eat fresh seed from a plot. Walk up to it and it flies off.

enum State { ARRIVING, PECKING, LEAVING }

const SPEED := 6.0
const SCARE_DISTANCE := 5.5
const PECK_MINUTES := 12.0

var plot: FarmPlot
var tame := false   ## Dev screenshots: don't fly off when approached.
var state := State.ARRIVING
var _model: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _target := Vector3.ZERO
var _t := 0.0
var _peck_timer := 0.0
var _hop := 0.0


func _ready() -> void:
	_model = Models.make(&"crow")
	_model.scale = Vector3.ONE * 1.3
	add_child(_model)
	_wing_l = _model.find_child("wing_l", true, false)
	_wing_r = _model.find_child("wing_r", true, false)
	var spot := Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8))
	_target = plot.to_world(spot, 0.08)
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 40.0
	global_position = _target + away + Vector3(0, 14, 0)
	Clock.minutes_passed.connect(_on_minutes)
	Sfx.play_at("crow", global_position, 2.0)


func _process(delta: float) -> void:
	_t += delta
	var player: Player = get_tree().get_first_node_in_group("player")
	if not tame and state != State.LEAVING and player and player.global_position.distance_to(global_position) < SCARE_DISTANCE and state == State.PECKING:
		flee()
	match state:
		State.ARRIVING:
			_fly_towards(_target, delta)
			if global_position.distance_to(_target) < 0.15:
				state = State.PECKING
				global_position = _target
				rotation.x = 0.0
		State.PECKING:
			_flap(0.0)
			_hop -= delta
			if _hop <= 0.0:
				_hop = randf_range(0.4, 1.6)
				var t := create_tween()
				t.tween_property(_model, "rotation:x", 0.6, 0.08)
				t.tween_property(_model, "rotation:x", 0.0, 0.12)
				if randf() < 0.3:
					rotation.y += randf_range(-1.2, 1.2)
			if not plot.state.is_sown_not_sprouted():
				flee()
		State.LEAVING:
			_fly_towards(_target, delta)
			if global_position.distance_to(_target) < 1.0:
				queue_free()


func _fly_towards(p: Vector3, delta: float) -> void:
	var d := p - global_position
	var step := minf(d.length(), SPEED * delta)
	global_position += d.normalized() * step
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)
	_flap(1.0)


## Flapping in flight; folded against the body when perched (amount 0).
func _flap(amount: float) -> void:
	var a := sin(_t * 22.0) * 0.9 * amount if amount > 0.0 else 1.25
	if _wing_l:
		_wing_l.rotation.z = a
	if _wing_r:
		_wing_r.rotation.z = -a


func _on_minutes(m: float) -> void:
	if state != State.PECKING:
		return
	_peck_timer += m
	if _peck_timer >= PECK_MINUTES:
		_peck_timer = 0.0
		plot.state.crow_peck(plot.field.rng)
		plot.refresh()
		if randf() < 0.4:
			Sfx.play_at("crow", global_position)


func flee() -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	Sfx.play_at("crow", global_position, 2.0)
	Sfx.play_at("flap", global_position)
	_target = global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 40.0 + Vector3(0, 18, 0)
