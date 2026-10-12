"""Reimport the actual exported Run GLB in a fresh Blender scene and sample it."""
import hashlib
import json
from pathlib import Path

import bpy

BASE = Path(__file__).resolve().parent


def positions(mesh):
    obj = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = obj.to_mesh()
    result = [obj.matrix_world @ v.co for v in data.vertices]
    obj.to_mesh_clear()
    return result


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(BASE/'foxfire-run.glb'), merge_vertices=False)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in scene.objects if o.type == 'MESH')
assert len(rig.data.bones) == 25
assert sum(b.name.startswith('tail_') for b in rig.data.bones) == 5
assert all(v.groups for v in mesh.data.vertices)
assert len(bpy.data.actions) == 1
scene.frame_set(1)
first = positions(mesh)
samples = []
for frame in (4,7,10,13,16,19,22,25):
    scene.frame_set(frame)
    points = positions(mesh)
    samples.append({'frame':frame,'max_delta_from_first':max((a-b).length for a,b in zip(first,points))})
assert all(r['max_delta_from_first'] > .01 for r in samples[:-1])
assert samples[-1]['max_delta_from_first'] < 1e-5
report = {'date':'2026-10-13','blender':bpy.app.version_string,
          'sha256':hashlib.sha256((BASE/'foxfire-run.glb').read_bytes()).hexdigest(),
          'bone_count':len(rig.data.bones),'weighted_vertices':len(mesh.data.vertices),
          'actions':[a.name for a in bpy.data.actions], 'fps':30, 'actual_glb_deformation_checks':samples,
          'scope':'Fresh Blender GLB import and actual skinned motion; not a game integration test.'}
(BASE/'roundtrip-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('RUN_ROUNDTRIP_PASS '+json.dumps(report))
