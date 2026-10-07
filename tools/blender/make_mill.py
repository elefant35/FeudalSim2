"""Generates the windmill (milling chunk) models into assets/models/<id>.glb.

Run: Blender -b --factory-startup --python tools/blender/make_mill.py -- [ids...]
The layout matches milling/post_mill.gd, so positions here are written in Godot's axes with
G(x, y, z) (x right, y up, z back; the sails face -z) and converted to Blender's.
Named objects the game looks up: post_mill_body: grain, meal, brake_lever, tenter_lever;
post_mill_sails: cloth_0..cloth_3 (scaled across their width to reef them).
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *  # noqa: E402,F401

C.update({
    "board": (0.84, 0.8, 0.7), "board_line": (0.62, 0.58, 0.5), "roof": (0.36, 0.3, 0.26),
    "brick": (0.62, 0.34, 0.25), "canvas": (0.9, 0.86, 0.76), "flour": (0.95, 0.93, 0.88),
    "millstone": (0.62, 0.6, 0.57), "flour_sack": (0.86, 0.82, 0.72), "shutter": (0.3, 0.36, 0.3),
})

FLOOR = 2.6
HX, HZ = 1.8, 2.2
EAVE, RIDGE = 5.3, 6.4
HUB = (0, 5.4, -2.75)
TAIL_END = (0.8, 0.9, 6.4)
STEPS_FOOT = (0, 0, 5.9)


def G(x, y, z):
    """Godot coordinates -> Blender."""
    return (x, -z, y)


def gsize(x, y, z):
    """A box size given in Godot axes -> Blender axes."""
    return (x, z, y)


def gbox(name, size, at, material, rot_y=0.0):
    o = box(name, gsize(*size), G(*at), material)
    if rot_y:
        o.rotation_euler = (0, 0, math.radians(rot_y))
    return o


def gseg(name, a, b, r, material, verts=6):
    return segment(name, G(*a), G(*b), r, material, verts)


def solidify(o, thickness):
    """Gives a sheet some thickness (applied now, so it survives joining)."""
    m = o.modifiers.new("solid", "SOLIDIFY")
    m.thickness = thickness
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)
    return o


def mesh_obj(name, verts, faces, material):
    me = bpy.data.meshes.new(name)
    me.from_pydata([G(*v) for v in verts], [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def open_box(name, size, center, material, wall=0.03):
    """A box with no lid (a bin), in Godot axes, centred on `center`."""
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    cx, cy, cz = center
    v = [(cx + x, cy + y, cz + z) for x, y, z in
         [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz),
          (-sx, sy, -sz), (sx, sy, -sz), (sx, sy, sz), (-sx, sy, sz)]]
    faces = [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return solidify(mesh_obj(name, v, faces, material), wall)


# --- The trestle: brick piers, crosstrees, quarterbars and the great post ---------------------

@model
def post_mill_trestle():
    parts = []
    for i, (x, z) in enumerate([(2.1, 0), (-2.1, 0), (0, 2.1), (0, -2.1)]):
        parts.append(gbox(f"pier{i}", (0.75, 0.6, 0.75), (x, 0.3, z), "brick"))
    parts.append(gbox("cross_x", (4.9, 0.32, 0.34), (0, 0.76, 0), "wood_dark"))
    parts.append(gbox("cross_z", (0.34, 0.32, 4.9), (0, 0.76, 0), "wood_dark"))
    parts.append(gseg("post", (0, 0.6, 0), (0, FLOOR - 0.15, 0), 0.32, "wood_dark", 8))
    for i, (x, z) in enumerate([(1.95, 0), (-1.95, 0), (0, 1.95), (0, -1.95)]):
        parts.append(gseg(f"quarter{i}", (x, 0.9, z), (x * 0.14, 2.05, z * 0.14), 0.11, "wood_dark", 6))
    join(parts, "trestle")
    export("post_mill_trestle")


# --- The body: the timber box that turns, with the stones, hopper and levers inside ------------

@model
def post_mill_body():
    parts = []
    # Floor, crown tree (the beam that rides on the post) and sills.
    parts.append(gbox("floor", (HX * 2, 0.14, HZ * 2), (0, FLOOR - 0.07, 0), "wood_light"))
    parts.append(gbox("crown", (HX * 2 + 0.2, 0.42, 0.5), (0, FLOOR - 0.35, 0), "wood_dark"))
    for z in (-HZ + 0.15, HZ - 0.15):
        parts.append(gbox(f"sill{int(z > 0)}", (HX * 2 + 0.2, 0.26, 0.26), (0, FLOOR - 0.27, z), "wood_dark"))
    # Walls (weatherboarded, a door at the back) and the boards' shadow lines.
    h = EAVE - FLOOR
    parts.append(gbox("wall_l", (0.1, h, HZ * 2), (-HX + 0.05, FLOOR + h / 2, 0), "board"))
    parts.append(gbox("wall_r", (0.1, h, HZ * 2), (HX - 0.05, FLOOR + h / 2, 0), "board"))
    parts.append(gbox("wall_f", (HX * 2, h, 0.1), (0, FLOOR + h / 2, -HZ + 0.05), "board"))
    side = (HX * 2 - 1.0) / 2
    for sx in (-1, 1):
        parts.append(gbox(f"wall_b{sx}", (side, h, 0.1), (sx * (0.5 + side / 2), FLOOR + h / 2, HZ - 0.05), "board"))
    parts.append(gbox("lintel", (1.0, h - 1.95, 0.1), (0, FLOOR + 1.95 + (h - 1.95) / 2, HZ - 0.05), "board"))
    y = FLOOR + 0.28
    while y < EAVE - 0.1:
        for sx in (-1, 1):
            parts.append(gbox(f"line_s{sx}_{round(y * 100)}", (0.03, 0.04, HZ * 2), (sx * (HX + 0.005), y, 0), "board_line"))
        parts.append(gbox(f"line_f_{round(y * 100)}", (HX * 2, 0.04, 0.03), (0, y, -HZ - 0.005), "board_line"))
        if y > FLOOR + 1.95:
            parts.append(gbox(f"line_b_{round(y * 100)}", (HX * 2, 0.04, 0.03), (0, y, HZ + 0.005), "board_line"))
        else:
            for sx in (-1, 1):
                parts.append(gbox(f"line_b{sx}_{round(y * 100)}", (side, 0.04, 0.03), (sx * (0.5 + side / 2), y, HZ + 0.005), "board_line"))
        y += 0.3
    for sx in (-1, 1):   # door posts
        parts.append(gbox(f"door_post{sx}", (0.1, 1.95, 0.14), (sx * 0.55, FLOOR + 0.975, HZ), "wood_dark"))
    parts.append(gbox("door_head", (1.2, 0.12, 0.14), (0, FLOOR + 2.0, HZ), "wood_dark"))
    for sx in (-1, 1):   # small shuttered windows on the sides
        parts.append(gbox(f"window{sx}", (0.04, 0.5, 0.6), (sx * (HX + 0.02), FLOOR + 1.6, 0.6), "shutter"))
    # Gable ends and the roof.
    for z, name in ((-HZ + 0.05, "gable_f"), (HZ - 0.05, "gable_b")):
        t = 0.05
        v = [(-HX, EAVE, z - t), (HX, EAVE, z - t), (0, RIDGE, z - t), (-HX, EAVE, z + t), (HX, EAVE, z + t), (0, RIDGE, z + t)]
        parts.append(mesh_obj(name, v, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], "board"))
    slope = math.atan2(RIDGE - EAVE, HX)
    w = math.hypot(HX + 0.2, RIDGE - EAVE + 0.12)
    for sx in (-1, 1):
        o = gbox(f"roof{sx}", (w, 0.09, HZ * 2 + 0.5), (sx * (HX + 0.2) / 2, (EAVE - 0.1 + RIDGE + 0.05) / 2, 0), "roof")
        o.rotation_euler = (0, sx * slope, 0)
        parts.append(o)
    parts.append(gbox("ridge", (0.16, 0.12, HZ * 2 + 0.5), (0, RIDGE + 0.04, 0), "wood_dark"))
    for z in (-1.0, 0.9):   # tie beams across the inside
        parts.append(gbox(f"tie{int(z > 0)}", (HX * 2 - 0.1, 0.18, 0.18), (0, EAVE - 0.12, z), "wood_dark"))
    # The steps up to the door, with handrails.
    top = Vector((0, FLOOR, HZ))
    foot = Vector(STEPS_FOOT)
    for sx in (-1, 1):
        parts.append(gseg(f"string{sx}", (sx * 0.55, FLOOR - 0.05, HZ), (sx * 0.55, 0.0, foot.z), 0.06, "wood_dark", 4))
        parts.append(gseg(f"rail{sx}", (sx * 0.6, FLOOR + 0.95, HZ), (sx * 0.6, 0.95, foot.z), 0.03, "wood_dark", 6))
        for t in (0.0, 0.5, 1.0):
            p = top.lerp(foot, t)
            parts.append(gseg(f"rpost{sx}_{int(t * 2)}", (sx * 0.6, p.y, p.z), (sx * 0.6, p.y + 0.95, p.z), 0.03, "wood_dark", 6))
    n = 10
    for i in range(n):
        p = top.lerp(foot, (i + 0.5) / n)
        parts.append(gbox(f"tread{i}", (1.05, 0.05, 0.3), (0, p.y - 0.02, p.z), "wood_light"))
    # The tailpole, beside the steps, out to where you take hold of it.
    parts.append(gseg("tailpole", (0.8, FLOOR - 0.35, HZ - 0.4), TAIL_END, 0.1, "wood_dark", 6))
    parts.append(gseg("tail_grip", TAIL_END, (TAIL_END[0], TAIL_END[1] - 0.1, TAIL_END[2] + 0.35), 0.07, "leather", 6))
    # Inside: the stones on their platform, in a wooden vat, under the hopper.
    parts.append(gbox("hurst", (1.3, 0.4, 1.3), (0, FLOOR + 0.2, -1.0), "wood_dark"))
    parts.append(cyl("vat", 0.62, 0.45, G(0, FLOOR + 0.625, -1.0), "wood_light", verts=12))
    parts.append(torus("vat_hoop", 0.63, 0.015, G(0, FLOOR + 0.7, -1.0), "iron", seg=12))
    parts.append(cyl("stone_eye", 0.2, 0.03, G(0, FLOOR + 0.86, -1.0), "millstone", verts=10))
    for i, (x, z) in enumerate([(-0.38, -0.62), (0.38, -0.62), (-0.38, -1.38), (0.38, -1.38)]):   # the horse
        parts.append(gseg(f"horse{i}", (x, FLOOR + 0.85, z), (x * 0.9, FLOOR + 1.1, -1.0 + (z + 1.0) * 0.9), 0.025, "wood_dark", 4))
    hb, ht = 0.1, 0.43   # hopper half-widths, bottom and top
    hy0, hy1 = FLOOR + 1.08, FLOOR + 1.58
    hv = [(-hb, hy0, -1.0 - hb), (hb, hy0, -1.0 - hb), (hb, hy0, -1.0 + hb), (-hb, hy0, -1.0 + hb),
          (-ht, hy1, -1.0 - ht), (ht, hy1, -1.0 - ht), (ht, hy1, -1.0 + ht), (-ht, hy1, -1.0 + ht)]
    parts.append(solidify(mesh_obj("hopper", hv, [(0, 1, 2, 3), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], "wood_light"), 0.03))
    parts.append(gbox("shoe", (0.16, 0.06, 0.4), (0, FLOOR + 1.0, -0.95), "wood_dark"))
    # The meal spout down into the bin.
    parts.append(gseg("spout", (0.58, FLOOR + 0.62, -1.0), (1.02, FLOOR + 0.5, -1.0), 0.07, "wood_dark", 4))
    parts.append(open_box("bin", (0.55, 0.6, 0.7), (1.2, FLOOR + 0.3, -1.0), "wood_light"))
    # Odds and ends: sacks in the corner, a broom.
    parts.append(ball("sack_a", 0.2, G(-1.35, FLOOR + 0.3, 1.6), "sack", scale=(1, 0.85, 1.4), subdiv=2))
    parts.append(ball("sack_b", 0.2, G(-1.0, FLOOR + 0.28, 1.75), "flour_sack", scale=(1, 0.85, 1.3), subdiv=2))
    parts.append(gseg("broom", (1.6, FLOOR, 1.7), (1.62, FLOOR + 1.3, 1.85), 0.02, "wood", 5))
    join(parts, "body")

    # The grain in the hopper: an inverted pyramid from the hopper's (projected) apex, scaled
    # uniformly by the game so its level drops as it's ground.
    apex = hy0 - hb / ((ht - hb) / (hy1 - hy0))
    gh = hy1 - 0.03 - apex
    gw = hb + (ht - hb) * ((hy1 - 0.03 - hy0) / (hy1 - hy0))
    gv = [(0, 0, 0), (-gw, gh, -gw), (gw, gh, -gw), (gw, gh, gw), (-gw, gh, gw)]
    grain = mesh_obj("grain", gv, [(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4), (1, 2, 3, 4)], "grain")
    grain.location = G(0, apex, -1.0)
    # Meal in the bin (scaled up from the bottom as it fills).
    meal = gbox("meal", (0.48, 0.52, 0.62), (1.2, FLOOR + 0.04 + 0.26, -1.0), "flour")
    set_origin(meal, G(1.2, FLOOR + 0.04, -1.0))
    # Brake lever and tentering lever, pivoting at their feet.
    brake = join([gseg("brake_beam", (-1.35, FLOOR + 0.05, -1.35), (-1.35, FLOOR + 1.55, -1.3), 0.05, "wood_dark", 6),
                  gseg("brake_rope", (-1.35, FLOOR + 1.55, -1.3), (-1.35, EAVE - 0.1, -1.4), 0.012, "rope", 4),
                  ball("brake_knob", 0.06, G(-1.35, FLOOR + 1.55, -1.3), "wood")], "brake_lever")
    set_origin(brake, G(-1.35, FLOOR + 0.05, -1.35))
    tx, tz = -0.95, -0.15   # the tentering lever, at the stones' back corner
    tenter = join([gseg("tenter_beam", (tx, FLOOR + 0.05, tz), (tx, FLOOR + 1.15, tz + 0.05), 0.04, "wood_dark", 6),
                   ball("tenter_weight", 0.09, G(tx, FLOOR + 0.85, tz + 0.03), "iron"),
                   ball("tenter_knob", 0.05, G(tx, FLOOR + 1.15, tz + 0.05), "wood")], "tenter_lever")
    set_origin(tenter, G(tx, FLOOR + 0.05, tz))
    gbox("lever_foot_b", (0.2, 0.1, 0.2), (-1.35, FLOOR + 0.05, -1.35), "iron")
    gbox("lever_foot_t", (0.2, 0.1, 0.2), (tx, FLOOR + 0.05, tz), "iron")
    export("post_mill_body")


# --- The sails: four common sails on the windshaft, with the brake wheel inside ----------------

@model
def post_mill_sails():
    # Built around the hub (origin), sails in the x/y plane facing -z; the game spins it about z.
    parts = [gbox("poll_end", (0.48, 0.48, 0.55), (0, 0, 0.05), "wood_dark"),
             gseg("windshaft", (0, 0, 0.2), (0, 0, 2.6), 0.16, "wood_dark", 8)]
    # The brake wheel on the windshaft, up in the body.
    wz = 1.55
    rim = torus("brake_rim", 0.82, 0.07, G(0, 0, wz), "wood", seg=20)
    rim.rotation_euler = (math.radians(90), 0, 0)
    parts.append(rim)
    for i in range(4):
        a = math.radians(45 + i * 90)
        parts.append(gseg(f"arm{i}", (0, 0, wz), (math.cos(a) * 0.8, math.sin(a) * 0.8, wz), 0.05, "wood_dark", 4))
    for i in range(24):
        a = math.tau * i / 24
        cog = gbox(f"cog{i}", (0.08, 0.08, 0.1), (math.cos(a) * 0.82, math.sin(a) * 0.82, wz + 0.1), "wood_light")
        parts.append(cog)
    R0, R1, W = 0.9, 4.6, 1.3
    for i in range(4):
        a = math.radians(i * 90 + 15)
        d = Vector((math.cos(a), math.sin(a), 0))
        e = Vector((math.sin(a), -math.cos(a), 0))   # the trailing side, where the cloth spreads
        parts.append(gseg(f"whip{i}", tuple(-d * 0.3), tuple(d * R1), 0.08, "wood_dark", 4))
        k = 0
        r = R0
        while r <= R1 + 0.01:
            p = d * r
            parts.append(gseg(f"bar{i}_{k}", tuple(p), tuple(p + e * W), 0.022, "wood_light", 4))
            parts.append(gseg(f"lead{i}_{k}", tuple(p), tuple(p - e * 0.28), 0.018, "wood_light", 4))
            r += 0.4
            k += 1
        parts.append(gseg(f"hemlath{i}", tuple(d * R0 + e * W), tuple(d * R1 + e * W), 0.03, "wood_light", 4))
        parts.append(gseg(f"leadboard{i}", tuple(d * R0 - e * 0.28), tuple(d * R1 - e * 0.28), 0.02, "wood_light", 4))
    join(parts, "sails")
    for i in range(4):
        a = math.radians(i * 90 + 15)
        theta = a - math.pi / 2   # local +y runs out along the whip, +x across to the hemlath
        z = -0.1                   # on the windward face
        v = [(0.04, R0 + 0.05, z), (W - 0.04, R0 + 0.05, z), (W - 0.04, R1 - 0.1, z), (0.04, R1 - 0.1, z)]
        cl = solidify(mesh_obj(f"cloth_{i}", v, [(0, 1, 2, 3)], "canvas"), 0.012)
        cl.rotation_euler = (0, -theta, 0)
    export("post_mill_sails")


# --- A sack of flour ---------------------------------------------------------------------------

@model
def flour_sack():
    join([ball("sack", 0.2, (0, 0, 0.25), "flour_sack", scale=(1, 0.85, 1.4), subdiv=2),
          cyl("neck", 0.06, 0.1, (0, 0, 0.55), "flour_sack", verts=8, r2=0.03),
          torus("tie", 0.06, 0.01, (0, 0, 0.53), "wool", seg=8),
          ball("dust", 0.12, (0.0, -0.17, 0.32), "flour", scale=(1.3, 0.25, 1.0))], "flour_sack")
    export("flour_sack")


def main():
    os.makedirs(OUT, exist_ok=True)
    names = args or [n for n in MODELS]
    for n in names:
        reset()
        MODELS[n]()


main()
