class_name Viewmodel
extends Node3D
## First-person hands and the held tool.
##
## The tool's pose (where it is and which way it points) is what gets animated. Every frame the
## hands are put on the tool's grip points and the arms reach back to fixed shoulders, so hands
## and tool always line up. A free hand (one-handed tools, bare hands) has its own resting spot
## plus an animated offset for actions like throwing seed or pulling weeds.
##
## Coordinates are camera space in metres; the whole viewmodel is drawn at a third of real size
## (and a third as far away), which looks identical but keeps tools from poking into the world.

const SHOULDER_R := Vector3(0.36, -0.62, 0.14)
const SHOULDER_L := Vector3(-0.36, -0.62, 0.14)
const HAND_IN_ARM := Vector3(0, 0, -0.33)   ## Palm centre in the arm model.
const HAND_REST_R := Vector3(0.22, -0.46, -0.42)    ## A free hand, mostly out of view.
const HAND_REST_L := Vector3(-0.22, -0.48, -0.44)
const HAND_SHOW_R := Vector3(0.2, -0.3, -0.44)      ## Bare hands, visible at the bottom.
const HAND_SHOW_L := Vector3(-0.2, -0.31, -0.45)

var right_arm := Node3D.new()
var left_arm := Node3D.new()
var r_off := Vector3.ZERO   ## Animated offsets for free hands.
var l_off := Vector3.ZERO

var _specs: Dictionary = {}
var _spec: Dictionary = {}
var _held_id: StringName = &""
var _model: Node3D = null
var _swingle: Node3D = null
var _xf := Transform3D.IDENTITY           ## Current tool pose.
var _swing_angle := 2.4                   ## Flail swingle droop (radians).
var _tool_tween: Tween
var _hand_tween: Tween
var _walk := 0.0
var _bob_t := 0.0
var _bucket_fill := 0.0
var _left_food: Node3D = null
var _carry_id: StringName = &""
var _carry_count := 0


static func _basis(up: Vector3, front: Vector3, s: float = 1.0) -> Basis:
	var y := up.normalized()
	var f := (front - y * front.dot(y)).normalized()
	var z := -f
	var x := y.cross(z)
	return Basis(x, y, z).scaled(Vector3.ONE * s)


static func _pose(pos: Vector3, up: Vector3, front: Vector3, s: float = 1.0) -> Transform3D:
	return Transform3D(_basis(up, front, s), pos)


func _build_specs() -> void:
	# grip_r / grip_l: where each hand holds the model (model space); absent = a free hand.
	# roll: twists the forearm so the fist wraps the handle.
	var hoe_like := {
		"rest": _pose(Vector3(0.24, -0.29, -0.52), Vector3(-0.2, 0.75, -0.62), Vector3(0, -0.6, -0.8)),
		"raised": _pose(Vector3(0.24, -0.26, -0.42), Vector3(-0.1, 0.9, 0.35), Vector3(0, 0, -1)),
		"struck": _pose(Vector3(0.18, -0.4, -0.6), Vector3(-0.1, -0.15, -1), Vector3(0, -1, 0)),
	}
	_specs = {
		&"hoe": {"model": &"hoe", "grip_r": Vector3(0, 0, 0), "grip_l": Vector3(0, 0.38, 0), "roll_r": 1.3, "roll_l": -1.3, "poses": hoe_like},
		&"flail": {"model": &"flail", "grip_r": Vector3(0, 0, 0), "grip_l": Vector3(0, 0.36, 0), "roll_r": 1.3, "roll_l": -1.3, "poses": hoe_like},
		&"sickle": {"model": &"sickle", "grip_r": Vector3(0, 0, 0), "roll_r": 1.4, "poses": {
			"rest": _pose(Vector3(0.24, -0.3, -0.46), Vector3(0.05, 0.9, -0.4), Vector3(-0.4, 0, -1)),
			"sweep_a": _pose(Vector3(0.42, -0.26, -0.5), Vector3(0.6, 0.35, -0.7), Vector3(-1, 0, 0)),
			"sweep_b": _pose(Vector3(-0.22, -0.32, -0.56), Vector3(-0.6, 0.15, -0.75), Vector3(-1, -0.2, 0.3)),
		}},
		&"bucket": {"model": &"bucket", "grip_r": Vector3(0, 0, 0), "roll_r": 0.2, "poses": {
			"rest": _pose(Vector3(0.24, -0.16, -0.46), Vector3(0, 1, 0), Vector3(0, 0, -1)),
			"pour": _pose(Vector3(0.14, -0.1, -0.58), Vector3(0.15, 0.1, -1), Vector3(0, -1, 0)),
		}},
		&"winnowing_basket": {"model": &"winnowing_basket", "grip_r": Vector3(0.32, 0.06, 0), "grip_l": Vector3(-0.32, 0.06, 0),
			"roll_r": -1.2, "roll_l": 1.2, "poses": {
			"rest": _pose(Vector3(0, -0.45, -0.95), Vector3(0, 1, 0.5), Vector3(0, 0, -1)),
			"lifted": _pose(Vector3(0, -0.34, -1.0), Vector3(0, 1, 0.3), Vector3(0, 0, -1)),
			"toss": _pose(Vector3(0, -0.12, -1.05), Vector3(0, 1, -0.3), Vector3(0, 0, -1)),
		}},
		&"seed_pouch": {"model": &"seed_pouch", "grip_l": Vector3(0, 0.02, 0), "roll_l": 0.4, "poses": {
			"rest": _pose(Vector3(-0.2, -0.32, -0.46), Vector3(0, 1, 0.2), Vector3(0, 0, -1)),
		}},
		&"scarecrow": {"model": &"scarecrow", "grip_r": Vector3(0, 0.9, 0), "roll_r": 1.4, "poses": {
			"rest": _pose(Vector3(0.32, -0.72, -0.8), Vector3(-0.15, 1, -0.25), Vector3(0, 0, -1), 0.45),
		}},
		&"hands": {"poses": {"rest": Transform3D.IDENTITY}},
		# An armful of produce, held in front with palms up underneath it.
		&"carrying": {"grip_r": Vector3(0.2, 0.02, 0.02), "grip_l": Vector3(-0.2, 0.02, 0.02), "roll_r": -1.5, "roll_l": 1.5, "poses": {
			"rest": _pose(Vector3(0, -0.45, -0.62), Vector3(0, 1, 0.15), Vector3(0, 0, -1)),
		}},
		# Walking between the handcart's shafts, a handle end in each fist, the shafts running
		# back past your hips to the cart behind you.
		&"pulling": {"grip_r": Vector3(0.3, 0, 0), "grip_l": Vector3(-0.3, 0, 0), "roll_r": 1.5, "roll_l": -1.5, "poses": {
			"rest": _pose(Vector3(0, -0.33, -0.48), Vector3(0, 1, 0), Vector3(0, 0, -1)),
			"jerk": _pose(Vector3(0, -0.37, -0.32), Vector3(0, 1, 0.2), Vector3(0, 0, -1)),
		}},
	}


func _ready() -> void:
	scale = Vector3.ONE * 0.33
	_build_specs()
	add_child(right_arm)
	right_arm.add_child(Models.make(&"fp_arm"))
	add_child(left_arm)
	left_arm.add_child(Models.make(&"fp_arm_l"))
	_spec = _specs[&"hands"]
	_no_shadows(self)


func _process(delta: float) -> void:
	_bob_t += delta * (6.0 + 4.0 * _walk)
	var bob := Vector3(sin(_bob_t) * 0.012, absf(cos(_bob_t)) * 0.016, 0) * _walk
	bob.y += sin(Time.get_ticks_msec() / 900.0) * 0.003
	var xf := _xf.translated(bob)
	if _model:
		_model.transform = xf
	if _swingle:
		_swingle.rotation.x = _swing_angle
	var bare := _held_id == Player.HANDS or _held_id == &""
	var rest_r := HAND_SHOW_R if bare else HAND_REST_R
	var rest_l := HAND_SHOW_L if bare else HAND_REST_L
	if _spec.has("hand_r"):
		rest_r = _spec.hand_r
		rest_l = _spec.hand_l
	var target_r: Vector3 = xf * (_spec.grip_r as Vector3) if _model and _spec.has("grip_r") else rest_r + r_off + bob
	var target_l: Vector3 = xf * (_spec.grip_l as Vector3) if _model and _spec.has("grip_l") and _left_food == null else rest_l + l_off + bob * Vector3(-1, 1, 1)
	_place_arm(right_arm, SHOULDER_R, target_r, _spec.get("roll_r", 0.0))
	_place_arm(left_arm, SHOULDER_L, target_l, _spec.get("roll_l", 0.0))
	if _left_food:
		_left_food.position = target_l + Vector3(0.02, 0.05, -0.02)


## Puts the arm's palm on `target`, the forearm pointing back towards the shoulder.
func _place_arm(arm: Node3D, shoulder: Vector3, target: Vector3, roll: float) -> void:
	var dir := (target - shoulder).normalized()
	var b := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3(0, 0, 1), roll)
	arm.transform = Transform3D(b, target - b * HAND_IN_ARM)


func _pose_named(name: String) -> Transform3D:
	var poses: Dictionary = _spec.poses
	return poses.get(name, poses.rest)


func set_walk(amount: float) -> void:
	_walk = lerpf(_walk, clampf(amount, 0.0, 1.0), 0.15)


## What the arms are carrying (rebuilds the armful if it changed).
func set_carry(id: StringName, count: int) -> void:
	if id == _carry_id and count == _carry_count:
		return
	_carry_id = id
	_carry_count = count
	if _held_id == Player.CARRYING:
		_held_id = &""   # force set_held to rebuild the armful


func _build_armful() -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * 0.62   # a believable armful, kept low so you can see past it
	var it := Items.item(_carry_id)
	var n := mini(_carry_count, 5)
	var sheaf := String(_carry_id).ends_with("_sheaf")
	var sack := it != null and it.kind == ItemData.Kind.GRAIN and not sheaf
	if _carry_id == &"barrel":
		var b := Models.make(&"barrel")
		b.scale = Vector3.ONE * 0.75
		b.position = Vector3(0, -0.25, 0)
		root.add_child(b)
		return root
	for i in n:
		var m := Models.make(&"grain_sack" if sack else _carry_id)
		root.add_child(m)
		if sheaf:   # sheaves lie across the arms
			m.rotation = Vector3(0, 0.15 * i, PI / 2)
			m.position = Vector3(0.42, 0.06 + i * 0.09, -0.05 * i)
			m.scale = Vector3.ONE * 0.8
		elif sack:
			m.scale = Vector3.ONE * (0.6 + 0.1 * mini(_carry_count, 4))
			break
		else:       # a heap: four on the bottom, one on top
			var row := Vector2(float(i % 2) - 0.5, float((i / 2) % 2) - 0.5) * 0.15
			m.position = Vector3(row.x, (0.12 if i == 4 else 0.0), row.y)
			m.rotation.y = i * 1.3
	return root


## The handcart's two shaft ends, as seen in your hands while pulling.
func _build_shafts() -> Node3D:
	var root := Node3D.new()
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.3 * side, 0, 0)
		pivot.rotation.x = 0.35   # running back and down towards the cart
		root.add_child(pivot)
		var shaft := Models.box(Vector3(0.05, 0.05, 1.4), Color(0.33, 0.22, 0.13), Vector3(0, 0, 0.62))
		pivot.add_child(shaft)
		# The worn handle end pokes forward out of the fist, so you can see what you're holding.
		var grip := Models.box(Vector3(0.06, 0.06, 0.24), Color(0.24, 0.16, 0.09), Vector3(0, 0, -0.05))
		pivot.add_child(grip)
	return root


## The cart caught on something: a jolt through the arms.
func play_jerk() -> void:
	_animate([[_pose_named("jerk"), 0.08], [_pose_named("rest"), 0.35]])


func set_held(id: StringName) -> void:
	if id == _held_id:
		return
	_held_id = id
	if _model:
		_model.queue_free()
		_model = null
		_swingle = null
	var it := Items.item(id)
	var key: StringName = &"seed_pouch" if it and it.kind == ItemData.Kind.SEED else id
	_spec = _specs.get(key, _specs[&"hands"])
	if id == Player.CARRYING and _carry_count > 0:
		_model = _build_armful()
		add_child(_model)
		_no_shadows(_model)
	elif id == Player.PULLING:
		_model = _build_shafts()
		add_child(_model)
		_no_shadows(_model)
	elif _spec.has("model"):
		_model = Models.make(_spec.model)
		add_child(_model)
		_no_shadows(_model)
		_swingle = _model.find_child("swingle", true, false)
		if id == &"bucket":
			set_bucket_fill(_bucket_fill)
		var grain := _model.find_child("grain", true, false) as Node3D
		if grain:
			grain.visible = false
	# Swap animation: bring the new tool up from below.
	var rest := _pose_named("rest")
	_xf = rest.translated(Vector3(0, -0.3, 0.05))
	r_off = Vector3(0, -0.2, 0)
	l_off = Vector3(0, -0.2, 0)
	_animate([[rest, 0.25]])
	_hands_to(Vector3.ZERO, Vector3.ZERO, 0.25)


func held_model() -> Node3D:
	return _model


## Shows or hides the water surface in the held bucket.
func set_bucket_fill(amount: float) -> void:
	_bucket_fill = amount
	if _model and _held_id == &"bucket":
		var w := _model.find_child("water", true, false) as Node3D
		if w:
			w.visible = amount > 0.0


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


# --- Animation plumbing -----------------------------------------------------------------------

## Moves the tool through a list of [pose, seconds] keys.
func _animate(keys: Array) -> Tween:
	if _tool_tween and _tool_tween.is_valid():
		_tool_tween.kill()
	_tool_tween = create_tween()
	var from := _xf
	for k: Array in keys:
		var to: Transform3D = k[0]
		var f := from
		_tool_tween.tween_method(func(t: float) -> void: _xf = f.interpolate_with(to, t), 0.0, 1.0, k[1]) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		from = to
	return _tool_tween


func _hands_to(r: Vector3, l: Vector3, dur: float) -> Tween:
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = create_tween().set_parallel(true)
	_hand_tween.tween_property(self, "r_off", r, dur).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(self, "l_off", l, dur).set_trans(Tween.TRANS_SINE)
	return _hand_tween


func _stop_tweens() -> void:
	if _tool_tween and _tool_tween.is_valid():
		_tool_tween.kill()
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()


# --- Continuous poses (a minigame drives these every frame) ---------------------------------

## Hoe/flail wind-up: 0 resting, 1 raised overhead.
func pose_raise(amount: float) -> void:
	_stop_tweens()
	_xf = _pose_named("rest").interpolate_with(_pose_named("raised"), clampf(amount, 0.0, 1.0))
	_swing_angle = lerpf(2.4, 2.9, amount)


## Tugging a weed or plant with both hands: reach down, strain back.
func pose_pull(reach: float, strain: float) -> void:
	_stop_tweens()
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.006 * strain
	r_off = Vector3(-0.06, 0.08 * reach - 0.05 * strain, -0.14 * reach + 0.1 * strain) + shake
	l_off = Vector3(0.06, 0.08 * reach - 0.05 * strain, -0.14 * reach + 0.1 * strain) - shake


## Tipping the bucket: 0 upright, 1 pouring.
func pose_pour(amount: float) -> void:
	_stop_tweens()
	_xf = _pose_named("rest").interpolate_with(_pose_named("pour"), clampf(amount, 0.0, 1.0))


## Turning the well's crank with the free left hand.
func pose_crank(angle: float) -> void:
	_stop_tweens()
	l_off = Vector3(0.1 + cos(angle) * 0.07, 0.28 + sin(angle) * 0.07, -0.1)


## Lifting the winnowing basket: 0 low, 1 high.
func pose_lift(amount: float) -> void:
	_stop_tweens()
	_xf = _pose_named("rest").interpolate_with(_pose_named("lifted"), clampf(amount, 0.0, 1.0))


func pose_rest(dur: float = 0.25) -> void:
	_animate([[_pose_named("rest"), dur]])
	_hands_to(Vector3.ZERO, Vector3.ZERO, dur)
	create_tween().tween_property(self, "_swing_angle", 2.4, dur)


# --- One-shot actions -----------------------------------------------------------------------

## Hoe or flail coming down hard.
func play_strike() -> void:
	var struck := _pose_named("struck")
	_animate([[struck, 0.1], [struck, 0.08], [_pose_named("rest"), 0.32]])
	if _swingle:
		var s := create_tween()
		s.tween_property(self, "_swing_angle", 0.3, 0.12).set_ease(Tween.EASE_OUT)
		s.tween_property(self, "_swing_angle", 2.4, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Broadcast sowing: the free right hand dips into the pouch, sweeps out and opens.
func play_throw() -> void:
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = create_tween()
	_hand_tween.tween_property(self, "r_off", Vector3(-0.3, 0.12, -0.02), 0.14).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(self, "r_off", Vector3(0.12, 0.2, -0.22), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(self, "r_off", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_SINE)


## Sickle sweep from right to left.
func play_sweep() -> void:
	_animate([[_pose_named("sweep_a"), 0.1], [_pose_named("sweep_b"), 0.18], [_pose_named("rest"), 0.3]])


## Quick reach forward and pinch (caterpillars, binding sheaves).
func play_pick() -> void:
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = create_tween()
	_hand_tween.tween_property(self, "r_off", Vector3(-0.08, 0.12, -0.2), 0.12)
	_hand_tween.tween_property(self, "r_off", Vector3.ZERO, 0.2)


## Winnowing toss: basket jerks up, then settles.
func play_toss() -> void:
	_animate([[_pose_named("toss"), 0.1], [_pose_named("rest"), 0.4]])


## Bring food to the mouth with the left hand.
func play_eat(id: StringName) -> void:
	if _left_food:
		_left_food.queue_free()
	_left_food = Models.make(id)
	_left_food.scale = Vector3.ONE * 0.6
	add_child(_left_food)
	_no_shadows(_left_food)
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	var mouth := Vector3(0.18, 0.36, 0.1)   # offset from the resting left hand up to the mouth
	_hand_tween = create_tween()
	_hand_tween.tween_property(self, "l_off", mouth, 0.3).set_trans(Tween.TRANS_SINE)
	_hand_tween.tween_property(self, "l_off", mouth + Vector3(0, -0.02, 0.02), 0.15)
	_hand_tween.tween_property(self, "l_off", mouth, 0.15)
	_hand_tween.tween_callback(func() -> void:
		if _left_food:
			_left_food.queue_free()
			_left_food = null)
	_hand_tween.tween_property(self, "l_off", Vector3.ZERO, 0.3)
