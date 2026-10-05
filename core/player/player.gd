class_name Player
extends CharacterBody3D
## First-person player: movement, looking, the hotbar, and interacting with what's under the
## crosshair. World objects opt in by implementing (any of):
##   get_prompt(player) -> String   what the crosshair says
##   interact(player)               E
##   use(player) -> Minigame        left-click with the held item (may return null)

signal message(text: String)
signal hotbar_changed
signal minigame_changed(game: Minigame)
signal carry_changed

const WALK_SPEED := 3.4
const RUN_SPEED := 5.6
const JUMP_VELOCITY := 4.2
const MOUSE_SENSITIVITY := 0.0022
const REACH := 3.2
const STEP_HEIGHT := 0.32
const EYE_HEIGHT := 1.6
const HANDS := &"hands"
const CARRYING := &"carrying"   ## held() while your arms are full of produce.
const PULLING := &"pulling"     ## held() while pulling the handcart.
const POCKET_MAX := 6           ## Produce the pack can hold, for eating on the go.

var needs := Needs.new()
var wallet := Wallet.new()
var inventory := Inventory.new()

var head := Node3D.new()
var camera := Camera3D.new()
var ray := RayCast3D.new()
var viewmodel: Viewmodel

const HOTBAR_SIZE := 9
## Slot 0 is always bare hands; slots 1..8 hold whatever the player puts there (or &"").
var hotbar: Array[StringName] = []
var held_index: int = 0
var minigame: Minigame = null
var ui_open: bool = false
var frozen: bool = false   ## Sleeping, fading, etc.
var target: Node = null
var target_point: Vector3 = Vector3.ZERO
## Per-tool state that outlives a minigame (e.g. how much water is in the bucket).
var tool_state: Dictionary = {}
var dev_walk_seconds: float = 0.0
## What's in your arms: one kind of bulky item, one quality per unit.
var carry_id: StringName = &""
var carry_units: Array[int] = []
## The handcart you're pulling, if any.
var pulling: Node3D = null   ## Dev runs: walk forward on our own for this long.

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_distance: float = 0.0


func _ready() -> void:
	InputSetup.ensure()
	name = "Player"
	add_to_group("player")
	for c: Node in [needs, wallet, inventory]:
		add_child(c)
	# The body rides on a short downward "foot" ray: the capsule sits STEP_HEIGHT off the
	# ground, so door sills, plot edges and other small lips are simply walked over.
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75 - STEP_HEIGHT
	shape.shape = capsule
	shape.position.y = STEP_HEIGHT + capsule.height / 2.0
	add_child(shape)
	var foot := CollisionShape3D.new()
	var ray_shape := SeparationRayShape3D.new()
	ray_shape.length = STEP_HEIGHT + 0.05
	foot.shape = ray_shape
	foot.position.y = STEP_HEIGHT + 0.05
	foot.rotation.x = PI / 2   # the ray casts along +Z; this points it straight down
	add_child(foot)
	floor_snap_length = STEP_HEIGHT + 0.1
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera.fov = 72.0
	camera.near = 0.03
	camera.current = true
	head.add_child(camera)
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = true
	ray.add_exception(self)
	camera.add_child(ray)
	viewmodel = Viewmodel.new()
	camera.add_child(viewmodel)
	hotbar.resize(HOTBAR_SIZE)
	hotbar.fill(&"")
	hotbar[0] = HANDS
	inventory.changed.connect(_on_inventory_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## What's in hand: the selected slot's item, or bare hands if the slot is empty or used up.
func held() -> StringName:
	if pulling:
		return PULLING
	if is_carrying():
		return CARRYING
	var id := hotbar[held_index]
	if id == &"" or id == HANDS or not inventory.has(id):
		return HANDS
	return id


# --- Carrying bulky goods in your arms -------------------------------------------------------

func is_carrying() -> bool:
	return not carry_units.is_empty()


func carry_count() -> int:
	return carry_units.size()


## How many more of `id` your arms can take right now.
func carry_space(id: StringName) -> int:
	var it := Items.item(id)
	if it == null or it.carry_max <= 0 or pulling != null:
		return 0
	if is_carrying() and carry_id != id:
		return 0
	return it.carry_max - carry_units.size()


func pick_up(id: StringName, quality: int) -> bool:
	if carry_space(id) <= 0:
		return false
	carry_id = id
	carry_units.append(quality)
	_carry_updated()
	return true


## Empties your arms, returning what you were carrying (one quality per unit).
func take_carry() -> Array[int]:
	var units := carry_units.duplicate()
	carry_units.clear()
	carry_id = &""
	_carry_updated()
	return units


func carry_text() -> String:
	if not is_carrying():
		return ""
	return "%d %s" % [carry_count(), Items.name_of(carry_id).to_lower() + ("s" if carry_count() > 1 and not carry_id.ends_with("y") else "")]


func _carry_updated() -> void:
	viewmodel.set_carry(carry_id, carry_units.size())
	viewmodel.set_held(held())
	hotbar_changed.emit()
	carry_changed.emit()


## Produce held in the pack.
func pocket_count() -> int:
	var n := 0
	for st in inventory.stacks():
		var it := Items.item(st.id)
		if it and it.carry_max > 0:
			n += st.count
	return n


## Moves one unit of food from your arms into the pack.
func pocket_one() -> bool:
	if not is_carrying() or Items.item(carry_id).food_value <= 0.0 or pocket_count() >= POCKET_MAX:
		return false
	var id := carry_id
	var q: int = carry_units.pop_back()
	if carry_units.is_empty():
		carry_id = &""
	inventory.add(id, 1, q)
	_carry_updated()
	return true


## Sets your load down where you're looking (or at your feet): onto a matching pile, or as a new one.
func set_down() -> void:
	if not is_carrying():
		return
	var at := target_point if target != null else global_position - global_basis.z * 1.0
	at.y = Terrain.height_at(at.x, at.z)
	var piles := get_tree().get_first_node_in_group("piles")
	if piles == null:
		return
	var id := carry_id
	var units := take_carry()
	piles.put(id, units, at)
	Sfx.play_at("rustle", at)
	say("You set down %d %s." % [units.size(), Items.name_of(id).to_lower()])


## Seed types carried, in a stable order.
func seed_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in [&"turnip_seed", &"cabbage_seed", &"barley_seed", &"wheat_seed"]:
		if inventory.has(id):
			out.append(id)
	for st in inventory.stacks():
		var it := Items.item(st.id)
		if it and it.kind == ItemData.Kind.SEED and not (st.id in out):
			out.append(st.id)
	return out


func select_slot(i: int) -> void:
	if i < 0 or i >= hotbar.size() or minigame != null:
		return
	held_index = i
	viewmodel.set_held(held())
	hotbar_changed.emit()


## Puts an item in a hotbar slot (1..8). If it's already in another slot, the two swap.
func assign_slot(slot: int, id: StringName) -> void:
	if slot <= 0 or slot >= HOTBAR_SIZE:
		return
	var it := Items.item(id)
	if it == null or not it.hotbar:
		return
	var old := hotbar.find(id)
	if old > 0:
		hotbar[old] = hotbar[slot]
	hotbar[slot] = id
	viewmodel.set_held(held())
	hotbar_changed.emit()


func clear_slot(slot: int) -> void:
	if slot <= 0 or slot >= HOTBAR_SIZE:
		return
	hotbar[slot] = &""
	viewmodel.set_held(held())
	hotbar_changed.emit()


## Newly acquired tools and seed go into the first free slot (the player can rearrange them).
var _had: Dictionary = {}


func _on_inventory_changed() -> void:
	var now := {}
	for st in inventory.stacks():
		now[st.id] = true
	for id: StringName in now:
		var it := Items.item(id)
		if not _had.has(id) and it and it.hotbar and not (id in hotbar):
			var free := hotbar.find(&"")
			if free > 0:
				hotbar[free] = id
	_had = now
	viewmodel.set_held(held())
	hotbar_changed.emit()


func bucket_water() -> float:
	return float(tool_state.get("bucket_water", 0.0))


func set_bucket_water(v: float) -> void:
	tool_state["bucket_water"] = clampf(v, 0.0, 1.0)
	viewmodel.set_bucket_fill(bucket_water())


func say(text: String) -> void:
	message.emit(text)


func start_minigame(game: Minigame) -> void:
	if minigame != null:
		minigame.stop()
	minigame = game
	game.finished.connect(_on_minigame_finished.bind(game), CONNECT_ONE_SHOT)
	game.start(self)
	minigame_changed.emit(game)


func _on_minigame_finished(game: Minigame) -> void:
	if minigame == game:
		minigame = null
		minigame_changed.emit(null)


func can_act() -> bool:
	return not ui_open and not frozen


# --- Input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not can_act():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = event.relative
		if minigame != null and minigame.locks_look:
			minigame.mouse_motion(rel)
		else:
			rotate_y(-rel.x * MOUSE_SENSITIVITY)
			head.rotate_x(-rel.y * MOUSE_SENSITIVITY)
			head.rotation.x = clampf(head.rotation.x, -1.45, 1.45)
	elif event.is_action_pressed("primary"):
		if minigame != null:
			minigame.press()
		elif target != null and target.has_method("use"):
			var game: Minigame = target.use(self)
			if game != null:
				start_minigame(game)
				game.press()
	elif event.is_action_released("primary"):
		if minigame != null:
			minigame.release()
	elif event.is_action_pressed("secondary"):
		if minigame != null:
			minigame.stop()
	elif event.is_action_pressed("interact"):
		if minigame != null:
			minigame.stop()
		elif pulling != null:
			pulling.call("release", self)
		elif target != null and target.has_method("interact"):
			target.interact(self)
		elif is_carrying():
			set_down()
	elif event.is_action_pressed("eat"):
		eat_something()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			select_slot(k - KEY_1)
	elif event is InputEventMouseButton and event.pressed and minigame == null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(posmod(held_index - 1, hotbar.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(posmod(held_index + 1, hotbar.size()))


## Eats the cheapest food carried (lowest quality first).
func eat_something() -> void:
	if needs.hunger >= 98.0:
		say("You're not hungry.")
		return
	if is_carrying() and Items.item(carry_id).food_value > 0.0:
		var id := carry_id
		var q: int = carry_units.pop_front()
		if carry_units.is_empty():
			carry_id = &""
		_carry_updated()
		inventory.add(id, 1, q)
		eat(id, q)
		return
	var best: ItemData = null
	for s in inventory.stacks():
		var it := Items.item(s.id)
		if it and it.food_value > 0.0 and (best == null or it.food_value < best.food_value):
			best = it
	if best == null:
		say("You have nothing to eat. Buy bread at the stall, or grow turnips.")
		return
	eat(best.id, inventory.qualities_of(best.id).front())


func eat(id: StringName, quality: int) -> void:
	var it := Items.item(id)
	if it == null or not inventory.remove(id, 1, quality):
		return
	needs.eat(it.food_value * (1.0 + 0.1 * maxi(quality, 0)))
	viewmodel.play_eat(id)
	Sfx.play("eat", -2.0)
	say("You eat a %s." % Items.name_of(id).to_lower())


# --- Per-frame ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_target()
	var input := Vector2.ZERO
	var running := false
	if can_act() and (minigame == null or not minigame.locks_movement):
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		running = Input.is_action_pressed("sprint") and needs.energy > 5.0
	if dev_walk_seconds > 0.0:
		dev_walk_seconds -= delta
		input = Vector2(0, -1)
		if dev_walk_seconds <= 0.0:
			print("DEV walked to ", global_position)
	var speed := (RUN_SPEED if running else WALK_SPEED) * needs.speed_factor()
	if pulling:
		speed *= 0.8
	elif is_carrying():
		speed *= 0.9
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 40.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 40.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif can_act() and minigame == null and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()

	var horizontal := Vector2(velocity.x, velocity.z).length()
	if running and horizontal > 0.5:
		needs.exert(delta * 0.15)
	if is_on_floor() and horizontal > 0.3:
		_step_distance += horizontal * delta
		if _step_distance > (1.9 if running else 1.5):
			_step_distance = 0.0
			Sfx.play(_footstep_bank(), -10.0, 0.12)
	viewmodel.set_walk(horizontal / RUN_SPEED if is_on_floor() else 0.0)
	if minigame != null:
		minigame.update(delta)


func _footstep_bank() -> String:
	var down := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1, [get_rid()]))
	if down and down.collider is Node and (down.collider as Node).is_in_group("wood_floor"):
		return "step_wood"
	return "step_grass"


func _update_target() -> void:
	target = null
	if minigame != null or not can_act():
		return
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	target_point = ray.get_collision_point()
	var n: Node = ray.get_collider()
	while n != null and not (n.has_method("get_prompt") or n.has_method("interact") or n.has_method("use")):
		n = n.get_parent()
	target = n


func prompt() -> String:
	if target == null or not target.has_method("get_prompt"):
		return ""
	return target.get_prompt(self)


# --- Save -----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y,
		"needs": needs.to_dict(), "gold": wallet.gold, "inventory": inventory.to_dict(),
		"tool_state": tool_state, "hotbar": hotbar,
		"carry_id": String(carry_id), "carry_units": carry_units,
	}


func from_dict(d: Dictionary) -> void:
	global_position = Vector3(d.pos[0], d.pos[1], d.pos[2])
	rotation.y = float(d.yaw)
	needs.from_dict(d.needs)
	wallet.gold = int(d.gold)
	wallet.changed.emit(wallet.gold)
	inventory.from_dict(d.inventory)
	tool_state = d.get("tool_state", {})
	carry_id = StringName(d.get("carry_id", ""))
	carry_units.clear()
	for q in d.get("carry_units", []):
		carry_units.append(int(q))
	if carry_units.is_empty():
		carry_id = &""
	viewmodel.set_carry(carry_id, carry_units.size())
	if d.has("hotbar"):
		for i in mini(HOTBAR_SIZE, d.hotbar.size()):
			hotbar[i] = StringName(d.hotbar[i])
		hotbar[0] = HANDS
		# Respect the saved layout: don't auto-fill slots the player emptied on purpose.
		_had.clear()
		for st in inventory.stacks():
			_had[st.id] = true
	viewmodel.set_held(held())
	hotbar_changed.emit()
	set_bucket_water(bucket_water())
