"""Shared kit for FeudalSim2's model scripts: palette, materials, primitives, export.
Axes: Blender +Z is up and +Y is forward (Godot -Z)."""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets/models")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

# --- Palette (sRGB) ---------------------------------------------------------------------------
C = {
    "skin": (0.86, 0.66, 0.52), "linen": (0.72, 0.64, 0.5), "linen_dark": (0.5, 0.42, 0.32),
    "wood": (0.55, 0.38, 0.22), "wood_dark": (0.33, 0.22, 0.13), "wood_light": (0.72, 0.56, 0.36),
    "iron": (0.32, 0.32, 0.34), "iron_edge": (0.62, 0.62, 0.64), "rope": (0.7, 0.6, 0.4),
    "leather": (0.4, 0.26, 0.16), "straw": (0.86, 0.72, 0.4), "straw_dark": (0.66, 0.52, 0.28),
    "thatch": (0.66, 0.52, 0.3), "daub": (0.86, 0.8, 0.66), "stone": (0.58, 0.57, 0.54),
    "stone_dark": (0.42, 0.41, 0.4), "water": (0.18, 0.32, 0.38), "grain": (0.86, 0.72, 0.42),
    "wool": (0.5, 0.18, 0.14), "sack": (0.68, 0.58, 0.42), "clay": (0.62, 0.5, 0.38),
    "leaf": (0.33, 0.55, 0.2), "leaf_light": (0.5, 0.68, 0.3), "leaf_dark": (0.22, 0.42, 0.17),
    "cabbage": (0.55, 0.72, 0.42), "cabbage_heart": (0.75, 0.84, 0.55),
    "turnip_root": (0.92, 0.9, 0.82), "turnip_top": (0.58, 0.28, 0.5),
    "stalk_green": (0.45, 0.62, 0.25), "head_green": (0.55, 0.68, 0.3),
    "wheat_ripe": (0.9, 0.74, 0.36), "barley_ripe": (0.88, 0.8, 0.52),
    "blight": (0.36, 0.26, 0.14), "dead": (0.5, 0.42, 0.3), "crow": (0.07, 0.07, 0.09),
    "beak": (0.2, 0.18, 0.16), "caterpillar": (0.45, 0.7, 0.22), "thistle": (0.55, 0.35, 0.6),
    "flower_yellow": (0.95, 0.85, 0.25), "hearth": (0.25, 0.22, 0.2), "ember": (0.95, 0.45, 0.15), "pot": (0.55, 0.36, 0.25),
}


def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rough=0.9, emit=0.0):
    key = name if emit == 0 else name + "_emit"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    col = (*[srgb(c) for c in C[name]], 1.0)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def _finish(o, name, material, rot):
    o.name = name
    if rot:
        o.rotation_euler = [math.radians(a) for a in rot]
    if material:
        o.data.materials.clear()
        o.data.materials.append(mat(material) if isinstance(material, str) else material)
    return o


def box(name, size, loc, material, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    return _finish(o, name, material, rot)


def cyl(name, r, depth, loc, material, rot=None, verts=8, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc)
    return _finish(bpy.context.active_object, name, material, rot)


def ball(name, r, loc, material, scale=(1, 1, 1), subdiv=1, rot=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, name, material, rot)


def torus(name, r, thick, loc, material, rot=None, seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=seg, minor_segments=4, location=loc)
    return _finish(bpy.context.active_object, name, material, rot)


def segment(name, a, b, r, material, verts=6, r2=None):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    o = cyl(name, r, d.length, (a + b) / 2, material, verts=verts, r2=r2)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return o


def leaf(name, base, length, width, yaw, pitch, material, curl=0.0):
    """A flat diamond leaf from base, pointing along yaw (deg), raised by pitch (deg)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    pts = [(0, 0, 0), (width / 2, length * 0.4, curl * 0.5), (0, length, curl), (-width / 2, length * 0.4, curl * 0.5)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new(vs)
    bm.faces.new(list(reversed([bm.verts.new(p) for p in pts])))
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = base
    o.rotation_euler = (math.radians(pitch), 0, math.radians(yaw))
    o.data.materials.append(mat(material) if isinstance(material, str) else material)
    return o


def join(objs, name):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def set_origin(o, point):
    """Moves an object's origin to `point` (world) without moving its geometry."""
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0, 0, 0)


def attach(child, parent):
    """Parents without moving the child (keeps its world position)."""
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export(model_id):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, model_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    print("BUILT", model_id)


MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn



def plate(name, top, down, length, w_top, w_bot, t_top, t_bot, material, start=0.0, end=1.0):
    """A tapered flat plate (a blade): its top edge centred on `top`, running `length` along `down`,
    widening from w_top to w_bot across X and thinning from t_top to t_bot. start/end (0..1) cut a band."""
    top, down = Vector(top), Vector(down).normalized()
    side = Vector((1, 0, 0))
    face = down.cross(side).normalized()
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    for f in (start, end):
        c = top + down * length * f
        w = (w_top + (w_bot - w_top) * f) / 2
        t = (t_top + (t_bot - t_top) * f) / 2
        rows.append([bm.verts.new(c + side * sx * w + face * sz * t) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    a, b = rows
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([a[i], a[j], b[j], b[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o
