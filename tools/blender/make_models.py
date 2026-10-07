"""Generates FeudalSim2's own low-poly models into assets/models/<id>.glb.

Run: Blender -b --factory-startup --python tools/blender/make_models.py -- [ids...]
With no ids, builds everything. Axes: Blender +Z is up and +Y is forward (Godot -Z).
Tools are modelled with the hand's grip at the origin and the handle running up +Z.
Named child objects (crank, well_bucket, swingle, wing_l, wing_r, water, grain, floor) are
looked up by the game for animation or state.
"""
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


# --- First-person arm -------------------------------------------------------------------------

@model
def fp_arm():
    parts = [
        segment("sleeve", (0, -0.5, -0.01), (0, 0.27, 0), 0.056, "linen", 8, r2=0.042),
        segment("cuff", (0, 0.25, 0), (0, 0.29, 0), 0.047, "linen_dark", 8),
        box("palm", (0.075, 0.09, 0.035), (0, 0.33, 0), "skin"),
        box("fingers", (0.072, 0.04, 0.045), (0, 0.38, -0.012), "skin", rot=(25, 0, 0)),
        # Palm faces down, so the thumb sits on the inner side (towards the body's centre).
        box("thumb", (0.022, 0.05, 0.022), (-0.045, 0.34, 0.01), "skin", rot=(0, 0, 30)),
    ]
    join(parts, "arm")
    export("fp_arm")


@model
def fp_arm_l():
    parts = [
        segment("sleeve", (0, -0.5, -0.01), (0, 0.27, 0), 0.056, "linen", 8, r2=0.042),
        segment("cuff", (0, 0.25, 0), (0, 0.29, 0), 0.047, "linen_dark", 8),
        box("palm", (0.075, 0.09, 0.035), (0, 0.33, 0), "skin"),
        box("fingers", (0.072, 0.04, 0.045), (0, 0.38, -0.012), "skin", rot=(25, 0, 0)),
        box("thumb", (0.022, 0.05, 0.022), (0.045, 0.34, 0.01), "skin", rot=(0, 0, -30)),
    ]
    join(parts, "arm")
    export("fp_arm_l")


# --- Tools ------------------------------------------------------------------------------------

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


@model
def hoe():
    # A draw hoe: an iron eye sleeved over the top of the shaft, a short goose-neck curving
    # forward, and a blade that flares towards its edge, angled back towards the user.
    neck = [(0, 0.022, 1.012), (0, 0.055, 1.03), (0, 0.09, 1.022), (0, 0.112, 0.992)]
    down = (0, -math.sin(math.radians(35)), -math.cos(math.radians(35)))
    blade_top = (0, 0.116, 0.99)
    parts = [
        segment("handle", (0, 0, -0.35), (0, 0, 1.02), 0.018, "wood", 8),
        cyl("eye", 0.027, 0.075, (0, 0, 1.0), "iron", verts=8),
        cyl("eye_cap", 0.027, 0.012, (0, 0, 1.043), "iron", verts=8, r2=0.018),
        plate("blade", blade_top, down, 0.135, 0.09, 0.17, 0.012, 0.005, "iron", 0.0, 0.84),
        plate("edge", blade_top, down, 0.135, 0.09, 0.17, 0.012, 0.002, "iron_edge", 0.84, 1.0),
    ]
    for i in range(len(neck) - 1):
        parts.append(segment(f"neck{i}", neck[i], neck[i + 1], 0.011 - i * 0.001, "iron", 6))
        if i > 0:
            parts.append(ball(f"knuckle{i}", 0.011 - i * 0.001, neck[i], "iron"))
    join(parts, "hoe")
    export("hoe")


@model
def bucket():
    staves = cyl("staves", 0.13, 0.24, (0, 0, -0.32), "wood_light", verts=12, r2=0.15)
    hoops = [torus(f"hoop{i}", 0.142 + i * 0.01, 0.008, (0, 0, -0.4 + i * 0.16), "iron", seg=12) for i in range(2)]
    arc = []
    for i in range(9):
        a0 = math.pi * i / 9
        a1 = math.pi * (i + 1) / 9
        arc.append(segment(f"h{i}", (math.cos(a0) * 0.15, 0, -0.2 + math.sin(a0) * 0.2), (math.cos(a1) * 0.15, 0, -0.2 + math.sin(a1) * 0.2), 0.007, "rope", 5))
    join([staves] + hoops + arc, "bucket")
    water = cyl("water", 0.145, 0.01, (0, 0, -0.23), "water", verts=12)
    water.name = "water"
    export("bucket")


@model
def sickle():
    parts = [segment("handle", (0, 0, -0.08), (0, 0, 0.1), 0.017, "wood", 6)]
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 22)
        pts.append(Vector((0, 0.13 + math.cos(a) * 0.15, 0.12 + 0.15 + math.sin(a) * 0.15)))
    for i in range(len(pts) - 1):
        parts.append(segment(f"b{i}", pts[i], pts[i + 1], 0.012 - i * 0.0009, "iron_edge", 4))
    parts.append(segment("tang", (0, 0, 0.1), pts[0], 0.01, "iron", 4))
    join(parts, "sickle")
    export("sickle")


@model
def flail():
    staff = join([segment("staff", (0, 0, -0.35), (0, 0, 0.75), 0.017, "wood", 6),
                  torus("cap", 0.02, 0.008, (0, 0, 0.75), "leather", seg=8)], "staff")
    swingle = join([segment("swingle", (0, 0, 0.78), (0, 0.0, 1.3), 0.024, "wood_dark", 6),
                    torus("link", 0.022, 0.008, (0, 0, 0.78), "leather", rot=(90, 0, 0), seg=8)], "swingle")
    set_origin(swingle, (0, 0, 0.77))
    attach(swingle, staff)
    export("flail")


@model
def winnowing_basket():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=7, radius=0.34, location=(0, 0, 0.08))
    b = bpy.context.active_object
    b.scale = (1.0, 0.85, 0.32)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(b.data)
    for v in [v for v in bm.verts if v.co.z > 0.0]:
        bm.verts.remove(v)
    bmesh.update_edit_mesh(b.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    _finish(b, "basket", "straw_dark", None)
    sol = b.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.015
    rim = torus("rim", 0.335, 0.015, (0, 0, 0.08), "wood", seg=14)
    rim.scale = (1.0, 0.85, 1)
    join([b, rim], "winnowing_basket")
    grain = ball("grain", 0.24, (0, 0, 0.03), "grain", scale=(1, 0.8, 0.18), subdiv=2)
    grain.name = "grain"
    export("winnowing_basket")


@model
def seed_pouch():
    bag = ball("bag", 0.07, (0, 0.0, 0.02), "sack", scale=(1, 0.9, 1.1))
    neck = cyl("neck", 0.04, 0.04, (0, 0, 0.09), "sack", verts=8, r2=0.05)
    seeds = cyl("seeds", 0.042, 0.01, (0, 0, 0.11), "grain", verts=8)
    tie = torus("tie", 0.045, 0.006, (0, 0, 0.075), "rope", seg=8)
    join([bag, neck, seeds, tie], "seed_pouch")
    export("seed_pouch")


@model
def scarecrow():
    parts = [
        segment("pole", (0, 0, 0), (0, 0, 1.9), 0.035, "wood", 6),
        segment("arms", (-0.75, 0, 1.45), (0.75, 0, 1.45), 0.03, "wood", 6),
        box("shirt", (0.55, 0.25, 0.6), (0, 0, 1.25), "linen_dark"),
        box("sleeve_l", (0.45, 0.2, 0.18), (-0.45, 0, 1.43), "linen_dark"),
        box("sleeve_r", (0.45, 0.2, 0.18), (0.45, 0, 1.43), "linen_dark"),
        ball("head", 0.17, (0, 0, 1.75), "sack", scale=(1, 1, 1.1)),
        cyl("brim", 0.3, 0.03, (0, 0, 1.88), "straw_dark", verts=10),
        cyl("crown", 0.14, 0.2, (0, 0, 1.98), "straw_dark", verts=10, r2=0.1),
        box("rope", (0.57, 0.27, 0.04), (0, 0, 1.0), "rope"),
    ]
    random.seed(4)
    for i in range(14):
        side = -1 if i % 2 else 1
        parts.append(segment(f"straw{i}", (side * 0.68, 0, 1.45 + random.uniform(-0.05, 0.05)),
                             (side * random.uniform(0.75, 0.85), random.uniform(-0.08, 0.08), 1.38 + random.uniform(-0.1, 0.05)), 0.008, "straw", 4))
    for i in range(8):
        a = i / 8 * math.tau
        parts.append(segment(f"hem{i}", (math.cos(a) * 0.2, math.sin(a) * 0.1, 0.96), (math.cos(a) * 0.25, math.sin(a) * 0.12, 0.82), 0.01, "straw", 4))
    join(parts, "scarecrow")
    export("scarecrow")


# --- Crops ------------------------------------------------------------------------------------
# Each crop has stages 0..3 (sprout, young, mature, ripe) plus _blight and _dead variants of
# the mature/ripe look. A plant fills one plot cell (~0.7 m).

def _variant_material(name, variant):
    if variant == "blight":
        return {"leaf": "blight", "leaf_light": "leaf_dark", "cabbage": "blight", "cabbage_heart": "leaf_dark",
                "stalk_green": "blight", "head_green": "blight", "wheat_ripe": "blight", "barley_ripe": "blight",
                "turnip_top": "blight"}.get(name, name)
    if variant == "dead":
        return "dead" if name != "turnip_root" else "dead"
    return name


def _turnip(stage, v):
    random.seed(10 + stage)
    parts = []
    n = [2, 4, 6, 7][stage]
    length = [0.06, 0.14, 0.24, 0.28][stage]
    droop = 25 if v == "dead" else 0
    for i in range(n):
        yaw = i * 360 / n + random.uniform(-15, 15)
        parts.append(leaf(f"l{i}", (0, 0, 0.01), length * random.uniform(0.85, 1.1), length * 0.45, yaw,
                          random.uniform(55, 70) - droop, _variant_material("leaf" if i % 2 else "leaf_light", v), curl=-0.02))
    if stage >= 2:
        r = 0.035 if stage == 2 else 0.055
        parts.append(ball("root", r, (0, 0, r * 0.4), _variant_material("turnip_root", v), scale=(1, 1, 0.8)))
        parts.append(ball("top", r * 0.95, (0, 0, r * 0.75), _variant_material("turnip_top", v), scale=(1, 1, 0.5)))
    return parts


def _cabbage(stage, v):
    random.seed(20 + stage)
    parts = []
    n = [2, 5, 7, 9][stage]
    length = [0.06, 0.15, 0.22, 0.26][stage]
    for i in range(n):
        yaw = i * 360 / n + random.uniform(-10, 10)
        parts.append(leaf(f"l{i}", (0, 0, 0.01), length, length * 0.8, yaw, random.uniform(25, 45),
                          _variant_material("cabbage", v), curl=0.03))
    if stage >= 2:
        r = 0.08 if stage == 2 else 0.13
        parts.append(ball("head", r, (0, 0, r * 0.8), _variant_material("cabbage_heart", v), scale=(1, 1, 0.85), subdiv=2))
    return parts


def _grain(stage, v, kind):
    random.seed(30 + stage + (5 if kind == "barley" else 0))
    parts = []
    height = [0.12, 0.35, 0.7, 0.85][stage] * (0.9 if kind == "barley" else 1.0)
    ripe = stage == 3
    stalk_m = _variant_material(("wheat_ripe" if kind == "wheat" else "barley_ripe") if ripe else "stalk_green", v)
    head_m = _variant_material(("wheat_ripe" if kind == "wheat" else "barley_ripe") if ripe else "head_green", v)
    if v == "dead":
        height *= 0.6
    for i in range(11):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.0, 0.2)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        lean = Vector((random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), 0))
        if kind == "barley" and ripe:
            lean *= 2.2
        top = base + lean + Vector((0, 0, height * random.uniform(0.85, 1.05)))
        if stage == 0:
            parts.append(leaf(f"s{i}", base, height, 0.02, random.uniform(0, 360), random.uniform(70, 85), stalk_m))
            continue
        parts.append(segment(f"stalk{i}", base, top, 0.006, stalk_m, 4))
        parts.append(leaf(f"lf{i}", base + Vector((0, 0, height * 0.3)), height * 0.4, 0.03, random.uniform(0, 360), 50, stalk_m))
        if stage >= 2:
            hl = 0.09 if kind == "wheat" else 0.07
            d = (top - base).normalized()
            parts.append(segment(f"head{i}", top, top + d * hl, 0.014 if kind == "wheat" else 0.011, head_m, 5, r2=0.006))
            if kind == "barley":
                for k in range(3):
                    parts.append(segment(f"awn{i}{k}", top + d * hl * 0.5, top + d * (hl + 0.08) + Vector((random.uniform(-0.02, 0.02), random.uniform(-0.02, 0.02), 0)), 0.002, head_m, 3))
    return parts


def _bolted(crop):
    """A biennial gone to seed: its leaves, plus a tall flowering stalk."""
    random.seed(40 + len(crop))
    parts = (_turnip if crop == "turnip" else _cabbage)(2, "")
    height = 0.75 if crop == "turnip" else 0.9
    for k in range(3):
        top = Vector((random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), height * random.uniform(0.8, 1.0)))
        parts.append(segment(f"stalk{k}", (0, 0, 0.08), top, 0.009, "stalk_green", 5))
        for j in range(6):
            p = top + Vector((random.uniform(-0.07, 0.07), random.uniform(-0.07, 0.07), random.uniform(-0.12, 0.04)))
            parts.append(ball(f"flower{k}{j}", 0.018, p, "flower_yellow", subdiv=1))
            parts.append(segment(f"pod{k}{j}", p, p + Vector((random.uniform(-0.03, 0.03), random.uniform(-0.03, 0.03), 0.05)), 0.004, "straw", 3))
    return parts


CROPS = {"turnip": _turnip, "cabbage": _cabbage,
         "barley": lambda s, v: _grain(s, v, "barley"), "wheat": lambda s, v: _grain(s, v, "wheat")}


def _crop_models():
    for crop, fn in CROPS.items():
        for stage in range(4):
            def build(crop=crop, fn=fn, stage=stage):
                join(fn(stage, ""), crop)
                export(f"{crop}_s{stage}")
            MODELS[f"{crop}_s{stage}"] = build
        for v in ("blight", "dead"):
            def build_v(crop=crop, fn=fn, v=v):
                join(fn(2, v), crop)
                export(f"{crop}_{v}")
            MODELS[f"{crop}_{v}"] = build_v


_crop_models()

for _c in ("turnip", "cabbage"):
    def _build_bolt(c=_c):
        join(_bolted(c), c)
        export(f"{c}_bolt")
    MODELS[f"{_c}_bolt"] = _build_bolt


@model
def turnip():
    """Harvested turnip (item)."""
    parts = [ball("root", 0.06, (0, 0, 0.05), "turnip_root", scale=(1, 1, 0.9)),
             ball("top", 0.058, (0, 0, 0.08), "turnip_top", scale=(1, 1, 0.5)),
             segment("tail", (0, 0, 0.0), (0, 0, -0.05), 0.012, "turnip_root", 5, r2=0.002)]
    for i in range(4):
        parts.append(leaf(f"l{i}", (0, 0, 0.1), 0.14, 0.06, i * 90, 75, "leaf"))
    join(parts, "turnip")
    export("turnip")


@model
def cabbage():
    parts = [ball("head", 0.1, (0, 0, 0.09), "cabbage_heart", scale=(1, 1, 0.9), subdiv=2)]
    for i in range(6):
        parts.append(leaf(f"l{i}", (0, 0, 0.02), 0.13, 0.12, i * 60, 55, "cabbage", curl=0.04))
    join(parts, "cabbage")
    export("cabbage")


def _sheaf_parts(length=0.9, kind="wheat"):
    random.seed(7)
    parts = []
    col = "wheat_ripe" if kind == "wheat" else "barley_ripe"
    for i in range(22):
        a = random.uniform(0, math.tau)
        r = random.uniform(0, 0.07)
        x, y = math.cos(a) * r, math.sin(a) * r
        top = Vector((x * 2.2, y * 2.2, length))
        parts.append(segment(f"st{i}", (x * 1.3, y * 1.3, 0), top, 0.006, col, 4))
        parts.append(segment(f"hd{i}", top, top + Vector((x * 0.6, y * 0.6, 0.08)), 0.014, col, 5, r2=0.006))
    parts.append(torus("band", 0.075, 0.012, (0, 0, length * 0.42), "straw_dark", seg=10))
    return parts


@model
def wheat_sheaf():
    join(_sheaf_parts(0.9, "wheat"), "sheaf")
    export("wheat_sheaf")


@model
def barley_sheaf():
    join(_sheaf_parts(0.8, "barley"), "sheaf")
    export("barley_sheaf")


@model
def grain_pile():
    join([ball("pile", 0.4, (0, 0, 0), "grain", scale=(1, 1, 0.4), subdiv=2)], "grain_pile")
    export("grain_pile")


@model
def chaff_pile():
    join([ball("pile", 0.4, (0, 0, 0), "straw_dark", scale=(1, 1, 0.35), subdiv=2),
          ball("grain", 0.25, (0.05, 0.05, 0.06), "grain", scale=(1, 1, 0.4), subdiv=1)], "chaff_pile")
    export("chaff_pile")


@model
def grain_sack():
    join([ball("sack", 0.2, (0, 0, 0.25), "sack", scale=(1, 0.85, 1.4), subdiv=2),
          cyl("neck", 0.06, 0.1, (0, 0, 0.55), "sack", verts=8, r2=0.03),
          torus("tie", 0.06, 0.01, (0, 0, 0.53), "rope", seg=8)], "grain_sack")
    export("grain_sack")


# --- Pests and weeds --------------------------------------------------------------------------

@model
def weed():
    random.seed(3)
    parts = []
    for i in range(7):
        parts.append(leaf(f"l{i}", (0, 0, 0.0), random.uniform(0.12, 0.2), 0.05, i * 51, random.uniform(20, 40), "leaf_dark", curl=0.02))
    for i in range(3):
        top = Vector((random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), random.uniform(0.25, 0.35)))
        parts.append(segment(f"stem{i}", (0, 0, 0), top, 0.006, "leaf_dark", 4))
        parts.append(ball(f"flower{i}", 0.025, top, "thistle", scale=(1, 1, 1.3)))
    join(parts, "weed")
    export("weed")


@model
def caterpillar():
    parts = [ball(f"seg{i}", 0.011 - abs(i - 2) * 0.001, (0, i * 0.016, 0.01 + (0.006 if i in (1, 2) else 0)), "caterpillar") for i in range(5)]
    parts.append(ball("head", 0.011, (0, 0.085, 0.012), "leaf_dark"))
    join(parts, "caterpillar")
    export("caterpillar")


@model
def crow():
    body = join([ball("body", 0.1, (0, 0, 0.16), "crow", scale=(0.75, 1.3, 0.8)),
                 ball("head", 0.06, (0, 0.13, 0.24), "crow"),
                 cyl("beak", 0.02, 0.07, (0, 0.2, 0.235), "beak", rot=(-90, 0, 0), verts=5, r2=0.0),
                 box("tail", (0.08, 0.14, 0.015), (0, -0.17, 0.15), "crow", rot=(15, 0, 0)),
                 segment("leg_l", (-0.03, 0, 0.1), (-0.03, 0.01, 0.0), 0.006, "beak", 4),
                 segment("leg_r", (0.03, 0, 0.1), (0.03, 0.01, 0.0), 0.006, "beak", 4)], "crow")
    for side in (-1, 1):
        w = box("wing_l" if side < 0 else "wing_r", (0.2, 0.16, 0.015), (side * 0.13, -0.01, 0.19), "crow", rot=(0, side * -12, 0))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        set_origin(w, (side * 0.05, 0, 0.19))
        attach(w, body)
    export("crow")


# --- Buildings and fixtures -------------------------------------------------------------------

@model
def house():
    """A one-room wattle-and-daub cottage, 6 x 5 m, door facing +Y (Godot -Z ... rotated in game)."""
    W, D, H = 6.0, 5.0, 2.4
    t = 0.2
    parts = []
    floor = box("floor", (W - 0.2, D - 0.2, 0.08), (0, 0, 0.04), "wood_light")
    floor.name = "floor"
    # Walls with a door gap (front, +Y) and window gaps.
    def wall_x(y, gaps):
        x = -W / 2
        for g0, g1 in gaps + [(W / 2, W / 2)]:
            if g0 > x:
                parts.append(box("w", (g0 - x, t, H), ((x + g0) / 2, y, H / 2), "daub"))
            x = g1
    wall_x(D / 2, [(-0.55, 0.55)])
    # Window in the back wall: lower and upper pieces around the gap.
    wall_x(-D / 2, [(1.2, 2.2)])
    parts.append(box("sill", (1.0, t, 1.0), (1.7, -D / 2, 0.5), "daub"))
    parts.append(box("lintel", (1.0, t, 0.5), (1.7, -D / 2, H - 0.25), "daub"))
    parts.append(box("wl", (t, D, H), (-W / 2, 0, H / 2), "daub"))
    parts.append(box("wr", (t, D, H), (W / 2, 0, H / 2), "daub"))
    parts.append(box("lintel_door", (1.1, t, H - 1.95), (0, D / 2, (H + 1.95) / 2), "daub"))
    # Timber frame.
    for x in (-W / 2, -1.5, 0.55, -0.55, 1.5, W / 2):
        for y in (D / 2 + 0.01, -D / 2 - 0.01):
            if y < 0 and x in (0.55, -0.55):
                continue
            parts.append(box("post", (0.16, 0.06 if abs(x) < W / 2 else 0.24, H), (x, y, H / 2), "wood_dark"))
    for y in (D / 2 + 0.02, -D / 2 - 0.02):
        parts.append(box("beam", (W + 0.1, 0.06, 0.16), (0, y, H - 0.08), "wood_dark"))
        if y > 0:   # front: leave the doorway clear
            parts.append(box("sole", ((W + 0.1) / 2 - 0.55, 0.06, 0.16), (-(W + 0.1) / 4 - 0.275, y, 0.08), "wood_dark"))
            parts.append(box("sole", ((W + 0.1) / 2 - 0.55, 0.06, 0.16), ((W + 0.1) / 4 + 0.275, y, 0.08), "wood_dark"))
        else:
            parts.append(box("sole", (W + 0.1, 0.06, 0.16), (0, y, 0.08), "wood_dark"))
    for x in (-W / 2 - 0.02, W / 2 + 0.02):
        parts.append(box("beam", (0.06, D, 0.16), (x, 0, H - 0.08), "wood_dark"))
        parts.append(segment("brace", (x, -D / 2 + 0.2, 0.2), (x, -0.3, H - 0.2), 0.05, "wood_dark", 4))
    # Gable ends (triangles) and a steep thatched roof.
    ridge = H + 2.2
    for x in (-W / 2, W / 2):
        me = bpy.data.meshes.new("gable")
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in [(x, -D / 2, H), (x, D / 2, H), (x, 0, ridge)]]
        bm.faces.new(vs)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=t)
        bm.to_mesh(me)
        g = bpy.data.objects.new("gable", me)
        bpy.context.collection.objects.link(g)
        g.data.materials.append(mat("daub"))
        parts.append(g)
    slope = math.atan2(2.2, D / 2)
    run = math.hypot(2.2, D / 2) + 0.7
    for side in (-1, 1):
        parts.append(box("thatch", (W + 0.9, run, 0.35), (0, side * (D / 4 + 0.3), H + 1.1 - 0.12), "thatch", rot=(side * -math.degrees(slope), 0, 0)))
    parts.append(box("ridge", (W + 0.95, 0.4, 0.3), (0, 0, ridge + 0.05), "straw_dark", rot=(45, 0, 0)))
    # Fireplace: a stone chimney breast on the left gable wall with an open firebox, and the
    # chimney stack running up the outside of the gable.
    fx, fy = -W / 2 + t / 2, -0.9          # inner face of the wall, centre of the fireplace
    parts += [
        box("jamb_l", (0.6, 0.32, 1.0), (fx + 0.3, fy - 0.61, 0.5), "stone"),
        box("jamb_r", (0.6, 0.32, 1.0), (fx + 0.3, fy + 0.61, 0.5), "stone"),
        box("firebox_back", (0.06, 0.9, 1.0), (fx + 0.03, fy, 0.5), "hearth"),
        box("firebox_top", (0.6, 0.9, 0.06), (fx + 0.3, fy, 0.97), "hearth"),
        box("mantel", (0.7, 1.6, 0.14), (fx + 0.33, fy, 1.07), "wood_dark"),
        box("breast", (0.5, 1.3, H - 1.14), (fx + 0.25, fy, 1.14 + (H - 1.14) / 2), "stone"),
        box("hearthstone", (0.9, 1.6, 0.06), (fx + 0.45, fy, 0.03), "stone_dark"),
        box("stack", (0.9, 1.3, H + 2.9), (-W / 2 - 0.45 - t / 2, fy, (H + 2.9) / 2), "stone"),
        box("stack_cap", (1.0, 1.4, 0.15), (-W / 2 - 0.45 - t / 2, fy, H + 2.9), "stone_dark"),
        box("pot_on_mantel", (0.12, 0.12, 0.16), (fx + 0.33, fy + 0.5, 1.22), "pot"),
    ]
    for i in range(3):
        parts.append(segment(f"log{i}", (fx + 0.15, fy - 0.3 + i * 0.3, 0.1), (fx + 0.5, fy - 0.15 + i * 0.15, 0.12), 0.045, "wood_dark", 5))
    flames = [cyl(f"flame{i}", 0.09 - i * 0.02, 0.35 - i * 0.06, (fx + 0.3 + (i - 1) * 0.04, fy + (i - 1) * 0.12, 0.3), mat("ember", 0.9, emit=4.0), verts=6, r2=0.0) for i in range(3)]
    flames.append(box("coals", (0.4, 0.6, 0.04), (fx + 0.3, fy, 0.08), mat("ember", 0.9, emit=2.0)))
    fire = join(flames, "fire")
    set_origin(fire, (fx + 0.3, fy, 0.08))
    bx, by = W / 2 - 1.05, -D / 2 + 1.25
    parts += [
        box("bed_frame", (1.0, 2.0, 0.35), (bx, by, 0.25), "wood"),
        box("mattress", (0.9, 1.9, 0.18), (bx, by, 0.5), "straw"),
        box("blanket", (0.95, 1.2, 0.06), (bx, by - 0.3, 0.6), "wool"),
        box("pillow", (0.6, 0.3, 0.12), (bx, by + 0.75, 0.62), "linen"),
        box("headboard", (1.0, 0.08, 0.8), (bx, by + 1.0, 0.45), "wood_dark"),
    ]
    tx, ty = -0.6, 0.2
    parts += [box("table_top", (1.4, 0.8, 0.06), (tx, ty, 0.78), "wood")]
    for dx in (-0.6, 0.6):
        for dy in (-0.32, 0.32):
            parts.append(box("leg", (0.07, 0.07, 0.75), (tx + dx, ty + dy, 0.375), "wood_dark"))
    for sx in (-0.4, 0.4):
        parts.append(cyl("stool", 0.18, 0.05, (tx + sx, ty - 0.7, 0.45), "wood", verts=8))
        parts.append(cyl("stool_leg", 0.05, 0.43, (tx + sx, ty - 0.7, 0.22), "wood_dark", verts=6))
    parts.append(box("bowl", (0.2, 0.2, 0.06), (tx + 0.2, ty, 0.84), "pot"))
    parts.append(ball("loaf", 0.09, (tx - 0.3, ty + 0.1, 0.86), "straw_dark", scale=(1.3, 1, 0.7)))
    sx, sy = -W / 2 + 0.2, 1.2
    for z in (1.0, 1.5):
        parts.append(box("shelf", (0.3, 1.4, 0.04), (sx, sy, z), "wood"))
    for i in range(3):
        parts.append(cyl("jar", 0.07, 0.18, (sx + 0.05, sy - 0.4 + i * 0.4, 1.11), "pot", verts=8, r2=0.05))
    parts.append(cyl("barrel", 0.3, 0.8, (W / 2 - 0.5, D / 2 - 0.5, 0.4), "wood_light", verts=10))
    parts.append(box("door", (0.08, 1.0, 1.9), (0.55 + 0.45, D / 2 + 0.45, 0.95), "wood_dark", rot=(0, 0, 0)))
    join(parts, "house")
    export("house")


@model
def barrel():
    random.seed(12)
    parts = [cyl("staves", 0.3, 0.84, (0, 0, 0.42), "wood_light", verts=12, r2=0.3)]
    # Bulge the middle by stacking a slightly wider band.
    parts.append(cyl("belly", 0.33, 0.4, (0, 0, 0.42), "wood_light", verts=12))
    for z in (0.1, 0.32, 0.52, 0.74):
        parts.append(torus(f"hoop{z}", 0.315 if z in (0.1, 0.74) else 0.335, 0.012, (0, 0, z), "iron", seg=12))
    parts.append(cyl("lid", 0.285, 0.02, (0, 0, 0.84), "wood", verts=12))
    join(parts, "barrel")
    export("barrel")


@model
def crate():
    parts = []
    S = 0.6
    for side in range(4):
        a = side * math.pi / 2
        for k in range(3):
            parts.append(box(f"slat{side}{k}", (S, 0.03, 0.16), (math.cos(a) * (S / 2 - 0.015) if side % 2 == 0 else 0, math.sin(a) * (S / 2 - 0.015) if side % 2 else 0, 0.1 + k * 0.2), "wood_light", rot=(0, 0, math.degrees(a) + 90)))
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(box("corner", (0.05, 0.05, S), (x * (S / 2 - 0.025), y * (S / 2 - 0.025), S / 2), "wood_dark"))
    parts.append(box("bottom", (S, S, 0.03), (0, 0, 0.015), "wood"))
    parts.append(box("lid1", (S, 0.18, 0.03), (0, -0.2, S), "wood"))
    parts.append(box("lid2", (S, 0.18, 0.03), (0, 0.02, S), "wood"))
    join(parts, "crate")
    export("crate")


@model
def lantern_post():
    parts = [box("post", (0.14, 0.14, 2.2), (0, 0, 1.1), "wood_dark"),
             box("arm", (0.6, 0.08, 0.08), (0.27, 0, 2.1), "wood_dark"),
             segment("brace", (0, 0, 1.8), (0.3, 0, 2.08), 0.025, "wood_dark", 4),
             segment("hook", (0.5, 0, 2.08), (0.5, 0, 1.95), 0.008, "iron", 4),
             box("cage_top", (0.2, 0.2, 0.04), (0.5, 0, 1.94), "iron"),
             box("cage_bottom", (0.18, 0.18, 0.03), (0.5, 0, 1.68), "iron")]
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(box("bar", (0.015, 0.015, 0.26), (0.5 + x * 0.08, y * 0.08, 1.81), "iron"))
    join(parts, "lantern_post")
    glow = cyl("candle", 0.03, 0.12, (0.5, 0, 1.77), mat("ember", 0.9, emit=5.0), verts=6)
    glow.name = "candle"
    export("lantern_post")


@model
def farm_cart():
    """A two-wheeled wooden farm cart with shafts, bed along +Y."""
    parts = [box("bed", (1.3, 2.0, 0.08), (0, 0, 0.75), "wood"),
             box("side_l", (0.06, 2.0, 0.35), (-0.62, 0, 0.95), "wood_light"),
             box("side_r", (0.06, 2.0, 0.35), (0.62, 0, 0.95), "wood_light"),
             box("back", (1.3, 0.06, 0.35), (0, -0.97, 0.95), "wood_light"),
             box("front", (1.3, 0.06, 0.35), (0, 0.97, 0.95), "wood_light"),
             segment("axle", (-0.8, 0, 0.45), (0.8, 0, 0.45), 0.04, "wood_dark", 6),
             segment("shaft_l", (-0.45, 0.9, 0.72), (-0.4, 2.4, 0.45), 0.04, "wood_dark", 6),
             segment("shaft_r", (0.45, 0.9, 0.72), (0.4, 2.4, 0.45), 0.04, "wood_dark", 6),
             box("prop", (0.06, 0.06, 0.45), (0, 2.2, 0.22), "wood_dark")]
    for side in (-1, 1):
        x = side * 0.78
        parts.append(torus(f"rim{side}", 0.42, 0.04, (x, 0, 0.45), "wood_dark", rot=(0, 90, 0), seg=16))
        parts.append(cyl(f"hub{side}", 0.08, 0.14, (x, 0, 0.45), "wood", rot=(0, 90, 0), verts=8))
        for k in range(8):
            a = k / 8 * math.tau
            parts.append(segment(f"spoke{side}{k}", (x, 0, 0.45), (x, math.cos(a) * 0.4, 0.45 + math.sin(a) * 0.4), 0.018, "wood", 4))
    join(parts, "farm_cart")
    export("farm_cart")


@model
def well():
    parts = []
    for i in range(12):
        a = i / 12 * math.tau
        parts.append(box(f"st{i}", (0.42, 0.24, 0.8), (math.cos(a) * 0.72, math.sin(a) * 0.72, 0.4), "stone" if i % 2 else "stone_dark", rot=(0, 0, math.degrees(a) + 90)))
    parts.append(torus("cap", 0.74, 0.12, (0, 0, 0.82), "stone", seg=12))
    parts.append(cyl("water", 0.62, 0.02, (0, 0, 0.1), "water", verts=12))
    for x in (-0.85, 0.85):
        parts.append(box("post", (0.14, 0.14, 2.2), (x, 0, 1.1), "wood_dark"))
    parts.append(box("roof_l", (2.1, 0.9, 0.06), (0, -0.33, 2.35), "thatch", rot=(35, 0, 0)))
    parts.append(box("roof_r", (2.1, 0.9, 0.06), (0, 0.33, 2.35), "thatch", rot=(-35, 0, 0)))
    join(parts, "well")
    axle = join([segment("axle", (-0.85, 0, 1.6), (0.85, 0, 1.6), 0.06, "wood", 8),
                 cyl("rope_coil", 0.085, 0.4, (0, 0, 1.6), "rope", rot=(0, 90, 0), verts=10),
                 segment("arm", (1.0, 0, 1.6), (1.0, 0, 1.3), 0.025, "iron", 5),
                 segment("pin", (0.85, 0, 1.6), (1.0, 0, 1.6), 0.025, "iron", 5),
                 segment("grip", (1.0, 0, 1.3), (1.18, 0, 1.3), 0.025, "wood", 5)], "crank")
    set_origin(axle, (0, 0, 1.6))
    b = join([cyl("staves", 0.12, 0.22, (0, 0, -0.11), "wood_light", verts=10, r2=0.14),
              torus("hoop", 0.135, 0.007, (0, 0, -0.06), "iron", seg=10),
              segment("rope", (0, 0, 0.0), (0, 0, 0.6), 0.01, "rope", 4)], "well_bucket")
    set_origin(b, (0, 0, 0.6))
    b.location = (0, 0.0, 1.0)
    export("well")


@model
def threshing_floor():
    parts = [cyl("floor", 2.3, 0.08, (0, 0, 0.04), "clay", verts=20)]
    random.seed(9)
    for i in range(30):
        a = random.uniform(0, math.tau)
        r = random.uniform(0.2, 2.0)
        parts.append(cyl(f"flag{i}", random.uniform(0.15, 0.28), 0.03, (math.cos(a) * r, math.sin(a) * r, 0.085), "stone", verts=6))
    for i in range(20):
        a = i / 20 * math.tau
        parts.append(box(f"curb{i}", (0.74, 0.14, 0.14), (math.cos(a) * 2.35, math.sin(a) * 2.35, 0.07), "wood_dark", rot=(0, 0, math.degrees(a) + 90)))
    join(parts, "threshing_floor")
    export("threshing_floor")


@model
def bed_marker():
    """Not drawn: keeps the bed's interaction box sized in one place."""
    pass


@model
def signboard():
    parts = [segment("post", (0, 0, 0), (0, 0, 1.6), 0.05, "wood_dark", 6),
             box("board", (1.7, 0.06, 0.42), (0, 0, 1.45), "wood_light"),
             box("trim", (1.76, 0.07, 0.04), (0, 0, 1.67), "wood_dark")]
    join(parts, "signboard")
    export("signboard")


def main():
    os.makedirs(OUT, exist_ok=True)
    names = args or [n for n in MODELS if n != "bed_marker"]
    for n in names:
        reset()
        MODELS[n]()


main()
