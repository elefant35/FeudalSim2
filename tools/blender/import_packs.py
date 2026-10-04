"""Converts chosen models from downloaded CC0 packs (.vendor/) into self-contained GLBs at
assets/models/<id>.glb, embedding textures and applying a scale so 1 unit = 1 metre.

Run: Blender -b --factory-startup --python tools/blender/import_packs.py -- [--measure]
The list of models lives in tools/blender/pack_models.json: {"id": [source path, scale], ...}
"""
import bpy, json, os, sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
measure = "--measure" in args
only = [a for a in args if not a.startswith("--")]

# The Nature Kit stores sRGB colours as linear factors (they render washed-out and teal), so
# untextured colours are converted to linear here. Some are re-tinted (sRGB) for a European valley.
RETINT = {
    "leafsGreen": (0.34, 0.56, 0.22), "leafsDark": (0.2, 0.4, 0.22), "grass": (0.38, 0.6, 0.24),
    "leafsFall": (0.85, 0.5, 0.18), "dirt": (0.5, 0.4, 0.3), "stone": (0.62, 0.62, 0.6),
    "wood": (0.6, 0.42, 0.26), "woodDark": (0.42, 0.28, 0.18), "woodBark": (0.42, 0.3, 0.2),
    "woodBarkDark": (0.32, 0.22, 0.15), "woodInner": (0.8, 0.68, 0.5), "woodBirch": (0.88, 0.86, 0.8),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def fix_untextured_colours():
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or bsdf.inputs["Base Color"].is_linked:
            continue
        col = bsdf.inputs["Base Color"].default_value
        src = RETINT.get(mat.name.split(".")[0], (col[0], col[1], col[2]))
        bsdf.inputs["Base Color"].default_value = (*[srgb_to_linear(c) for c in src], col[3])


manifest = json.load(open(os.path.join(ROOT, "tools/blender/pack_models.json")))
out_dir = os.path.join(ROOT, "assets/models")
os.makedirs(out_dir, exist_ok=True)

for model_id, (src, scale) in manifest.items():
    if only and model_id not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, ".vendor", src))
    if src.startswith("kenney_nature-kit"):
        fix_untextured_colours()
    objs = [o for o in bpy.context.scene.objects]
    for o in objs:
        if o.parent is None:
            o.scale = [s * scale for s in o.scale]
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = hi - lo
    # Blender is Z-up; report as Godot's x, y(up), z.
    print(f"MODEL {model_id}: size x={size.x:.2f} y={size.z:.2f} z={size.y:.2f}  min_up={lo.z:.2f}")
    if measure:
        continue
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, model_id + ".glb"), export_format="GLB",
                              export_image_format="AUTO", export_apply=True)
