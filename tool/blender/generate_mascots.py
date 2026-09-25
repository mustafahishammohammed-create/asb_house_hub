"""
ASB House Hub - Blender 5.2 Mascot 3D Generator
Generates high-fidelity 3D models, renders, .obj, .glb, and .blend files
for all four house mascots (Dragon, Gryphon, Wolf, Chimera) atop the Grand Runic Disc.
"""

import bpy
import bmesh
import mathutils
from mathutils import Vector, Euler, Color
import math
import os
import json

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Remove existing objects
    for obj in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in bpy.data.meshes:
        bpy.data.meshes.remove(mesh, do_unlink=True)
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat, do_unlink=True)

def setup_studio_lighting(accent_color_hex):
    # World background
    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs["Color"].default_value = (0.015, 0.02, 0.035, 1.0)
        bg_node.inputs["Strength"].default_value = 0.4
    bpy.context.scene.world = world

    # Key Light (Warm Rim/Top)
    key_light_data = bpy.data.lights.new(name="KeyLight", type='AREA')
    key_light_data.energy = 450.0
    key_light_data.size = 2.5
    key_light_data.color = (1.0, 0.95, 0.88)
    key_light = bpy.data.objects.new(name="KeyLight", object_data=key_light_data)
    key_light.location = (-2.5, -3.2, 3.8)
    key_light.rotation_euler = (math.radians(52), math.radians(-18), math.radians(-32))
    bpy.context.collection.objects.link(key_light)

    # Fill Light (Cool Ambient)
    fill_light_data = bpy.data.lights.new(name="FillLight", type='AREA')
    fill_light_data.energy = 180.0
    fill_light_data.size = 3.0
    fill_light_data.color = (0.6, 0.75, 1.0)
    fill_light = bpy.data.objects.new(name="FillLight", object_data=fill_light_data)
    fill_light.location = (3.2, -2.8, 2.4)
    fill_light.rotation_euler = (math.radians(45), math.radians(25), math.radians(40))
    bpy.context.collection.objects.link(fill_light)

    # Rim / House Accent Light
    c = Color()
    c.r = int(accent_color_hex[1:3], 16) / 255.0
    c.g = int(accent_color_hex[3:5], 16) / 255.0
    c.b = int(accent_color_hex[5:7], 16) / 255.0

    rim_light_data = bpy.data.lights.new(name="RimLight", type='SPOT')
    rim_light_data.energy = 600.0
    rim_light_data.spot_size = math.radians(65)
    rim_light_data.spot_blend = 0.4
    rim_light_data.color = (c.r, c.g, c.b)
    rim_light = bpy.data.objects.new(name="RimLight", object_data=rim_light_data)
    rim_light.location = (0.0, 3.5, 3.2)
    rim_light.rotation_euler = (math.radians(-48), 0, math.radians(180))
    bpy.context.collection.objects.link(rim_light)

    # Studio Camera
    cam_data = bpy.data.cameras.new(name="StudioCamera")
    cam_data.lens = 65.0
    cam_data.sensor_width = 36.0
    cam_obj = bpy.data.objects.new(name="StudioCamera", object_data=cam_data)
    cam_obj.location = (0.0, -4.5, 1.35)
    cam_obj.rotation_euler = (math.radians(78), 0, 0)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

def create_pbr_material(name, base_color, metallic=0.7, roughness=0.3, emission_color=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission_color and emission_strength > 0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*emission_color, 1.0)
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = (*emission_color, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

def create_runic_pedestal(mat_stone, mat_runic, radius=1.3, height=0.28):
    bm = bmesh.new()
    segments = 24

    # Tier 1: Lower beveled ring
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius * 0.94,
        depth=height * 0.55,
        matrix=mathutils.Matrix.Translation((0, 0, -height * 0.55))
    )

    # Tier 2: Upper beveled disc with runic depression
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius * 0.94,
        radius2=radius * 0.88,
        depth=height * 0.45,
        matrix=mathutils.Matrix.Translation((0, 0, -height * 0.15))
    )

    mesh = bpy.data.meshes.new("GrandRunicPedestal")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("GrandRunicPedestal", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_stone)
    obj.data.materials.append(mat_runic)

    # Assign runic material to top faces
    for poly in obj.data.polygons:
        if poly.normal.z > 0.8:
            poly.material_index = 1
        else:
            poly.material_index = 0

    return obj

def build_dragon(primary_mat, dark_mat, gold_mat, eye_mat, plinth_mat, runic_mat):
    """Ignis the Crimson Dragon"""
    pedestal = create_runic_pedestal(plinth_mat, runic_mat)

    # Head and Snout
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.45, location=(0, 0, 0.75))
    head = bpy.context.object
    head.name = "DragonHead"
    head.scale = (0.75, 1.15, 0.7)
    head.data.materials.append(primary_mat)

    # Snout
    bpy.ops.mesh.primitive_cube_add(size=0.35, location=(0, 0.42, 0.65))
    snout = bpy.context.object
    snout.name = "DragonSnout"
    snout.scale = (0.7, 1.3, 0.55)
    snout.data.materials.append(primary_mat)

    # Horns L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.09, radius2=0.015, depth=0.65, location=(sx * 0.28, -0.22, 1.15))
        horn = bpy.context.object
        horn.name = f"DragonHorn_{side}"
        horn.rotation_euler = (math.radians(-38), math.radians(sx * 24), math.radians(sx * 15))
        horn.data.materials.append(gold_mat)

    # Eyes L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.08, location=(sx * 0.22, 0.25, 0.82))
        eye = bpy.context.object
        eye.name = f"DragonEye_{side}"
        eye.data.materials.append(eye_mat)

    # Wings L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bm = bmesh.new()
        # Create winged triangular fan
        v0 = bm.verts.new((0, 0, 0))
        v1 = bm.verts.new((sx * 1.55, 0.25, 0.95))
        v2 = bm.verts.new((sx * 1.25, -0.35, 0.35))
        v3 = bm.verts.new((sx * 0.65, -0.45, -0.15))
        bm.faces.new((v0, v1, v2))
        bm.faces.new((v0, v2, v3))
        w_mesh = bpy.data.meshes.new(f"DragonWing_{side}")
        bm.to_mesh(w_mesh)
        bm.free()
        wing = bpy.data.objects.new(f"DragonWing_{side}", w_mesh)
        wing.location = (sx * 0.25, -0.1, 0.65)
        bpy.context.collection.objects.link(wing)
        wing.data.materials.append(primary_mat)

    # Chest & Body
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.48, radius2=0.25, depth=0.75, location=(0, -0.05, 0.28))
    chest = bpy.context.object
    chest.name = "DragonChest"
    chest.rotation_euler = (math.radians(180), 0, 0)
    chest.data.materials.append(dark_mat)

    # Claws Gripping Pedestal L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.14, radius2=0.04, depth=0.45, location=(sx * 0.42, 0.48, 0.08))
        claw = bpy.context.object
        claw.name = f"DragonClaw_{side}"
        claw.rotation_euler = (math.radians(35), math.radians(sx * -15), 0)
        claw.data.materials.append(gold_mat)

    # Tail curled around base
    bm_t = bmesh.new()
    tail_pts = [
        Vector((0, -0.35, 0.1)),
        Vector((0.45, -0.65, 0.06)),
        Vector((0.75, -0.35, 0.04)),
        Vector((0.85, 0.15, 0.04)),
    ]
    prev_v = None
    for pt in tail_pts:
        v = bm_t.verts.new(pt)
        if prev_v:
            bm_t.edges.new((prev_v, v))
        prev_v = v
    t_mesh = bpy.data.meshes.new("DragonTailSpade")
    bm_t.to_mesh(t_mesh)
    bm_t.free()

    tail_obj = bpy.data.objects.new("DragonTail", t_mesh)
    bpy.context.collection.objects.link(tail_obj)
    tail_obj.data.materials.append(primary_mat)

    # Join dragon parts (except pedestal)
    dragon_objs = [obj for obj in bpy.context.scene.objects if obj.name.startswith("Dragon")]
    ctx = bpy.context.copy()
    ctx['active_object'] = dragon_objs[0]
    ctx['selected_objects'] = dragon_objs
    ctx['selected_editable_objects'] = dragon_objs
    with bpy.context.temp_override(active_object=dragon_objs[0], selected_objects=dragon_objs):
        bpy.ops.object.join()
    dragon_mesh_obj = bpy.context.active_object
    dragon_mesh_obj.name = "IgnisTheCrimsonDragon"
    return dragon_mesh_obj, pedestal

def build_gryphon(primary_mat, dark_mat, beak_mat, eye_mat, plinth_mat, runic_mat):
    """Zephyr the Tempest Gryphon"""
    pedestal = create_runic_pedestal(plinth_mat, runic_mat)

    # Raptor Head
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.42, location=(0, 0, 0.78))
    head = bpy.context.object
    head.name = "GryphonHead"
    head.scale = (0.75, 1.1, 0.8)
    head.data.materials.append(primary_mat)

    # Curved Raptor Beak
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.18, radius2=0.02, depth=0.45, location=(0, 0.48, 0.68))
    beak = bpy.context.object
    beak.name = "GryphonBeak"
    beak.rotation_euler = (math.radians(95), 0, 0)
    beak.data.materials.append(beak_mat)

    # Feathered Crest / Ear Tufts L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08, radius2=0.02, depth=0.52, location=(sx * 0.22, -0.25, 1.05))
        crest = bpy.context.object
        crest.name = f"GryphonCrest_{side}"
        crest.rotation_euler = (math.radians(-45), math.radians(sx * 22), 0)
        crest.data.materials.append(dark_mat)

    # Eyes L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.07, location=(sx * 0.22, 0.25, 0.85))
        eye = bpy.context.object
        eye.name = f"GryphonEye_{side}"
        eye.data.materials.append(eye_mat)

    # Wings L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bm = bmesh.new()
        v0 = bm.verts.new((0, 0, 0))
        v1 = bm.verts.new((sx * 1.65, 0.35, 1.15))
        v2 = bm.verts.new((sx * 1.35, -0.25, 0.55))
        v3 = bm.verts.new((sx * 0.75, -0.45, 0.05))
        bm.faces.new((v0, v1, v2))
        bm.faces.new((v0, v2, v3))
        w_mesh = bpy.data.meshes.new(f"GryphonWing_{side}")
        bm.to_mesh(w_mesh)
        bm.free()
        wing = bpy.data.objects.new(f"GryphonWing_{side}", w_mesh)
        wing.location = (sx * 0.22, -0.05, 0.68)
        bpy.context.collection.objects.link(wing)
        wing.data.materials.append(primary_mat)

    # Lion Chest & Talons
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.45, radius2=0.22, depth=0.72, location=(0, -0.05, 0.28))
    chest = bpy.context.object
    chest.name = "GryphonChest"
    chest.rotation_euler = (math.radians(180), 0, 0)
    chest.data.materials.append(dark_mat)

    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0.03, depth=0.42, location=(sx * 0.38, 0.42, 0.08))
        talon = bpy.context.object
        talon.name = f"GryphonTalon_{side}"
        talon.rotation_euler = (math.radians(35), math.radians(sx * -15), 0)
        talon.data.materials.append(beak_mat)

    gryphon_objs = [obj for obj in bpy.context.scene.objects if obj.name.startswith("Gryphon")]
    with bpy.context.temp_override(active_object=gryphon_objs[0], selected_objects=gryphon_objs):
        bpy.ops.object.join()
    gryphon_mesh_obj = bpy.context.active_object
    gryphon_mesh_obj.name = "ZephyrTheTempestGryphon"
    return gryphon_mesh_obj, pedestal

def build_wolf(primary_mat, dark_mat, fangs_mat, eye_mat, plinth_mat, runic_mat):
    """Sylva the Forest Wolf"""
    pedestal = create_runic_pedestal(plinth_mat, runic_mat)

    # Wolf Skull
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.44, location=(0, 0, 0.72))
    head = bpy.context.object
    head.name = "WolfHead"
    head.scale = (0.75, 1.12, 0.78)
    head.data.materials.append(primary_mat)

    # Wolf Muzzle
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.22, radius2=0.08, depth=0.55, location=(0, 0.46, 0.65))
    muzzle = bpy.context.object
    muzzle.name = "WolfMuzzle"
    muzzle.rotation_euler = (math.radians(82), 0, 0)
    muzzle.data.materials.append(dark_mat)

    # Wolf Ears L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0.02, depth=0.48, location=(sx * 0.28, -0.15, 1.1))
        ear = bpy.context.object
        ear.name = f"WolfEar_{side}"
        ear.rotation_euler = (math.radians(-18), math.radians(sx * 25), 0)
        ear.data.materials.append(primary_mat)

    # Eyes L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.07, location=(sx * 0.2, 0.26, 0.8))
        eye = bpy.context.object
        eye.name = f"WolfEye_{side}"
        eye.data.materials.append(eye_mat)

    # Thick Fur Mane / Collar
    bpy.ops.mesh.primitive_torus_add(major_radius=0.45, minor_radius=0.14, location=(0, -0.05, 0.42))
    collar = bpy.context.object
    collar.name = "WolfCollar"
    collar.data.materials.append(dark_mat)

    # Chest & Forepaws
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.48, radius2=0.25, depth=0.68, location=(0, -0.08, 0.25))
    chest = bpy.context.object
    chest.name = "WolfChest"
    chest.rotation_euler = (math.radians(180), 0, 0)
    chest.data.materials.append(primary_mat)

    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.22, location=(sx * 0.35, 0.42, 0.08))
        paw = bpy.context.object
        paw.name = f"WolfPaw_{side}"
        paw.scale = (0.9, 1.4, 0.6)
        paw.data.materials.append(dark_mat)

    wolf_objs = [obj for obj in bpy.context.scene.objects if obj.name.startswith("Wolf")]
    with bpy.context.temp_override(active_object=wolf_objs[0], selected_objects=wolf_objs):
        bpy.ops.object.join()
    wolf_mesh_obj = bpy.context.active_object
    wolf_mesh_obj.name = "SylvaTheForestWolf"
    return wolf_mesh_obj, pedestal

def build_chimera(primary_mat, dark_mat, gold_mat, eye_mat, plinth_mat, runic_mat):
    """Solis the Sun Chimera"""
    pedestal = create_runic_pedestal(plinth_mat, runic_mat)

    # Lion Head
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.45, location=(0, 0, 0.72))
    head = bpy.context.object
    head.name = "ChimeraHead"
    head.scale = (0.85, 1.1, 0.85)
    head.data.materials.append(primary_mat)

    # Radiant Solar Mane Rays (16 rays in a sunburst)
    for i in range(16):
        angle = (i * 22.5) * math.pi / 180.0
        rad = 0.65
        lx = math.cos(angle) * rad
        lz = 0.72 + math.sin(angle) * rad
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08, radius2=0.015, depth=0.38, location=(lx, -0.15, lz))
        ray = bpy.context.object
        ray.name = f"ChimeraManeRay_{i}"
        ray.rotation_euler = (0, -angle + math.pi/2, 0)
        ray.data.materials.append(gold_mat if i % 2 == 0 else primary_mat)

    # Eyes L / R
    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.08, location=(sx * 0.22, 0.28, 0.78))
        eye = bpy.context.object
        eye.name = f"ChimeraEye_{side}"
        eye.data.materials.append(eye_mat)

    # Lion Body & Paws
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.5, radius2=0.26, depth=0.72, location=(0, -0.06, 0.26))
    chest = bpy.context.object
    chest.name = "ChimeraChest"
    chest.rotation_euler = (math.radians(180), 0, 0)
    chest.data.materials.append(dark_mat)

    for side, sx in [("L", -1), ("R", 1)]:
        bpy.ops.mesh.primitive_cube_add(size=0.24, location=(sx * 0.38, 0.44, 0.08))
        paw = bpy.context.object
        paw.name = f"ChimeraPaw_{side}"
        paw.scale = (1.0, 1.35, 0.6)
        paw.data.materials.append(gold_mat)

    chimera_objs = [obj for obj in bpy.context.scene.objects if obj.name.startswith("Chimera")]
    with bpy.context.temp_override(active_object=chimera_objs[0], selected_objects=chimera_objs):
        bpy.ops.object.join()
    chimera_mesh_obj = bpy.context.active_object
    chimera_mesh_obj.name = "SolisTheSunChimera"
    return chimera_mesh_obj, pedestal

def render_hero_image(filepath):
    scene = bpy.context.scene
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.filepath = filepath

    # Try EEVEE or Workbench
    try:
        scene.render.engine = 'BLENDER_EEVEE'
    except Exception:
        scene.render.engine = 'BLENDER_WORKBENCH'

    print(f"Rendering {filepath}...")
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {filepath}")

def export_obj_and_glb(obj, name_prefix, output_dir):
    obj_path = os.path.join(output_dir, f"{name_prefix}.obj")
    glb_path = os.path.join(output_dir, f"{name_prefix}.glb")

    # Select all objects
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = obj

    try:
        if hasattr(bpy.ops.wm, 'obj_export'):
            bpy.ops.wm.obj_export(filepath=obj_path, export_selected_objects=True)
        else:
            bpy.ops.export_scene.obj(filepath=obj_path, use_selection=True)
        print(f"Exported OBJ: {obj_path}")
    except Exception as e:
        print(f"OBJ Export note: {e}")

    try:
        bpy.ops.export_scene.gltf(filepath=glb_path, use_selection=True)
        print(f"Exported GLB: {glb_path}")
    except Exception as e:
        print(f"GLTF Export note: {e}")

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    assets_3d_dir = os.path.join(root_dir, "assets", "3d")
    images_dir = os.path.join(root_dir, "assets", "images", "mascots")
    os.makedirs(assets_3d_dir, exist_ok=True)
    os.makedirs(images_dir, exist_ok=True)

    mascot_configs = [
        {
            "id": "ruby",
            "name": "Ignis the Crimson Dragon",
            "file_prefix": "ignis_dragon",
            "accent_hex": "#FF3B30",
            "builder": build_dragon,
            "colors": {
                "primary": (0.85, 0.08, 0.15),
                "dark": (0.35, 0.02, 0.05),
                "accent": (1.0, 0.78, 0.2),
                "eye": (1.0, 0.92, 0.1),
                "plinth": (0.1, 0.12, 0.16),
                "runic": (1.0, 0.15, 0.25),
            }
        },
        {
            "id": "sapphire",
            "name": "Zephyr the Tempest Gryphon",
            "file_prefix": "zephyr_gryphon",
            "accent_hex": "#007AFF",
            "builder": build_gryphon,
            "colors": {
                "primary": (0.05, 0.35, 0.95),
                "dark": (0.02, 0.12, 0.38),
                "accent": (0.95, 0.82, 0.18),
                "eye": (0.0, 0.9, 1.0),
                "plinth": (0.1, 0.12, 0.16),
                "runic": (0.0, 0.75, 1.0),
            }
        },
        {
            "id": "emerald",
            "name": "Sylva the Forest Wolf",
            "file_prefix": "sylva_wolf",
            "accent_hex": "#34C759",
            "builder": build_wolf,
            "colors": {
                "primary": (0.08, 0.72, 0.32),
                "dark": (0.02, 0.25, 0.1),
                "accent": (0.9, 0.92, 0.95),
                "eye": (0.4, 1.0, 0.5),
                "plinth": (0.1, 0.12, 0.16),
                "runic": (0.1, 0.95, 0.45),
            }
        },
        {
            "id": "topaz",
            "name": "Solis the Sun Chimera",
            "file_prefix": "solis_chimera",
            "accent_hex": "#FF9500",
            "builder": build_chimera,
            "colors": {
                "primary": (0.95, 0.65, 0.05),
                "dark": (0.45, 0.25, 0.02),
                "accent": (1.0, 0.88, 0.35),
                "eye": (1.0, 0.3, 0.0),
                "plinth": (0.1, 0.12, 0.16),
                "runic": (1.0, 0.65, 0.05),
            }
        },
    ]

    master_blend_path = os.path.join(assets_3d_dir, "asb_mascots.blend")

    # Generate each mascot individually for renders & exports
    for cfg in mascot_configs:
        print(f"\n==========================================")
        print(f"Generating 3D Mascot in Blender: {cfg['name']}")
        print(f"==========================================")
        clear_scene()
        setup_studio_lighting(cfg["accent_hex"])

        cols = cfg["colors"]
        mat_primary = create_pbr_material("Mat_Primary", cols["primary"], metallic=0.45, roughness=0.35)
        mat_dark = create_pbr_material("Mat_Dark", cols["dark"], metallic=0.6, roughness=0.4)
        mat_accent = create_pbr_material("Mat_Accent", cols["accent"], metallic=0.85, roughness=0.25)
        mat_eye = create_pbr_material("Mat_Eye", cols["eye"], metallic=0.1, roughness=0.1, emission_color=cols["eye"], emission_strength=4.0)
        mat_plinth = create_pbr_material("Mat_Plinth", cols["plinth"], metallic=0.3, roughness=0.6)
        mat_runic = create_pbr_material("Mat_Runic", cols["runic"], metallic=0.1, roughness=0.2, emission_color=cols["runic"], emission_strength=3.5)

        mascot_obj, pedestal_obj = cfg["builder"](
            mat_primary, mat_dark, mat_accent, mat_eye, mat_plinth, mat_runic
        )

        # Render 3D studio raytraced hero image
        render_path = os.path.join(images_dir, f"{cfg['file_prefix']}_blender_render.png")
        render_hero_image(render_path)

        # Export OBJ and GLB
        export_obj_and_glb(mascot_obj, cfg["file_prefix"], assets_3d_dir)

    # Finally, build the Master 4-Mascot Coliseum Scene in asb_mascots.blend
    clear_scene()
    setup_studio_lighting("#FFFFFF")
    print(f"\nBuilding Master 4-Mascot Coliseum Scene: {master_blend_path}")

    coliseum_positions = [
        (-2.2, 0, 0),  # Ruby (Left)
        (-0.7, 1.2, 0), # Sapphire (Back-Left)
        (0.7, 1.2, 0),  # Emerald (Back-Right)
        (2.2, 0, 0),   # Topaz (Right)
    ]

    for idx, cfg in enumerate(mascot_configs):
        cols = cfg["colors"]
        mat_primary = create_pbr_material(f"Mat_Primary_{cfg['id']}", cols["primary"], metallic=0.45, roughness=0.35)
        mat_dark = create_pbr_material(f"Mat_Dark_{cfg['id']}", cols["dark"], metallic=0.6, roughness=0.4)
        mat_accent = create_pbr_material(f"Mat_Accent_{cfg['id']}", cols["accent"], metallic=0.85, roughness=0.25)
        mat_eye = create_pbr_material(f"Mat_Eye_{cfg['id']}", cols["eye"], metallic=0.1, roughness=0.1, emission_color=cols["eye"], emission_strength=4.0)
        mat_plinth = create_pbr_material(f"Mat_Plinth_{cfg['id']}", cols["plinth"], metallic=0.3, roughness=0.6)
        mat_runic = create_pbr_material(f"Mat_Runic_{cfg['id']}", cols["runic"], metallic=0.1, roughness=0.2, emission_color=cols["runic"], emission_strength=3.5)

        m_obj, p_obj = cfg["builder"](
            mat_primary, mat_dark, mat_accent, mat_eye, mat_plinth, mat_runic
        )

        pos = coliseum_positions[idx]
        m_obj.location.x += pos[0]
        m_obj.location.y += pos[1]
        p_obj.location.x += pos[0]
        p_obj.location.y += pos[1]

    bpy.ops.wm.save_as_mainfile(filepath=master_blend_path)
    print(f"Master Blender file saved successfully: {master_blend_path}")

if __name__ == "__main__":
    main()
