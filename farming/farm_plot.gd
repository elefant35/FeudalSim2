class_name FarmPlot
extends StaticBody3D
## One plot in the field: draws its PlotState (sod/soil, seed, plants, weeds, caterpillars,
## wetness) and turns the player's held tool into the right action or minigame.

signal changed

const SIZE := 2.2
const SOIL_SHADER := preload("res://farming/soil.gdshader")

var state := PlotState.new()
var field: Field
var index: int = 0

var _soil_mat := ShaderMaterial.new()
var _plants: Array[Node3D] = []
var _plant_keys: Array[String] = []
var _weed_nodes: Array[Node3D] = []
var _caterpillar_root := Node3D.new()
var _seed_mm := MultiMeshInstance3D.new()
var _cell_yaw: Array[float] = []
var _cell_offset: Array[Vector2] = []


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE, 0.3, SIZE)
	shape.shape = bs
	shape.position.y = -0.08
	add_child(shape)

	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	top.mesh = pm
	top.position.y = 0.075
	_soil_mat.shader = SOIL_SHADER
	_soil_mat.set_shader_parameter("grass_tex", load("res://assets/textures/grass_ground_diff.jpg"))
	_soil_mat.set_shader_parameter("soil_tex", load("res://assets/textures/farm_furrows_diff.jpg"))
	_soil_mat.set_shader_parameter("soil_normal", load("res://assets/textures/farm_furrows_nor.jpg"))
	_soil_mat.set_shader_parameter("seed", float(index) * 1.37)
	top.material_override = _soil_mat
	add_child(top)
	var rim := Models.box(Vector3(SIZE + 0.04, 0.12, SIZE + 0.04), Color(0.3, 0.22, 0.15), Vector3(0, -0.005, 0))
	add_child(rim)

	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index
	for i in PlotState.CELLS:
		_plants.append(null)
		_plant_keys.append("")
		_cell_yaw.append(rng.randf() * TAU)
		_cell_offset.append(Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06)))
	add_child(_caterpillar_root)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var speck := BoxMesh.new()
	speck.size = Vector3(0.018, 0.012, 0.012)
	speck.material = Models.mat(Color(0.82, 0.7, 0.45))
	mm.mesh = speck
	_seed_mm.multimesh = mm
	_seed_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seed_mm)
	refresh()


## The plot a raycast hit belongs to (the plot itself, or a plant/weed hit area on it).
static func from_collider(n: Object) -> FarmPlot:
	var node := n as Node
	while node != null and not (node is FarmPlot):
		node = node.get_parent()
	return node as FarmPlot


## A small invisible target so the crosshair can pick out a plant or weed.
static func _hit_area(radius: float, height: float) -> Area3D:
	var a := Area3D.new()
	a.monitoring = false
	a.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height / 2.0
	a.add_child(shape)
	return a


# --- Coordinates ----------------------------------------------------------------------------

## World point -> plot space (0..1, 0..1).
func to_plot(world_point: Vector3) -> Vector2:
	var l := to_local(world_point)
	return Vector2(l.x / SIZE + 0.5, l.z / SIZE + 0.5)


func to_world(p: Vector2, y: float = 0.07) -> Vector3:
	return to_global(Vector3((p.x - 0.5) * SIZE, y, (p.y - 0.5) * SIZE))


func cell_world(i: int) -> Vector3:
	var c := PlotState.cell_center(i) + _cell_offset[i] / SIZE
	return to_world(c)


func cell_under(world_point: Vector3) -> int:
	return PlotState.cell_at(to_plot(world_point))


## Index of the weed nearest the point (within reach), or -1.
func weed_under(world_point: Vector3) -> int:
	var p := to_plot(world_point)
	var best := -1
	var best_d := 0.14
	for i in state.weeds.size():
		var d := state.weeds[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


# --- Visuals --------------------------------------------------------------------------------

func refresh() -> void:
	var till := state.till_progress / state.till_needed if not state.has_crop() else 1.0
	if state.has_crop():
		till = 1.0
	_soil_mat.set_shader_parameter("till", till)
	_soil_mat.set_shader_parameter("wet", clampf(state.moisture, 0.0, 1.2) / 1.2)
	_refresh_seeds()
	_refresh_plants()
	_refresh_weeds()
	_refresh_caterpillars()
	changed.emit()


func _refresh_seeds() -> void:
	var mm := _seed_mm.multimesh
	if not state.is_sown_not_sprouted():
		mm.instance_count = 0
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + index
	var xforms: Array[Transform3D] = []
	for i in PlotState.CELLS:
		var n := mini(int(state.seeds[i] * 14.0), 60)
		var c := PlotState.cell_center(i)
		for k in n:
			var p := c + Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.16, 0.16))
			var pos := Vector3((p.x - 0.5) * SIZE, 0.08, (p.y - 0.5) * SIZE)
			xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos))
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])


func _plant_model_id(i: int) -> String:
	if state.crop == null:
		return ""
	var crop := String(state.crop.id)
	match state.plants[i]:
		PlotState.Plant.ALIVE:
			var stage := 3 if state.is_ripe() else mini(2, int(state.growth_fraction() * 3.0))
			return "%s_s%d" % [crop, stage]
		PlotState.Plant.BLIGHTED:
			return crop + "_blight"
		PlotState.Plant.DEAD:
			return crop + "_dead"
		PlotState.Plant.CUT:
			return "cut:" + String(state.crop.product_item)
	return ""


func _refresh_plants() -> void:
	for i in PlotState.CELLS:
		var key := _plant_model_id(i)
		if key == _plant_keys[i]:
			continue
		var grew := _plant_keys[i] != "" and key != "" and not key.begins_with("cut:")
		_plant_keys[i] = key
		if _plants[i]:
			_plants[i].queue_free()
			_plants[i] = null
		if key == "":
			continue
		var n: Node3D
		if key.begins_with("cut:"):
			n = Models.make(StringName(key.substr(4)))
			n.rotation = Vector3(0, _cell_yaw[i], PI / 2 - 0.1)
			n.position = to_local(cell_world(i)) + Vector3(0, 0.08, 0)
			n.scale = Vector3.ONE * 0.8
		else:
			n = Models.make(StringName(key))
			n.position = to_local(cell_world(i))
			n.rotation.y = _cell_yaw[i]
			if state.coverage(i) == 2:
				n.scale = Vector3.ONE * 1.12
		var tall := 0.85 if String(state.crop.id) in ["barley", "wheat"] else 0.35
		var h := 0.15 if key.begins_with("cut:") else tall * maxf(0.3, state.growth_fraction())
		var area := _hit_area(0.2, h)
		area.scale = Vector3.ONE / n.scale
		n.add_child(area)
		add_child(n)
		_plants[i] = n
		if grew:
			var target := n.scale
			n.scale = target * 0.85
			n.create_tween().tween_property(n, "scale", target, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _refresh_weeds() -> void:
	for w in _weed_nodes:
		w.queue_free()
	_weed_nodes.clear()
	for i in state.weeds.size():
		var w := Models.make(&"weed")
		w.position = to_local(to_world(state.weeds[i]))
		w.rotation.y = float(i) * 2.1
		w.scale = Vector3.ONE * (0.9 + 0.15 * (i % 3))
		w.add_child(_hit_area(0.13, 0.3))
		add_child(w)
		_weed_nodes.append(w)


func _refresh_caterpillars() -> void:
	for c in _caterpillar_root.get_children():
		c.queue_free()
	for i in PlotState.CELLS:
		for k in state.caterpillars[i]:
			var c := Models.make(&"caterpillar")
			var a := float(k) * 2.2 + _cell_yaw[i]
			var r := 0.04 + 0.1 * state.growth_fraction()
			c.position = to_local(cell_world(i)) + Vector3(cos(a) * r, 0.04 + 0.18 * state.growth_fraction() + 0.02 * k, sin(a) * r)
			c.rotation = Vector3(0.3, a, 0)
			c.scale = Vector3.ONE * 1.5
			_caterpillar_root.add_child(c)


# --- Interaction ----------------------------------------------------------------------------

func status_text() -> String:
	var lines: Array[String] = []
	if state.crop == null:
		if state.is_tilled():
			lines.append("Tilled soil")
		elif state.till_progress > 0.0:
			lines.append("Half-tilled (%d%%)" % roundi(100.0 * state.till_progress / state.till_needed))
		else:
			lines.append("Stubble" if state.till_needed < PlotState.SOD_TILL else "Grass sod")
	elif not state.germinated:
		var good := 0
		for i in PlotState.CELLS:
			if state.coverage(i) == 1:
				good += 1
		lines.append("Sown with %s · %d/9 well covered" % [state.crop.display_name.to_lower(), good])
	else:
		var growing := "ripe!" if state.is_ripe() else "%d%% grown" % roundi(state.growth_fraction() * 100.0)
		lines.append("%s · %s · %s quality" % [state.crop.display_name, growing, Items.QUALITY_NAMES[state.quality()].to_lower()])
	var soil := "dry" if state.moisture < PlotState.DRY else ("soggy" if state.moisture > PlotState.SOGGY else ("damp" if state.moisture < 0.6 else "moist"))
	var extra := "Soil %s" % soil
	if not state.weeds.is_empty():
		extra += " · %d weed%s" % [state.weeds.size(), "" if state.weeds.size() == 1 else "s"]
	var cats := 0
	for c in state.caterpillars:
		cats += c
	if cats > 0:
		extra += " · %d caterpillar%s" % [cats, "" if cats == 1 else "s"]
	if state.count_plants(PlotState.Plant.BLIGHTED) > 0:
		extra += " · blight!"
	lines.append(extra)
	return "\n".join(lines)


func get_prompt(player: Player) -> String:
	return "%s\n%s" % [status_text(), _action_text(player)]


func _action_text(player: Player) -> String:
	var held := player.held()
	var it := Items.item(held)
	var p := player.target_point
	if held == Player.HANDS:
		if weed_under(p) >= 0:
			return "[Hold left] Pull the weed"
		var c := cell_under(p)
		if state.caterpillars[c] > 0:
			return "[Click] Pick off the caterpillar"
		match state.plants[c]:
			PlotState.Plant.BLIGHTED:
				return "[Hold left] Pull the blighted plant"
			PlotState.Plant.CUT:
				return "[Click] Bind into a sheaf"
			PlotState.Plant.ALIVE:
				if state.is_ripe():
					if state.crop.harvest == CropData.Harvest.HANDS:
						return "[Hold left] Pull the %s" % state.crop.display_name.to_lower()
					return "Reap it with a sickle."
		return ""
	if held == &"hoe":
		if state.has_crop():
			return "Something is growing here."
		if state.is_tilled():
			return "Ready for seed."
		return "[Click] Till the soil"
	if held == &"bucket":
		return "[Hold left] Pour water" if player.bucket_water() > 0.0 else "Your bucket is empty. Fill it at the well."
	if held == &"sickle":
		if state.is_ripe() and state.crop.harvest == CropData.Harvest.SICKLE:
			return "[Hold left and sweep] Reap the %s" % state.crop.display_name.to_lower()
		return ""
	if it and it.kind == ItemData.Kind.SEED:
		var err := state.sow_error(Items.crop(it.crop), Clock.season())
		return err if err != "" else "[Click] Sow %s" % it.display_name.to_lower()
	if held == &"scarecrow":
		return "Place the scarecrow beside the plots, not on them."
	return ""


func use(player: Player) -> Minigame:
	var held := player.held()
	var it := Items.item(held)
	var p := player.target_point
	if held == Player.HANDS:
		var w := weed_under(p)
		if w >= 0:
			return TugGame.weed(self, w)
		var c := cell_under(p)
		if state.caterpillars[c] > 0:
			if state.pick_caterpillar(c):
				player.viewmodel.play_pick()
				Sfx.play_at("squish", cell_world(c))
				refresh()
			return null
		match state.plants[c]:
			PlotState.Plant.BLIGHTED:
				return TugGame.blighted(self, c)
			PlotState.Plant.CUT:
				var product := state.crop.product_item
				var q := state.bind_cell(c)
				if q >= 0:
					player.viewmodel.play_pick()
					player.inventory.add(product, 1, q)
					player.needs.exert(0.3)
					Sfx.play_at("rustle", cell_world(c))
					refresh()
				return null
			PlotState.Plant.ALIVE:
				if state.is_ripe() and state.crop.harvest == CropData.Harvest.HANDS:
					return TugGame.harvest(self, c)
		return null
	if held == &"hoe" and not state.has_crop() and not state.is_tilled():
		return TillGame.new(self)
	if held == &"bucket" and player.bucket_water() > 0.0:
		return PourGame.new()
	if held == &"sickle" and state.is_ripe() and state.crop.harvest == CropData.Harvest.SICKLE:
		return ReapGame.new()
	if it and it.kind == ItemData.Kind.SEED and state.sow_error(Items.crop(it.crop), Clock.season()) == "":
		return SowGame.new(held)
	return null


## Harvest a hand-pulled cell; gives the produce to the player.
func harvest_by_hand(player: Player, c: int) -> void:
	var product := state.crop.product_item
	var q := state.harvest_cell(c)
	if q < 0:
		return
	player.inventory.add(product, 1, q)
	player.say("%s." % Items.name_of(product, q))
	refresh()


func daily_update(season: int, raining: bool, rng: RandomNumberGenerator) -> String:
	state.daily_update(season, raining, rng)
	refresh()
	return state.last_event


func to_dict() -> Dictionary:
	return state.to_dict()


func from_dict(d: Dictionary) -> void:
	state.from_dict(d, func(id: StringName) -> CropData: return Items.crop(id))
	refresh()
