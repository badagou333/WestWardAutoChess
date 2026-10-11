"""Small, local Blender automation probe; not a project character."""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

output = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, 24
scene.render.fps = 24
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.resolution_x = 480
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("ProbeWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.21, 0.24, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.45

def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    result.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    result.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    return result

ochre = material("Ochre", (0.65, 0.35, 0.08))
teal = material("Teal", (0.08, 0.38, 0.42))
ivory = material("Ivory", (0.8, 0.75, 0.58))
floor_material = material("Floor", (0.25, 0.3, 0.3))

bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = "ProbeRig"
bpy.ops.object.mode_set(mode="EDIT")
root = rig.data.edit_bones[0]
root.name = "root"
root.head, root.tail = (0, 0, 0), (0, 0, 1.1)
head = rig.data.edit_bones.new("head")
head.head, head.tail = (0, 0, 1.1), (0, 0, 2.1)
head.parent = root
bpy.ops.object.mode_set(mode="OBJECT")

def bind(obj, bone):
    obj.parent = rig
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("ProbeSkin", "ARMATURE")
    modifier.object = rig
    return obj

bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.8))
body = bpy.context.object
body.name = "Body"
body.scale = (0.85, 0.6, 1.35)
body.data.materials.append(ochre)
bind(body, "root")
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.48, location=(0, 0, 1.78))
head_mesh = bpy.context.object
head_mesh.name = "Head"
head_mesh.data.materials.append(ivory)
bind(head_mesh, "head")
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.35, 1.78))
marker = bpy.context.object
marker.name = "FrontMarker"
marker.scale = (0.34, 0.25, 0.16)
marker.data.materials.append(teal)
bind(marker, "head")

pose = rig.pose.bones["head"]
pose.rotation_mode = "XYZ"
for frame, angle in [(1, -0.25), (12, 0.25), (24, -0.25)]:
    pose.rotation_euler = (0, angle, 0)
    pose.keyframe_insert(data_path="rotation_euler", frame=frame)
rig.animation_data.action.name = "probe_head_turn"
scene.frame_set(1)

export_objects = [rig, body, head_mesh, marker]
bpy.ops.object.select_all(action="DESELECT")
for obj in export_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(output / "probe.glb"), export_format="GLB", use_selection=True, export_animations=True)

bpy.ops.mesh.primitive_plane_add(size=200)
floor = bpy.context.object
floor.name = "RenderFloor"
floor.data.materials.append(floor_material)
bpy.ops.object.light_add(type="AREA", location=(3, -4, 6))
light = bpy.context.object
light.data.energy = 700
light.data.shape = "DISK"
light.data.size = 4
bpy.ops.object.camera_add(location=(4, -6, 4.5))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 1.05)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.4
scene.camera = camera
scene.render.filepath = str(output / "probe.png")
bpy.ops.wm.save_as_mainfile(filepath=str(output / "probe.blend"))
bpy.ops.render.render(write_still=True)
report = {
    "blender_version": bpy.app.version_string,
    "blender_binary": bpy.app.binary_path,
    "background": bpy.app.background,
    "mesh_objects": 3,
    "bones": len(rig.data.bones),
    "animation": rig.animation_data.action.name,
    "frame_range": [1, 24],
    "fps": 24,
    "render_engine": scene.render.engine,
    "render_device": scene.cycles.device,
    "render_size": [480, 480],
    "outputs": {name: (output / name).stat().st_size for name in ["probe.blend", "probe.glb", "probe.png"]},
}
(output / "blender-result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("BLENDER_PROBE_PASS " + json.dumps(report))
