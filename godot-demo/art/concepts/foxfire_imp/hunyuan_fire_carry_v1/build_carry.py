"""Create cupped fire-carry arms over unchanged approved Idle/Run body motion.

Only compact official glTF animation channels are retained in this directory.
The original mesh, rig, source clips and all non-arm animation remain untouched.
"""
import argparse, hashlib, json, math, struct, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

BASE=Path(__file__).resolve().parent
SOURCE=BASE.parent/'hunyuan_board_actor_v1/foxfire-board-actor.blend'
TEMP=Path('/private/tmp/foxfire-carry-actions.glb')
ARMS=[prefix+'.'+side for side in ('L','R') for prefix in ('upper_arm','forearm','hand')]
PALM_REST_NORMAL=Vector((0,0,-1))

def update(): bpy.context.view_layer.update()
def bind(rig,action):
    rig.animation_data_create(); rig.animation_data.action=action
    if action.slots: rig.animation_data.action_slot=action.slots[0]
    update()
def fcurves(action):
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
def curve_signature(action,exclude_arm=False):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation) for k in fc.keyframe_points]) for fc in fcurves(action)
            if not exclude_arm or not any('"'+name+'"' in fc.data_path for name in ARMS)]
def points(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); data=obj.to_mesh()
    result=[obj.matrix_world@v.co for v in data.vertices]; obj.to_mesh_clear(); return result
def frame_basis(direction,normal):
    a=direction.normalized(); b=(normal-a*normal.dot(a)).normalized(); c=a.cross(b)
    return Matrix((a,b,c)).transposed()
def bone_rotation(rig,name,direction,palm_normal):
    rest=rig.data.bones[name].matrix_local.to_quaternion()
    rest_direction=rest@Vector((0,1,0))
    delta=frame_basis(direction,palm_normal)@frame_basis(rest_direction,PALM_REST_NORMAL).transposed()
    return (delta.to_quaternion()@rest).normalized()
def set_bone(rig,name,direction,normal):
    pb=rig.pose.bones[name]
    q=bone_rotation(rig,name,direction,normal)
    pb.matrix=Matrix.Translation(pb.head)@q.to_matrix().to_4x4()
    update()
def solve_elbow(shoulder,wrist,pole,length_a,length_b):
    delta=wrist-shoulder; dist=min(delta.length,length_a+length_b-.001)
    axis=delta.normalized(); wrist=shoulder+axis*dist
    along=(length_a*length_a-length_b*length_b+dist*dist)/(2*dist)
    height=math.sqrt(max(0,length_a*length_a-along*along))
    perpendicular=pole-shoulder-axis*(pole-shoulder).dot(axis)
    return shoulder+axis*along+perpendicular.normalized()*height,wrist

def carry_pose(rig):
    chest_delta=rig.pose.bones['chest'].matrix@rig.data.bones['chest'].matrix_local.inverted()
    rotation=chest_delta.to_quaternion()
    evidence={}
    for side,sign in [('L',1),('R',-1)]:
        shoulder=rig.pose.bones['upper_arm.'+side].head.copy()
        wrist=chest_delta@Vector((sign*.115,-.325,.558))
        pole=chest_delta@Vector((sign*.26,-.09,.43))
        elbow,wrist=solve_elbow(shoulder,wrist,pole,rig.data.bones['upper_arm.'+side].length,rig.data.bones['forearm.'+side].length)
        # Upper arm falls down; forearm turns naturally forward/up into a shallow bowl.
        set_bone(rig,'upper_arm.'+side,elbow-shoulder,rotation@Vector((0,-1,.12)))
        set_bone(rig,'forearm.'+side,wrist-elbow,rotation@Vector((-sign*.25,-.10,.96)))
        fingers=(rotation@Vector((-sign*.72,-.67,.14))).normalized()
        palm=(rotation@Vector((-sign*.45,.04,.892))).normalized()
        set_bone(rig,'hand.'+side,fingers,palm)
        hand=rig.pose.bones['hand.'+side]
        rest_hand=rig.data.bones['hand.'+side]
        # Palm center is midway from wrist into the hand; use matching local offset.
        palm_offset=Vector((0,rest_hand.length*.42,0))
        palm_position=hand.matrix@palm_offset
        actual_palm=hand.matrix.to_quaternion()@(rest_hand.matrix_local.to_quaternion().inverted()@PALM_REST_NORMAL)
        evidence[side]={'shoulder':list(shoulder),'elbow':list(elbow),'wrist':list(hand.head),
                       'palm':list(palm_position),'palm_normal':list(actual_palm),
                       'hand_local_palm_offset_blender':list(palm_offset)}
    return evidence

def read_gltf(path):
    data=path.read_bytes(); n,kind=struct.unpack_from('<II',data,12)
    document=json.loads(data[20:20+n]); offset=20+n
    n,kind=struct.unpack_from('<II',data,offset)
    return document,data[offset+8:offset+8+n]
def read_accessor(doc,blob,index):
    accessor=doc['accessors'][index]; view=doc['bufferViews'][accessor['bufferView']]
    width={'SCALAR':1,'VEC3':3,'VEC4':4}[accessor['type']]
    offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    stride=view.get('byteStride',width*4)
    values=[list(struct.unpack_from('<'+'f'*width,blob,offset+i*stride)) for i in range(accessor['count'])]
    return [v[0] for v in values] if width==1 else values
def render(scene,rig,orb,clips):
    folder=BASE/'drafts'; folder.mkdir(exist_ok=True)
    scene.render.resolution_x=scene.render.resolution_y=640
    scene.cycles.samples=12
    scene.camera.data.ortho_scale=1.30
    for name,action in clips.items():
        bind(rig,action)
        for frame in ([1,24,47] if name=='CarryIdle' else [1,6,11,16]):
            scene.frame_set(frame); update()
            palms=[rig.pose.bones['hand.'+s].matrix@Vector((0,rig.data.bones['hand.'+s].length*.42,0)) for s in ('L','R')]
            orb.location=(palms[0]+palms[1])*.5+Vector((0,0,.075))
            for angle,location in [('front',(1.05,-3,1.32)),('side',(3,-.30,1.15))]:
                scene.camera.location=location
                scene.camera.rotation_euler=(Vector((0,-.075,.52))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
                scene.render.filepath=str(folder/f'{name}-{frame:03}-{angle}.png')
                bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene; scene.render.fps=30
    rig=bpy.data.objects['Foxfire_Rig']; mesh=bpy.data.objects['Foxfire_Mesh']
    source_actions={name:bpy.data.actions[name] for name in ['Idle','Run']}
    signatures={name:curve_signature(action) for name,action in source_actions.items()}
    clips={}; evidence={}
    for base_name,source_action in source_actions.items():
        name='Carry'+base_name; action=source_action.copy(); action.name=name
        clips[name]=action
        count=90 if base_name=='Idle' else 20
        bind(rig,action); checks=[]; previous={}
        for i in range(count+1):
            scene.frame_set(i+1); update()
            data=carry_pose(rig)
            for bone_name in ARMS:
                pb=rig.pose.bones[bone_name]
                if bone_name in previous and pb.rotation_quaternion.dot(previous[bone_name])<0: pb.rotation_quaternion.negate()
                previous[bone_name]=pb.rotation_quaternion.copy()
                pb.keyframe_insert(data_path='rotation_quaternion',frame=i+1,group=bone_name)
                pb.keyframe_insert(data_path='location',frame=i+1,group=bone_name)
            update(); pts=points(mesh)
            checks.append({'frame':i+1,'hands':data,'mesh_min_z':min(v.z for v in pts)})
        for fc in fcurves(action):
            if any('"'+n+'"' in fc.data_path for n in ARMS):
                for k in fc.keyframe_points: k.interpolation='LINEAR'
        assert curve_signature(action,True)==curve_signature(source_action,True)
        scene.frame_set(1); update(); first=points(mesh)
        scene.frame_set(count+1); update(); last=points(mesh)
        error=max((a-b).length for a,b in zip(first,last))
        assert error<1e-5,(name,'loop',error)
        evidence[name]={'duration':count/30,'non_arm_curves_exact':True,'loop_mesh_error':error,'samples':checks}
    assert all(curve_signature(a)==signatures[n] for n,a in source_actions.items())
    # Armature-only temporary export contains no mesh or texture copies.
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig; bind(rig,clips['CarryIdle']); scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(TEMP),export_format='GLB',use_selection=True,export_animations=True,
       export_animation_mode='ACTIONS',export_skins=True,export_rest_position_armature=True,export_current_frame=False)
    doc,blob=read_gltf(TEMP)
    source_time_offset=1/30
    output={'schema':1,'space':'glTF parent-node local TRS, compatible with original GLB animation tracks',
            'quaternion_order':'xyzw','up':'Y','model_front':'+Z','source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'source_time_offset':source_time_offset,'replace_only_bones':ARMS,
            'palm_offsets':{side:{'bone':'hand.'+side,'position':[0,rig.data.bones['hand.'+side].length*.42,0]} for side in ['L','R']},
            'orb':{'center':'midpoint of transformed palm offsets plus model up offset; multiply by actor scale only once',
                   'up_offset':.075,'core_radius':.077,'maximum_tip_height_above_center':.10},'clips':{}}
    for animation in doc['animations']:
        if animation['name'] not in clips: continue
        tracks=[]
        for channel in animation['channels']:
            target=channel['target']; bone=doc['nodes'][target['node']]['name']
            if bone not in ARMS: continue
            sampler=animation['samplers'][channel['sampler']]
            duration=evidence[animation['name']]['duration']
            times=[value-source_time_offset for value in read_accessor(doc,blob,sampler['input'])]
            times=[0 if abs(value)<1e-6 else duration if abs(value-duration)<1e-6 else value for value in times]
            tracks.append({'bone':bone,'path':target['path'],'interpolation':sampler.get('interpolation','LINEAR'),
                'times':times,'values':read_accessor(doc,blob,sampler['output'])})
        output['clips'][animation['name']]={'duration':evidence[animation['name']]['duration'],'tracks':tracks}
    assert set(output['clips'])==set(clips)
    (BASE/'carry-animations.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
    report={'date':'2026-10-13','method':'Two-bone arm solve in animated chest frame, shallow cupped palms; official glTF exporter extracts arm-only channels',
            'mesh_weights_materials_unchanged':True,'original_actions_unchanged':True,'modified_bones':ARMS,'evidence':evidence}
    (BASE/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('CARRY_EXPORT '+json.dumps({'clip_tracks':{k:len(v['tracks']) for k,v in output['clips'].items()},'bytes':(BASE/'carry-animations.json').stat().st_size}),flush=True)
    # Neutral stand-in establishes palm support and face clearance; real fire is engine VFX.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=.077)
    orb=bpy.context.object; orb.name='PreviewOrb_NotExported'
    mat=bpy.data.materials.new('PreviewAmber'); mat.diffuse_color=(1,.24,.018,1); mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(1,.20,.01,1)
    bs.inputs['Roughness'].default_value=.35; bs.inputs['Emission Color'].default_value=(1,.16,.006,1); bs.inputs['Emission Strength'].default_value=.3
    orb.data.materials.append(mat)
    if '--render' in sys.argv: render(scene,rig,orb,clips)

if __name__=='__main__': main()
