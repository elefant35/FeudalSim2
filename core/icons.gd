extends Node
## Item icons, rendered at runtime from the items' own 3D models (so a new model gets an icon
## for free). Autoloaded as `Icons`. Icons render one per frame in an off-screen viewport;
## `get_icon` returns null until ready, then `icon_ready` fires.

signal icon_ready(id: StringName)

const SIZE := 128
## Which models make up an item's icon (default: the model with the item's own id).
const COMPOSITE := {
	&"hands": [&"fp_arm"],
	&"barley_chaff": [&"chaff_pile"], &"wheat_chaff": [&"chaff_pile"],
}

var _tex: Dictionary = {}       # id -> Texture2D
var _queue: Array[StringName] = []
var _busy := false
var _vp := SubViewport.new()
var _cam := Camera3D.new()
var _holder := Node3D.new()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.68)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_vp.add_child(_holder)


func get_icon(id: StringName) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	if DisplayServer.get_name() != "headless" and not (id in _queue):
		_queue.append(id)
	return null


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_render(_queue.pop_front())


func _models_for(id: StringName) -> Array:
	if COMPOSITE.has(id):
		return COMPOSITE[id]
	var it := Items.item(id)
	if it and it.kind == ItemData.Kind.SEED:
		return [&"seed_pouch", StringName("%s_s3" % it.crop)]
	return [Items.carry_model(id)]


func _render(id: StringName) -> void:
	_busy = true
	for c in _holder.get_children():
		c.free()
	var models := _models_for(id)
	# Long-handled tools lie diagonally so they fill the square.
	_holder.rotation = Vector3(0, 0, -0.8) if id in [&"hoe", &"flail", &"sickle", &"scarecrow"] else Vector3.ZERO
	for i in models.size():
		var m := Models.make(models[i])
		_holder.add_child(m)
		if i == 1:   # a seed pouch's crop: smaller, beside it
			m.scale = Vector3.ONE * 0.35
			m.position = Vector3(0.12, 0, -0.05)
	var tool := _holder.rotation != Vector3.ZERO
	var view := Vector3(0.15, 0.25, 1.0) if tool else Vector3(1.0, 0.75, 1.2)
	if id == &"sickle":
		_holder.rotation = Vector3(0.8, 0, 0)   # the blade curves forward: look at it side-on
		view = Vector3(1.0, 0.2, 0.1)
	_frame(view.normalized())
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img and not img.is_empty():
		_tex[id] = ImageTexture.create_from_image(img)
		icon_ready.emit(id)
	_busy = false


## Points the camera along `dir` and fits it to the model's actual outline on screen (projecting
## every vertex), so odd shapes like the sickle still sit in the middle of the icon.
func _frame(dir: Vector3) -> void:
	var box := _bounds(_holder)
	var center := box.get_center()
	var reach := box.get_longest_axis_size() * 3.0 + 1.0
	_cam.position = center + dir * reach
	_cam.look_at(center, Vector3.UP)
	var inv := _cam.global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi: MeshInstance3D in _holder.find_children("*", "MeshInstance3D", true, false):
		var xf := inv * mi.global_transform
		for si in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				var p := xf * v
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	if lo.x == INF:
		_cam.size = box.get_longest_axis_size() * 1.2
	else:
		var mid := (lo + hi) / 2.0
		_cam.position += _cam.global_basis.x * mid.x + _cam.global_basis.y * mid.y
		_cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.12
	_cam.near = 0.01
	_cam.far = reach * 3.0


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.global_transform * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out if not first else AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
