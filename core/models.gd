class_name Models
extends RefCounted
## Model lookup by id: `res://assets/models/<id>.glb`. Missing models fall back to a simple
## coloured box so the game always runs while art is in progress.

const DIR := "res://assets/models"
## Items drawn with a model of a different name.
const ALIASES := {&"bread": &"food_loaf"}

static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}


static func exists(id: StringName) -> bool:
	return ResourceLoader.exists("%s/%s.glb" % [DIR, id])


static func make(id: StringName) -> Node3D:
	id = ALIASES.get(id, id)
	var path := "%s/%s.glb" % [DIR, id]
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _scenes[path]
	if scene:
		return scene.instantiate()
	return _fallback(id)


## A shared flat-coloured material.
static func mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


static func box(size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	mi.position = offset
	return mi


static func _fallback(id: StringName) -> Node3D:
	push_warning("Model missing, using placeholder: %s" % id)
	var root := Node3D.new()
	root.name = String(id)
	root.add_child(box(Vector3(0.2, 0.2, 0.2), Color(1, 0, 1)))
	return root
