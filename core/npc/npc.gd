class_name Npc
extends Actor
## A villager. The body walks the navigation mesh and animates; basic needs are looked after
## here (they eat when hungry and sleep in their own bed at night); everything else comes from
## their Role, so the same villager can be a farmer today and a baker in another chunk.

const WALK_SPEED := 1.5
## How each tool sits in the villager's right hand (rotation in degrees, offset in metres).
const TOOL_GRIP := {
	&"default": [Vector3(-90, 0, 0), Vector3(0, -0.06, 0.02)],
	&"bucket": [Vector3(180, 0, 0), Vector3(0, 0.05, 0)],   # hangs below the fist
}

var role: Role
var bed: Vector3              ## Where they sleep (the middle of the mattress).
var bed_head := Vector3(0, 0, -1)   ## Which way the bed's head (pillow) end points.
var home: Vector3             ## Where they wait when there's nothing to do.
var instant: bool = false     ## Tests: walking and work complete at once.
var sleeping: bool = false
## Clothes colours (material name -> Color), so villagers look like different people.
var tint: Dictionary = {}

var _task: Task
var _visual: Node3D
var _anim: AnimationPlayer
var _hand: BoneAttachment3D
var _held_model: Node3D
var _held_id: StringName = &""
var _action: StringName = &""
var _walking := false
var _walk_target := Vector3.ZERO
var _walk_direct := false   ## Straight at the target, ignoring the navigation mesh (indoors, up steps).
var _agent := NavigationAgent3D.new()
var _bubble := Label3D.new()
var _bubble_t := 0.0
var _line := ""


func _ready() -> void:
	super()
	add_to_group("npc")
	add_to_group("saveable")
	owner_key = StringName(name.to_lower())
	_visual = Models.make(&"villager")
	add_child(_visual)
	_anim = _visual.find_children("*", "AnimationPlayer", true, false)[0]
	for a in _anim.get_animation_list():
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var skel: Skeleton3D = _visual.find_children("*", "Skeleton3D", true, false)[0]
	_hand = BoneAttachment3D.new()
	_hand.bone_name = "hand.R"
	skel.add_child(_hand)
	_apply_tint()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.5
	_agent.radius = 0.3
	_agent.height = 1.7
	add_child(_agent)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 36
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 10
	_bubble.position.y = 2.1
	_bubble.no_depth_test = true
	_bubble.visible = false
	add_child(_bubble)
	if role:
		role.npc = self
	Clock.minutes_passed.connect(_on_minutes)
	Clock.day_started.connect(_on_day_started)
	Clock.skipped.connect(_on_skipped)


func _apply_tint() -> void:
	for mi: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si)
			if m and tint.has(m.resource_name):
				var copy := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = tint[m.resource_name]
				mi.set_surface_override_material(si, copy)


# --- Thinking --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _task == null:
		_task = _think()
		if _task:
			if OS.has_environment("FS_NPC_LOG"):
				print("NPC %s %s: %s   %s" % [name, Clock.time_string(), _task.label, role.debug_status() if role else ""])
			_task.start(self)
	elif _task.update(self, delta):
		_task = null
	_move(delta)
	_animate()
	_update_bubble(delta)


## Needs first (sleep, food), then whatever the role wants.
func _think() -> Task:
	if sleeping:   # loaded while asleep: carry on sleeping where they lie
		return SleepTask.new()
	var h := Clock.hour()
	if h >= 21.0 or h < 5.0 or needs.energy < 12.0:
		var steps: Array[Task] = [GoTo.new(bedside(), 0.6, "Going home to bed"), SleepTask.new()]
		return Sequence.new("Going to bed", steps)
	if needs.hunger < 35.0:
		if _has_food():
			return Work.new("Eating", &"idle", 2.0, eat_something)
		var fetch := role.fetch_food() if role else null
		if fetch:
			return fetch
	var t := role.next_task() if role else null
	if t == null:
		var steps: Array[Task] = [GoTo.new(home, 1.5, "Heading home"), Work.new("Resting", &"idle", 20.0, Callable())]
		return Sequence.new("Resting", steps)
	return t


func _has_food() -> bool:
	if is_carrying() and Items.item(carry_id).food_value > 0.0:
		return true
	for s in inventory.stacks():
		var it := Items.item(s.id)
		if it and it.food_value > 0.0:
			return true
	return false


## What they're doing right now, in words.
func activity() -> String:
	if _task == null:
		return ""
	if _task is Sequence:
		return (_task as Sequence).current_label()
	return _task.label


## Drops whatever they were doing (a new day, the clock jumping ahead).
func interrupt() -> void:
	if _task:
		_task.cancel(self)
		_task = null
	if pulling:   # never left holding a cart from a trip that's been cut short
		pulling.call("release", self)


# --- Body ------------------------------------------------------------------------------------

func walk_to(p: Vector3, direct: bool = false) -> void:
	_walking = true
	_walk_target = p
	_walk_direct = direct
	if not direct:
		_agent.target_position = p


func stop_walking() -> void:
	_walking = false
	velocity.x = 0.0
	velocity.z = 0.0


func _move(delta: float) -> void:
	var dir := Vector3.ZERO
	if _walking and not instant and not sleeping:
		var next := _walk_target
		if not _walk_direct and NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0:
			next = _agent.get_next_path_position()
		dir = Vector3(next.x - global_position.x, 0, next.z - global_position.z)
		if dir.length() > 0.05:
			dir = dir.normalized()
		else:
			dir = Vector3.ZERO
	var speed := WALK_SPEED * Clock.speed() * needs.speed_factor() * (0.85 if is_carrying() else 1.0) * (0.8 if pulling else 1.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if sleeping:
		velocity = Vector3.ZERO
		return
	_fall(delta)
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))


func face(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(-d.x, -d.z)


## Plays a work animation until cleared (&"" goes back to walking/idling).
func act(anim: StringName) -> void:
	_action = anim


func hold(tool: StringName) -> void:
	if tool == _held_id:
		return
	_held_id = tool
	if _held_model:
		_held_model.queue_free()
		_held_model = null
	if tool == &"":
		return
	_held_model = Models.make(tool)
	var grip: Array = TOOL_GRIP.get(tool, TOOL_GRIP[&"default"])
	_held_model.rotation_degrees = grip[0]
	_held_model.position = grip[1]
	_hand.add_child(_held_model)


func _animate() -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	var want: StringName
	if sleeping:
		want = &"idle"
	elif _action != &"":
		want = _action
	elif horiz > 0.2:
		want = &"pull" if pulling else (&"carry" if is_carrying() else &"walk")
	else:
		want = &"carry_idle" if is_carrying() else &"idle"
	if not _anim.has_animation(want):
		want = &"idle"
	if _anim.current_animation != String(want):
		_anim.play(want, 0.2)
	# One walk cycle covers about 1.7 m (two strides), so this keeps the feet from sliding.
	_anim.speed_scale = horiz / 1.7 if horiz > 0.2 and _action == &"" else float(Clock.speed())


## Where to stand beside the bed (the bed itself is solid).
func bedside() -> Vector3:
	return bed + Vector3(bed_head.z, 0, -bed_head.x) * 0.9


## Lies on the bed: feet at the foot end, head on the pillow.
func lie_down() -> void:
	sleeping = true
	stop_walking()
	rotation.y = atan2(bed_head.x, bed_head.z)        # local +Z towards the pillow
	global_position = bed - bed_head * 0.85
	_visual.rotation = Vector3(PI / 2, 0, 0)          # the body tips over onto its back, head along +Z
	_visual.position = Vector3(0, 0.62, 0)


func get_up() -> void:
	sleeping = false
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	global_position = bedside()


# --- Needs and time --------------------------------------------------------------------------

func _on_minutes(minutes: float) -> void:
	if sleeping:
		needs.sleep(minutes / 60.0)
	else:
		needs.pass_hours(minutes / 60.0)


func _on_day_started(_day: int) -> void:
	if role:
		role.on_day_started()


## The player slept and the world jumped ahead: they slept too, and start the morning afresh.
func _on_skipped(hours: float) -> void:
	interrupt()
	needs.sleep(hours)
	if sleeping:
		get_up()
	global_position = home


# --- Talking ---------------------------------------------------------------------------------

func say(text: String) -> void:
	super(text)
	_line = text
	_bubble_t = 4.0


func _update_bubble(delta: float) -> void:
	_bubble_t = maxf(0.0, _bubble_t - delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and player.global_position.distance_to(global_position) < 10.0
	_bubble.visible = near
	if not near:
		return
	var doing := "Zzz" if sleeping else activity()
	_bubble.text = ("\"%s\"\n" % _line if _bubble_t > 0.0 else "") + doing
	_bubble.modulate = Color(1, 0.96, 0.85)


func get_prompt(_player: Player) -> String:
	var title := role.title if role else "villager"
	return "%s the %s\n%s\n[E] Talk" % [display_name, title, "Asleep" if sleeping else activity()]


func interact(player: Player) -> void:
	var line := "Zzz..." if sleeping else (role.chat_line() if role else "Good day.")
	if not sleeping:
		face(player.global_position)
	say(line)
	player.say("%s: \"%s\"" % [display_name, line])


# --- Save ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := actor_dict()
	d["sleeping"] = sleeping
	d["role"] = role.to_dict() if role else {}
	return d


func from_dict(d: Dictionary) -> void:
	interrupt()
	load_actor_dict(d)
	if d.get("sleeping", false):
		lie_down()
	if role:
		role.from_dict(d.get("role", {}))
