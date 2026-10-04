class_name Terrain
extends RefCounted
## The valley floor: flat around the farm, rolling hills further out.

const SIZE := 180.0
const STEP := 2.0
const FLAT_HALF := Vector2(34.0, 30.0)   ## Flat rectangle around the farm (x, z).

static var _noise: FastNoiseLite


static func height_at(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1187
		_noise.frequency = 0.018
	var d := maxf(absf(x) - FLAT_HALF.x, absf(z) - FLAT_HALF.y)
	var hills := smoothstep(0.0, 30.0, d)
	var gentle := _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.25 * (1.0 - hills)
	return gentle * smoothstep(4.0, 12.0, d) + hills * (6.0 + _noise.get_noise_2d(x, z) * 9.0)


static func build() -> Ground:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(SIZE / STEP)
	var half := SIZE / 2.0
	for iz in n:
		for ix in n:
			var x0 := -half + ix * STEP
			var z0 := -half + iz * STEP
			var quad := [Vector2(x0, z0), Vector2(x0 + STEP, z0), Vector2(x0 + STEP, z0 + STEP), Vector2(x0, z0 + STEP)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[idx]
				st.set_uv(p / 4.0)
				st.add_vertex(Vector3(p.x, height_at(p.x, p.y), p.y))
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = grass_material()
	var body := Ground.new()
	body.name = "Terrain"
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	return body


static func grass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/grass_ground_diff.jpg")
	m.albedo_color = Color(0.82, 0.95, 0.62)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/grass_ground_nor.jpg")
	m.roughness = 1.0
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return m
