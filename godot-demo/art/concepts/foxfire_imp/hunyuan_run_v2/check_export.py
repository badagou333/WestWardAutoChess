"""Reimport final v2 GLB, check actual skinned deformation and cyclic endpoint."""
import hashlib,json
from pathlib import Path
import bpy

BASE=Path(__file__).resolve().parent
def points(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data=obj.to_mesh()
    out=[obj.matrix_world@v.co for v in data.vertices]
    obj.to_mesh_clear()
    return out

bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(BASE/'foxfire-run.glb'),merge_vertices=False)
rig=next(o for o in scene.objects if o.type=='ARMATURE')
mesh=next(o for o in scene.objects if o.type=='MESH')
assert len(rig.data.bones)==25
assert len(bpy.data.actions)==1
assert all(v.groups for v in mesh.data.vertices)
action=rig.animation_data.action
start,end=map(float,action.frame_range)
assert abs((end-start)/30-2/3)<1e-5
def sample(frame):
    scene.frame_set(int(frame),subframe=frame-int(frame))
    return points(mesh)
first=sample(start)
checks=[]
for frac in [.15,.3,.5,.7,.85,1]:
    frame=start+(end-start)*frac
    delta=max((a-b).length for a,b in zip(first,sample(frame)))
    checks.append({'frame':frame,'max_mesh_delta_from_start':delta})
assert all(row['max_mesh_delta_from_start']>.01 for row in checks[:-1])
assert checks[-1]['max_mesh_delta_from_start']<1e-5
report={'date':'2026-10-13','blender':bpy.app.version_string,
        'glb_sha256':hashlib.sha256((BASE/'foxfire-run.glb').read_bytes()).hexdigest(),
        'bones':len(rig.data.bones),'tail_bones':sum(b.name.startswith('tail_') for b in rig.data.bones),
        'weighted_vertices':len(mesh.data.vertices),'action':action.name,'range':list(action.frame_range),
        'fps':30,'actual_mesh_checks':checks,'scope':'Fresh GLB import and actual skinning, not an engine or visual quality sign-off.'}
(BASE/'roundtrip-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('V2_ROUNDTRIP_PASS '+json.dumps(report))
