"""Builds the villager: one low-poly rigged character that every NPC uses, with its animations.

Run: Blender -b --factory-startup --python tools/blender/make_villager.py
Output: assets/models/villager.glb (mesh + armature + one animation per action).

The character faces Blender +Y (Godot -Z, the node's forward) and stands 1.7 m tall.
Each body part is bound rigidly to one bone, which suits the low-poly style and keeps the rig
easy to animate from code. Materials are named (tunic, trousers, skin, hair, shoes, belt) so the
game can recolour villagers.

Animations are written as pose tables: for each action, a list of keyframes, each a dict of
bone -> (x, y, z) rotation in degrees (bone-local) plus optional hip lift. Adding a new action
for a new profession is one more table in ACTIONS.
"""
import bpy, math, os, sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets/models/villager.glb")
FPS = 24

C = {
    "tunic": (0.42, 0.33, 0.22), "trousers": (0.3, 0.27, 0.22), "skin": (0.86, 0.66, 0.52),
    "hair": (0.32, 0.2, 0.12), "shoes": (0.22, 0.14, 0.09), "belt": (0.5, 0.36, 0.2),
}

# Bone: (head, tail, parent). Right is +X when facing +Y.
BONES = {
    "hips": ((0, 0, 0.95), (0, 0, 1.05), None),
    "spine": ((0, 0, 1.05), (0, 0, 1.28), "hips"),
    "chest": ((0, 0, 1.28), (0, 0, 1.48), "spine"),
    "neck": ((0, 0, 1.48), (0, 0, 1.56), "chest"),
    "head": ((0, 0, 1.56), (0, 0, 1.8), "neck"),
    "upper_arm.R": ((0.21, 0, 1.44), (0.21, 0, 1.17), "chest"),
    "lower_arm.R": ((0.21, 0, 1.17), (0.21, 0, 0.93), "upper_arm.R"),
    "hand.R": ((0.21, 0, 0.93), (0.21, 0, 0.83), "lower_arm.R"),
    "upper_arm.L": ((-0.21, 0, 1.44), (-0.21, 0, 1.17), "chest"),
    "lower_arm.L": ((-0.21, 0, 1.17), (-0.21, 0, 0.93), "upper_arm.L"),
    "hand.L": ((-0.21, 0, 0.93), (-0.21, 0, 0.83), "lower_arm.L"),
    "thigh.R": ((0.1, 0, 0.95), (0.1, 0, 0.52), "hips"),
    "shin.R": ((0.1, 0, 0.52), (0.1, 0, 0.09), "thigh.R"),
    "foot.R": ((0.1, 0, 0.09), (0.1, 0.16, 0.03), "shin.R"),
    "thigh.L": ((-0.1, 0, 0.95), (-0.1, 0, 0.52), "hips"),
    "shin.L": ((-0.1, 0, 0.52), (-0.1, 0, 0.09), "thigh.L"),
    "foot.L": ((-0.1, 0, 0.09), (-0.1, 0.16, 0.03), "shin.L"),
}


def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*[srgb(c) for c in C[name]], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


def part(kind, size, loc, material, bone, rot=(0, 0, 0), verts=8, r2=None):
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.active_object
        o.scale = size
    elif kind == "cyl":
        if r2 is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=size[0], depth=size[1], location=loc)
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=size[0], radius2=r2, depth=size[1], location=loc)
        o = bpy.context.active_object
    else:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=loc)
        o = bpy.context.active_object
        o.scale = size
    o.rotation_euler = [math.radians(a) for a in rot]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat(material))
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    return o


def build_body():
    parts = [
        # Torso: a belted tunic.
        part("cyl", (0.17, 0.42), (0, 0, 1.27), "tunic", "chest", r2=0.19),
        part("cyl", (0.19, 0.22), (0, 0, 1.0), "tunic", "hips", r2=0.17),
        part("cyl", (0.17, 0.12), (0, 0, 1.12), "tunic", "spine"),
        part("cyl", (0.2, 0.05), (0, 0, 1.08), "belt", "spine"),
        part("cyl", (0.21, 0.18), (0, 0, 0.82), "tunic", "hips", r2=0.19),   # skirt of the tunic
        # Head.
        part("cyl", (0.05, 0.1), (0, 0, 1.52), "skin", "neck"),
        part("sph", (0.11, 0.12, 0.13), (0, 0.01, 1.66), "skin", "head"),
        part("sph", (0.115, 0.12, 0.09), (0, -0.015, 1.71), "hair", "head"),
        part("box", (0.03, 0.03, 0.04), (0, 0.12, 1.65), "skin", "head"),    # nose
        # Arms.
        part("cyl", (0.055, 0.27), (0.21, 0, 1.31), "tunic", "upper_arm.R", r2=0.05),
        part("cyl", (0.05, 0.24), (0.21, 0, 1.05), "tunic", "lower_arm.R", r2=0.042),
        part("box", (0.07, 0.04, 0.1), (0.21, 0.01, 0.88), "skin", "hand.R"),
        part("cyl", (0.055, 0.27), (-0.21, 0, 1.31), "tunic", "upper_arm.L", r2=0.05),
        part("cyl", (0.05, 0.24), (-0.21, 0, 1.05), "tunic", "lower_arm.L", r2=0.042),
        part("box", (0.07, 0.04, 0.1), (-0.21, 0.01, 0.88), "skin", "hand.L"),
        # Legs.
        part("cyl", (0.075, 0.43), (0.1, 0, 0.735), "trousers", "thigh.R", r2=0.06),
        part("cyl", (0.058, 0.43), (0.1, 0, 0.305), "trousers", "shin.R", r2=0.05),
        part("box", (0.1, 0.22, 0.08), (0.1, 0.05, 0.04), "shoes", "foot.R"),
        part("cyl", (0.075, 0.43), (-0.1, 0, 0.735), "trousers", "thigh.L", r2=0.06),
        part("cyl", (0.058, 0.43), (-0.1, 0, 0.305), "trousers", "shin.L", r2=0.05),
        part("box", (0.1, 0.22, 0.08), (-0.1, 0.05, 0.04), "shoes", "foot.L"),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = "body"
    return body


def build_armature():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "villager"
    eb = arm.data.edit_bones
    eb.remove(eb[0])
    for name, (h, t, parent) in BONES.items():
        b = eb.new(name)
        b.head = h
        b.tail = t
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


# --- Animations ------------------------------------------------------------------------------
# Rotations are bone-local degrees. For the limbs (bones pointing down), +X swings the limb
# backwards and -X forwards/up; for the spine bones, +X bends forward. Verified in Godot (the
# hoe's frame-10 key raises the arms overhead); if the sign is ever wrong, flip SWING.

SWING = 1.0


def P(**bones):
    return bones


def walk_cycle(arm_swing=35, leg_swing=30, carry=False):
    a, l = arm_swing, leg_swing
    arms_a = {"upper_arm.R": (a, 0, 0), "upper_arm.L": (-a, 0, 0), "lower_arm.R": (-15, 0, 0), "lower_arm.L": (-25, 0, 0)}
    arms_b = {"upper_arm.R": (-a, 0, 0), "upper_arm.L": (a, 0, 0), "lower_arm.R": (-25, 0, 0), "lower_arm.L": (-15, 0, 0)}
    if carry:
        arms_a = arms_b = {"upper_arm.R": (-40, 0, -8), "upper_arm.L": (-40, 0, 8), "lower_arm.R": (-55, 0, 0), "lower_arm.L": (-55, 0, 0)}
    return [
        (0, dict(arms_a, **{"thigh.R": (-l, 0, 0), "thigh.L": (l, 0, 0), "shin.R": (5, 0, 0), "shin.L": (25, 0, 0), "hips_z": 0.0})),
        (6, dict(arms_a, **{"thigh.R": (0, 0, 0), "thigh.L": (0, 0, 0), "shin.R": (30, 0, 0), "shin.L": (5, 0, 0), "hips_z": 0.03})),
        (12, dict(arms_b, **{"thigh.R": (l, 0, 0), "thigh.L": (-l, 0, 0), "shin.R": (25, 0, 0), "shin.L": (5, 0, 0), "hips_z": 0.0})),
        (18, dict(arms_b, **{"thigh.R": (0, 0, 0), "thigh.L": (0, 0, 0), "shin.R": (5, 0, 0), "shin.L": (30, 0, 0), "hips_z": 0.03})),
        (24, dict(arms_a, **{"thigh.R": (-l, 0, 0), "thigh.L": (l, 0, 0), "shin.R": (5, 0, 0), "shin.L": (25, 0, 0), "hips_z": 0.0})),
    ]


# Two-handed tool held across the body: right hand low on the handle, left hand above it.
HOLD_HIGH = {"upper_arm.R": (-30, 0, -10), "lower_arm.R": (-70, 0, 0), "upper_arm.L": (-50, 0, 25), "lower_arm.L": (-60, 0, 0)}

ACTIONS = {
    "idle": [
        (0, {"chest": (0, 0, 0), "upper_arm.R": (0, 0, 4), "upper_arm.L": (0, 0, -4), "lower_arm.R": (-8, 0, 0), "lower_arm.L": (-8, 0, 0)}),
        (36, {"chest": (2, 0, 0), "upper_arm.R": (2, 0, 4), "upper_arm.L": (2, 0, -4), "lower_arm.R": (-10, 0, 0), "lower_arm.L": (-10, 0, 0)}),
        (72, {"chest": (0, 0, 0), "upper_arm.R": (0, 0, 4), "upper_arm.L": (0, 0, -4), "lower_arm.R": (-8, 0, 0), "lower_arm.L": (-8, 0, 0)}),
    ],
    "walk": walk_cycle(),
    "carry": walk_cycle(carry=True),
    "carry_idle": [
        (0, {"upper_arm.R": (-40, 0, -8), "upper_arm.L": (-40, 0, 8), "lower_arm.R": (-55, 0, 0), "lower_arm.L": (-55, 0, 0)}),
        (12, {"upper_arm.R": (-42, 0, -8), "upper_arm.L": (-42, 0, 8), "lower_arm.R": (-55, 0, 0), "lower_arm.L": (-55, 0, 0)}),
        (24, {"upper_arm.R": (-40, 0, -8), "upper_arm.L": (-40, 0, 8), "lower_arm.R": (-55, 0, 0), "lower_arm.L": (-55, 0, 0)}),
    ],
    # Pulling the handcart: arms down and back gripping the shafts, leaning into it.
    "pull": [(f, dict(p, **{"spine": (12, 0, 0), "upper_arm.R": (15, 0, -6), "upper_arm.L": (15, 0, 6), "lower_arm.R": (-20, 0, 0), "lower_arm.L": (-20, 0, 0)}))
             for f, p in walk_cycle(leg_swing=26)],
    # Hoeing: lift the hoe over the shoulder, chop down into the soil.
    "hoe": [
        (0, dict(HOLD_HIGH, spine=(5, 0, 0))),
        (10, {"spine": (-5, 0, 0), "upper_arm.R": (-150, 0, -15), "lower_arm.R": (-40, 0, 0), "upper_arm.L": (-160, 0, 15), "lower_arm.L": (-30, 0, 0)}),
        (16, {"spine": (30, 0, 0), "chest": (10, 0, 0), "upper_arm.R": (-55, 0, -8), "lower_arm.R": (-15, 0, 0), "upper_arm.L": (-65, 0, 12), "lower_arm.L": (-10, 0, 0)}),
        (24, dict(HOLD_HIGH, spine=(5, 0, 0))),
    ],
}


def key_action(arm, name, keys):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    bpy.context.scene.frame_start = 0
    for frame, pose in keys:
        # Reset every bone each key, so unlisted bones return to rest.
        for pb in arm.pose.bones:
            r = pose.get(pb.name, (0, 0, 0))
            pb.rotation_euler = [math.radians(SWING * r[0]), math.radians(r[1]), math.radians(r[2])]
            pb.keyframe_insert("rotation_euler", frame=frame)
        hips = arm.pose.bones["hips"]
        hips.location = (0, pose.get("hips_z", 0.0), 0)   # bone-local Y is up for the hips
        hips.keyframe_insert("location", frame=frame)
    return act


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    body = build_body()
    arm = build_armature()
    body.parent = arm
    mod = body.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    for name, keys in ACTIONS.items():
        key_action(arm, name, keys)
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animation_mode="ACTIONS", export_apply=False,
                              export_force_sampling=True, export_frame_range=False)
    print("BUILT villager with", len(ACTIONS), "actions")


main()
