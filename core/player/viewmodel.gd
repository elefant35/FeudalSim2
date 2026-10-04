class_name Viewmodel
extends Node3D
## First-person hands and the held item. Actions are short tweened animations layered over a
## per-tool resting pose and a walking bob. Poses are offsets (position, euler rotation) per arm.

const RIGHT_BASE_POS := Vector3(0.24, -0.30, -0.42)
const LEFT_BASE_POS := Vector3(-0.26, -0.34, -0.44)
const BASE_ROT := Vector3(0.12, 0.0, 0.0)

## How each tool sits in the hand (rotation of the model at the grip).
const GRIP_ROT := {
	&"hoe": Vector3(-1.05, 0.0, 0.45), &"flail": Vector3(-1.0, 0.0, 0.45), &"sickle": Vector3(-0.5, 0.0, 0.2),
	&"bucket": Vector3(0.0, 0.3, 0.0), &"winnowing_basket": Vector3(0.0, 0.0, 0.0), &"seed_pouch": Vector3(0.2, 0, 0),
	&"scarecrow": Vector3(-0.3, 0.0, 0.3),
}
const GRIP_POS := {
	&"hoe": Vector3(0, 0, 0.1), &"flail": Vector3(0, 0, 0.1), &"winnowing_basket": Vector3(-0.2, -0.05, -0.05),
	&"scarecrow": Vector3(0, -0.4, 0),
}

## Resting offsets per held item: [right_pos, right_rot, left_pos, left_rot, left_visible]
const HOLD_POSES := {
	&"hands": [Vector3(0.02, -0.14, 0.06), Vector3(0.2, 0, 0), Vector3(-0.02, -0.14, 0.06), Vector3(0.2, 0, 0), true],
	&"hoe": [Vector3(0.0, -0.04, 0.05), Vector3(0.25, 0.25, -0.1), Vector3(0.18, -0.12, -0.05), Vector3(0.3, 0.3, 0), true],
	&"bucket": [Vector3(0.02, -0.12, 0.05), Vector3(-0.1, 0, 0), Vector3.ZERO, Vector3.ZERO, false],
	&"sickle": [Vector3(0, -0.02, 0), Vector3(0.1, 0.1, -0.2), Vector3.ZERO, Vector3.ZERO, true],
	&"flail": [Vector3(0.0, -0.04, 0.04), Vector3(0.4, 0.2, -0.1), Vector3(0.16, -0.1, -0.04), Vector3(0.4, 0.2, 0), true],
	&"winnowing_basket": [Vector3(-0.1, -0.08, -0.05), Vector3(0.1, 0, 0), Vector3(0.1, -0.08, -0.05), Vector3(0.1, 0, 0), true],
	&"seed": [Vector3(0, -0.04, 0), Vector3(0.1, 0, 0), Vector3(0.04, -0.06, 0.02), Vector3.ZERO, true],
	&"scarecrow": [Vector3(0.0, -0.05, 0.05), Vector3(0.1, 0.4, 0), Vector3.ZERO, Vector3.ZERO, false],
}

var right_arm := Node3D.new()
var left_arm := Node3D.new()
var grip := Node3D.new()        ## Right-hand attachment point.
var left_grip := Node3D.new()

# Animated offsets (tweens drive these).
var r_pos := Vector3.ZERO
var r_rot := Vector3.ZERO
var l_pos := Vector3.ZERO
var l_rot := Vector3.ZERO

var _hold: Array = HOLD_POSES[&"hands"]
var _held_id: StringName = &""
var _held_model: Node3D = null
var _walk: float = 0.0
var _bob_t: float = 0.0
var _tween: Tween = null
var _left_food: Node3D = null
var _bucket_fill: float = 0.0


func _ready() -> void:
	add_child(right_arm)
	right_arm.add_child(Models.make(&"fp_arm"))
	add_child(left_arm)
	left_arm.add_child(Models.make(&"fp_arm_l"))
	grip.position = Vector3(0, 0.0, -0.36)
	right_arm.add_child(grip)
	left_grip.position = Vector3(0, 0.0, -0.36)
	left_arm.add_child(left_grip)
	_set_layers(self)


func _process(delta: float) -> void:
	_bob_t += delta * (6.0 + 4.0 * _walk)
	var bob := Vector3(sin(_bob_t) * 0.012, absf(cos(_bob_t)) * 0.016, 0) * _walk
	var idle := Vector3(0, sin(Time.get_ticks_msec() / 900.0) * 0.003, 0)
	right_arm.position = RIGHT_BASE_POS + _hold[0] + r_pos + bob + idle
	right_arm.rotation = BASE_ROT + _hold[1] + r_rot
	left_arm.position = LEFT_BASE_POS + _hold[2] + l_pos + bob * Vector3(-1, 1, 1) + idle
	left_arm.rotation = BASE_ROT + _hold[3] + l_rot
	left_arm.visible = _hold[4] or _left_food != null


func set_walk(amount: float) -> void:
	_walk = lerpf(_walk, clampf(amount, 0.0, 1.0), 0.15)


func set_held(id: StringName) -> void:
	if id == _held_id:
		return
	_held_id = id
	if _held_model:
		_held_model.queue_free()
		_held_model = null
	var it := Items.item(id)
	var pose_key: StringName = &"seed" if it and it.kind == ItemData.Kind.SEED else id
	_hold = HOLD_POSES.get(pose_key, HOLD_POSES[&"hands"])
	if id != Player.HANDS:
		var model_id: StringName = &"seed_pouch" if pose_key == &"seed" else id
		_held_model = Models.make(model_id)
		_held_model.rotation = GRIP_ROT.get(model_id, Vector3.ZERO)
		_held_model.position = GRIP_POS.get(model_id, Vector3.ZERO)
		if model_id == &"scarecrow":
			_held_model.scale = Vector3.ONE * 0.5
		grip.add_child(_held_model)
		_set_layers(_held_model)
		if id == &"bucket":
			set_bucket_fill(_bucket_fill)
		var basket_grain := _held_model.find_child("grain", true, false) as Node3D
		if basket_grain:
			basket_grain.visible = false
	# Swap animation: dip out and back up.
	r_pos = Vector3(0, -0.25, 0.05)
	_play().tween_property(self, "r_pos", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows or hides the water surface in the held bucket.
func set_bucket_fill(amount: float) -> void:
	_bucket_fill = amount
	if _held_model and _held_id == &"bucket":
		var w := _held_model.find_child("water", true, false) as Node3D
		if w:
			w.visible = amount > 0.0


func held_model() -> Node3D:
	return _held_model


## Keeps the viewmodel from clipping into the world: render it on its own layer, no shadows.
func _set_layers(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_layers(c)


func _play() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


func _reset_to(t: Tween, dur: float) -> void:
	t.set_parallel(true)
	t.tween_property(self, "r_pos", Vector3.ZERO, dur)
	t.tween_property(self, "r_rot", Vector3.ZERO, dur)
	t.tween_property(self, "l_pos", Vector3.ZERO, dur)
	t.tween_property(self, "l_rot", Vector3.ZERO, dur)


# --- Continuous poses (driven every frame by a minigame) ------------------------------------

## Hoe/flail wind-up: 0 resting, 1 fully raised overhead.
func pose_raise(amount: float) -> void:
	r_rot = Vector3(-1.1 * amount, 0, 0.2 * amount)
	r_pos = Vector3(0, 0.22 * amount, 0.12 * amount)
	l_rot = r_rot
	l_pos = Vector3(0, 0.18 * amount, 0.1 * amount)


## Tugging a weed or plant: hands reach down/forward and strain back.
func pose_pull(reach: float, strain: float) -> void:
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006 * strain
	r_pos = Vector3(-0.08, -0.12 * reach, -0.1 * reach + 0.12 * strain) + shake
	r_rot = Vector3(-0.6 * reach + 0.3 * strain, 0, 0)
	l_pos = Vector3(0.08, -0.12 * reach, -0.1 * reach + 0.12 * strain) - shake
	l_rot = r_rot


## Tipping the bucket: 0 upright, 1 fully poured.
func pose_pour(amount: float) -> void:
	r_rot = Vector3(-0.2 * amount, 0, 1.3 * amount)
	r_pos = Vector3(-0.05 * amount, 0.08 * amount, -0.1 * amount)


## Turning a crank: angle in radians.
func pose_crank(angle: float) -> void:
	r_pos = Vector3(cos(angle) * 0.07, sin(angle) * 0.07, -0.12)
	r_rot = Vector3(-0.3, 0, 0)


## Lifting the winnowing basket: 0 low, 1 high.
func pose_lift(amount: float) -> void:
	r_pos = Vector3(0, 0.15 * amount, -0.05 * amount)
	l_pos = r_pos
	r_rot = Vector3(-0.2 * amount, 0, 0)
	l_rot = r_rot


func pose_rest(dur: float = 0.2) -> void:
	_reset_to(_play(), dur)


# --- One-shot actions -----------------------------------------------------------------------

## Hoe or flail coming down hard.
func play_strike() -> void:
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "r_rot", Vector3(0.75, 0, -0.1), 0.09).set_ease(Tween.EASE_IN)
	t.tween_property(self, "r_pos", Vector3(0, -0.12, -0.12), 0.09).set_ease(Tween.EASE_IN)
	t.tween_property(self, "l_rot", Vector3(0.75, 0, 0), 0.09).set_ease(Tween.EASE_IN)
	t.tween_property(self, "l_pos", Vector3(0, -0.1, -0.1), 0.09).set_ease(Tween.EASE_IN)
	t.chain().tween_interval(0.08)
	_reset_to(t.chain(), 0.3)


## Broadcast sowing: right hand sweeps out and opens.
func play_throw() -> void:
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "r_pos", Vector3(0.1, -0.05, 0.12), 0.12)
	t.tween_property(self, "r_rot", Vector3(0.3, -0.5, 0), 0.12)
	t.chain().set_parallel(true)
	t.tween_property(self, "r_pos", Vector3(-0.18, 0.05, -0.22), 0.16).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "r_rot", Vector3(-0.3, 0.7, 0), 0.16).set_ease(Tween.EASE_OUT)
	_reset_to(t.chain(), 0.25)


## Sickle sweep from right to left.
func play_sweep() -> void:
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "r_pos", Vector3(-0.32, -0.08, -0.12), 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "r_rot", Vector3(0.5, 1.1, -0.4), 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "l_pos", Vector3(0.05, -0.05, -0.05), 0.18)
	_reset_to(t.chain(), 0.3)


## Quick reach forward and pinch (caterpillars, binding).
func play_pick() -> void:
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "r_pos", Vector3(-0.06, -0.08, -0.18), 0.12)
	t.tween_property(self, "r_rot", Vector3(-0.5, 0.2, 0), 0.12)
	_reset_to(t.chain(), 0.2)


## Toss: basket jerks up then drops.
func play_toss() -> void:
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "r_pos", Vector3(0, 0.2, -0.1), 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "l_pos", Vector3(0, 0.2, -0.1), 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "r_rot", Vector3(-0.35, 0, 0), 0.1)
	t.tween_property(self, "l_rot", Vector3(-0.35, 0, 0), 0.1)
	_reset_to(t.chain(), 0.35)


## Bring food to the mouth with the left hand.
func play_eat(id: StringName) -> void:
	if _left_food:
		_left_food.queue_free()
	_left_food = Models.make(id)
	_left_food.scale = Vector3.ONE * 0.6
	left_grip.add_child(_left_food)
	_set_layers(_left_food)
	var t := _play()
	t.set_parallel(true)
	t.tween_property(self, "l_pos", Vector3(0.2, 0.2, 0.15), 0.25)
	t.tween_property(self, "l_rot", Vector3(-0.6, -0.4, 0), 0.25)
	t.chain().tween_interval(0.5)
	t.chain().tween_callback(func() -> void:
		if _left_food:
			_left_food.queue_free()
			_left_food = null)
	_reset_to(t.chain(), 0.25)
