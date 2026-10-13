"""Validate final GLB structure, reference preservation, and actual animation skinning."""
import hashlib,json,struct
from pathlib import Path
import bpy

BASE=Path(__file__).resolve().parent
PATH=BASE/'foxfire-board-actor.glb'
SOURCE=BASE.parent/'hunyuan_run_v2/foxfire-run.glb'

def glb(path):
    raw=path.read_bytes(); length,kind=struct.unpack_from('<II',raw,12)
    doc=json.loads(raw[20:20+length]); offset=20+length
    size,kind=struct.unpack_from('<II',raw,offset)
    return doc,raw[offset+8:offset+8+size]
def image_hashes(doc,blob):
    result=[]
    for image in doc.get('images',[]):
        view=doc['bufferViews'][image['bufferView']]; offset=view.get('byteOffset',0)
        result.append(hashlib.sha256(blob[offset:offset+view['byteLength']]).hexdigest())
    return result
def accessor(doc,blob,index):
    ac=doc['accessors'][index]; v=doc['bufferViews'][ac['bufferView']]
    offset=v.get('byteOffset',0)+ac.get('byteOffset',0)
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[ac['type']]
    code={5121:'B',5123:'H',5125:'I',5126:'f'}[ac['componentType']]
    size=struct.calcsize('<'+code)*width; stride=v.get('byteStride',size)
    return [struct.unpack_from('<'+code*width,blob,offset+i*stride) for i in range(ac['count'])]
def positions(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); data=obj.to_mesh()
    result=[obj.matrix_world@v.co for v in data.vertices]; obj.to_mesh_clear(); return result
def bind(rig,action):
    rig.animation_data_create(); rig.animation_data.action=action
    if action.slots: rig.animation_data.action_slot=action.slots[0]
    bpy.context.view_layer.update()

doc,blob=glb(PATH); source,sblob=glb(SOURCE)
assert {a['name'] for a in doc['animations']}=={'Idle','Run'}
assert len(doc['skins'][0]['joints'])==25
images_same=image_hashes(doc,blob)==image_hashes(source,sblob)
assert images_same
primitive=doc['meshes'][0]['primitives'][0]; sprim=source['meshes'][0]['primitives'][0]
geometry={}
for semantic in ['POSITION','NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0']:
    first=accessor(doc,blob,primitive['attributes'][semantic]); second=accessor(source,sblob,sprim['attributes'][semantic])
    max_error=max(abs(x-y) for a,b in zip(first,second) for x,y in zip(a,b))
    assert len(first)==len(second) and max_error<1e-6,(semantic,max_error)
    geometry[semantic]={'count':len(first),'max_error':max_error}
assert accessor(doc,blob,primitive['indices'])==accessor(source,sblob,sprim['indices'])

bpy.ops.wm.read_factory_settings(use_empty=True); scene=bpy.context.scene; scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(PATH),merge_vertices=False)
rig=next(o for o in scene.objects if o.type=='ARMATURE'); mesh=next(o for o in scene.objects if o.type=='MESH')
assert len(rig.data.bones)==25
soles={s:[v.index for v in mesh.data.vertices if v.co.z<.064 and sign*v.co.x>.06] for sign,s in [(1,'L'),(-1,'R')]}
reports={}
for action in bpy.data.actions:
    bind(rig,action); start,end=map(float,action.frame_range)
    scene.frame_set(int(start)); first=positions(mesh)
    checks=[]
    steps=180 if action.name=='Idle' else 40
    for i in range(steps+1):
        frame=start+(end-start)*i/steps
        scene.frame_set(int(frame),subframe=frame-int(frame)); pts=positions(mesh)
        checks.append({'frame':frame,'sole_min':{s:min(pts[v].z for v in ids) for s,ids in soles.items()},'mesh_min_z':min(p.z for p in pts),'max_delta':max((a-b).length for a,b in zip(first,pts))})
    assert checks[-1]['max_delta']<1e-5,(action.name,'not closed')
    assert min(min(r['sole_min'].values()) for r in checks)>-.0001,(action.name,'floor')
    assert min(r['mesh_min_z'] for r in checks)>-.0001,(action.name,'mesh floor')
    reports[action.name]={'range':list(action.frame_range),'duration':(end-start)/30,'samples':len(checks),'max_deformation':max(row['max_delta'] for row in checks),'loop_delta':checks[-1]['max_delta'],'sole_min':{s:min(r['sole_min'][s] for r in checks) for s in soles},'sole_max':{s:max(r['sole_min'][s] for r in checks) for s in soles},'first_frame_aabb_blender':{'min':[min(p[i] for p in first) for i in range(3)],'max':[max(p[i] for p in first) for i in range(3)]},'sample_details':checks}
rest=accessor(doc,blob,primitive['attributes']['POSITION'])
report={'date':'2026-10-13','glb_sha256':hashlib.sha256(PATH.read_bytes()).hexdigest(),'bytes':PATH.stat().st_size,'animations':reports,'bones':len(rig.data.bones),'geometry_vs_run_v2':geometry,'triangles':len(accessor(doc,blob,primitive['indices']))//3,'embedded_images_exact':images_same,'rest_aabb_gltf':{'min':[min(p[i] for p in rest) for i in range(3)],'max':[max(p[i] for p in rest) for i in range(3)]},'scope':'Fresh GLB import and sampled real skinning. Not gameplay, cloth self-collision, or performance acceptance.'}
(BASE/'roundtrip-report.json').write_text(json.dumps(report,indent=2)+'\n')
print('ACTOR_ROUNDTRIP_PASS '+json.dumps({k:v for k,v in report.items() if k!='animations'}))
print('ANIMATION_CHECKS '+json.dumps({k:{x:y for x,y in v.items() if x!='sample_details'} for k,v in reports.items()}))
