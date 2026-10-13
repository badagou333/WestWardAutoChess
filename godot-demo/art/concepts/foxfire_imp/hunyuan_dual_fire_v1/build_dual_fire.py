"""Independent high/low fire hands over the approved grounded Idle/Run.

Run with Blender --background --factory-startup --python this_file -- --preview
for the two-frame posture gate; --build exports only compact animation channels.
Source model, body motion, geometry, weights and material assets are immutable.
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

BASE = Path(__file__).resolve().parent
SOURCE = BASE.parent / 'hunyuan_board_actor_v1/foxfire-board-actor.blend'
TEMP = Path('/private/tmp/foxfire-dual-fire-actions.glb')
ARMS = [prefix+'.'+side for side in ('L','R') for prefix in ('upper_arm','forearm','hand')]
PALM_REST_NORMAL = Vector((0,0,-1))
ORBS = {'L': {'up_offset': .054, 'core_radius': .047, 'maximum_tip_height_above_center': .083},
        'R': {'up_offset': .053, 'core_radius': .042, 'maximum_tip_height_above_center': .075}}

def update(): bpy.context.view_layer.update()
def bind(rig, action):
    rig.animation_data_create(); rig.animation_data.action=action
    if action.slots: rig.animation_data.action_slot=action.slots[0]
    update()
def fcurves(action):
    return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
def curve_signature(action, exclude_arm=False):
    return [(fc.data_path,fc.array_index,[(tuple(k.co),k.interpolation) for k in fc.keyframe_points])
            for fc in fcurves(action) if not exclude_arm or not any('"'+n+'"' in fc.data_path for n in ARMS)]
def points(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); data=obj.to_mesh()
    result=[obj.matrix_world@v.co for v in data.vertices]; obj.to_mesh_clear(); return result
def frame_basis(direction, normal):
    a=direction.normalized(); b=(normal-a*normal.dot(a)).normalized(); c=a.cross(b)
    return Matrix((a,b,c)).transposed()
def set_bone(rig, name, direction, normal):
    rest=rig.data.bones[name].matrix_local.to_quaternion()
    delta=frame_basis(direction,normal)@frame_basis(rest@Vector((0,1,0)),PALM_REST_NORMAL).transposed()
    q=(delta.to_quaternion()@rest).normalized()
    pb=rig.pose.bones[name]
    pb.matrix=Matrix.Translation(pb.head)@q.to_matrix().to_4x4(); update()
def solve_elbow(shoulder, wrist, pole, a, b):
    delta=wrist-shoulder; dist=min(delta.length,a+b-.001)
    axis=delta.normalized(); wrist=shoulder+axis*dist
    along=(a*a-b*b+dist*dist)/(2*dist)
    height=math.sqrt(max(0,a*a-along*along))
    perpendicular=pole-shoulder-axis*(pole-shoulder).dot(axis)
    return shoulder+axis*along+perpendicular.normalized()*height,wrist
def palm_offset(rig, side):
    # Aiming socket toward the finger roots, not a sphere seated in the palm.
    return Vector((0,rig.data.bones['hand.'+side].length*.65,0))

def dual_pose(rig, phase=0, running=False):
    chest_delta=rig.pose.bones['chest'].matrix@rig.data.bones['chest'].matrix_local.inverted()
    rotation=chest_delta.to_quaternion()
    evidence={}
    for side,sign in [('L',1),('R',-1)]:
        # Distinct gestures: L is a bent elbow / raised spell hand, R hangs low
        # beside the hip. Neither is a mirrored half of a centered serving bowl.
        base=Vector((.265,-.245,.595) if side=='L' else (-.28,-.20,.485))
        pole_local=Vector((.275,-.035,.435) if side=='L' else (-.225,-.055,.40))
        wave=math.sin(phase+(0 if side=='L' else math.pi*.65))
        wave0=math.sin(0 if side=='L' else math.pi*.65)
        breath=wave-wave0
        amp=.013 if running else .0045
        base+=Vector((sign*amp*.35*breath,amp*.65*breath,amp*breath))
        pole_local+=Vector((sign*amp*.3*breath,0,amp*.35*breath))
        shoulder=rig.pose.bones['upper_arm.'+side].head.copy()
        wrist=chest_delta@base; pole=chest_delta@pole_local
        elbow,wrist=solve_elbow(shoulder,wrist,pole,rig.data.bones['upper_arm.'+side].length,rig.data.bones['forearm.'+side].length)
        set_bone(rig,'upper_arm.'+side,elbow-shoulder,rotation@Vector((0,-1,.15)))
        set_bone(rig,'forearm.'+side,wrist-elbow,rotation@Vector((-sign*.16,-.10,.98)))
        fingers=rotation@Vector((sign*.25,-.93,(.27 if side=='L' else -.16)+.06*breath))
        palm=rotation@Vector((-.74,-.10,.665) if side=='L' else (.38,-.38,.844))
        set_bone(rig,'hand.'+side,fingers,palm)
        hand=rig.pose.bones['hand.'+side]; rest_hand=rig.data.bones['hand.'+side]
        actual_palm=hand.matrix.to_quaternion()@(rest_hand.matrix_local.to_quaternion().inverted()@PALM_REST_NORMAL)
        hand_direction=(hand.tail-hand.head).normalized()
        forearm_direction=(hand.head-elbow).normalized()
        evidence[side]={'shoulder':list(shoulder),'elbow':list(elbow),'wrist':list(hand.head),
                       'palm':list(hand.matrix@palm_offset(rig,side)), 'palm_normal':list(actual_palm),
                       'wrist_direction_change_degrees':math.degrees(forearm_direction.angle(hand_direction))}
    return evidence

def make_orbs():
    mat=bpy.data.materials.new('PreviewAmber'); mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(1,.20,.01,1); bs.inputs['Roughness'].default_value=.4
    bs.inputs['Emission Color'].default_value=(1,.16,.006,1); bs.inputs['Emission Strength'].default_value=.4
    orbs={}
    for side in ('L','R'):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=ORBS[side]['core_radius'])
        orb=bpy.context.object; orb.name='PreviewIndependentOrb_'+side; orb.data.materials.append(mat)
        orbs[side]=orb
    return orbs
def place_orbs(rig, orbs):
    for side,orb in orbs.items():
        orb.location=rig.pose.bones['hand.'+side].matrix@palm_offset(rig,side)+Vector((0,0,ORBS[side]['up_offset']))
def render_pose(scene, rig, orbs, prefix):
    scene.render.resolution_x=scene.render.resolution_y=720
    scene.cycles.samples=16; scene.camera.data.ortho_scale=1.26
    place_orbs(rig,orbs)
    for angle,location in [('front',(.1,-3,1.12)),('side',(3,-.40,1.15))]:
        scene.camera.location=location
        scene.camera.rotation_euler=(Vector((0,-.075,.51))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(BASE/f'{prefix}-{angle}.png'); bpy.ops.render.render(write_still=True)

def read_gltf(path):
    data=path.read_bytes(); n,kind=struct.unpack_from('<II',data,12)
    document=json.loads(data[20:20+n]); offset=20+n; n,kind=struct.unpack_from('<II',data,offset)
    return document,data[offset+8:offset+8+n]
def read_accessor(doc, blob, index):
    a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    offset=view.get('byteOffset',0)+a.get('byteOffset',0); stride=view.get('byteStride',width*4)
    values=[list(struct.unpack_from('<'+'f'*width,blob,offset+i*stride)) for i in range(a['count'])]
    return [v[0] for v in values] if width==1 else values

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene; scene.render.fps=30
    rig=bpy.data.objects['Foxfire_Rig']; mesh=bpy.data.objects['Foxfire_Mesh']
    if '--build' not in sys.argv:
        preview=bpy.data.actions['Idle'].copy(); preview.name='DualFirePreview'
        bind(rig,preview); scene.frame_set(1); update()
        evidence=dual_pose(rig)
        for bone_name in ARMS:
            rig.pose.bones[bone_name].keyframe_insert(data_path='rotation_quaternion',frame=1,group=bone_name)
            rig.pose.bones[bone_name].keyframe_insert(data_path='location',frame=1,group=bone_name)
        render_pose(scene,rig,make_orbs(),'pose')
        (BASE/'pose-report.json').write_text(json.dumps({'hands':evidence,'orbs':ORBS},indent=2)+'\n')
        return
    source_actions={name:bpy.data.actions[name] for name in ('Idle','Run')}
    signatures={name:curve_signature(action) for name,action in source_actions.items()}
    clips={}; evidence={}
    for base_name,source_action in source_actions.items():
        name='DualFire'+base_name; action=source_action.copy(); action.name=name; clips[name]=action
        count=90 if base_name=='Idle' else 20; bind(rig,action); checks=[]; previous={}
        for i in range(count+1):
            scene.frame_set(i+1); update(); data=dual_pose(rig,2*math.pi*i/count,base_name=='Run')
            for bone_name in ARMS:
                pb=rig.pose.bones[bone_name]
                assert pb.location.length < 1e-5, (name,bone_name,'unexpected joint translation',list(pb.location))
                assert max(abs(s-1) for s in pb.scale) < 1e-5, (name,bone_name,'unexpected scale')
                if bone_name in previous and pb.rotation_quaternion.dot(previous[bone_name])<0: pb.rotation_quaternion.negate()
                previous[bone_name]=pb.rotation_quaternion.copy()
                pb.keyframe_insert(data_path='rotation_quaternion',frame=i+1,group=bone_name)
                pb.keyframe_insert(data_path='location',frame=i+1,group=bone_name)
            update(); pts=points(mesh)
            checks.append({'frame':i+1,'hands':data,'mesh_min_z':min(v.z for v in pts)})
        for fc in fcurves(action):
            if any('"'+n+'"' in fc.data_path for n in ARMS):
                for key in fc.keyframe_points: key.interpolation='LINEAR'
        assert curve_signature(action,True)==curve_signature(source_action,True)
        scene.frame_set(1); update(); first=points(mesh)
        scene.frame_set(count+1); update(); last=points(mesh)
        error=max((a-b).length for a,b in zip(first,last)); assert error<1e-5,(name,error)
        palm_pairs=[(Vector(row['hands']['L']['palm']),Vector(row['hands']['R']['palm'])) for row in checks]
        evidence[name]={'duration':count/30,'non_arm_curves_exact':True,'loop_mesh_error':error,
            'evaluated_frames':count+1,'mesh_min_z':min(row['mesh_min_z'] for row in checks),
            'minimum_palm_separation':min((a-b).length for a,b in palm_pairs),
            'high_minus_low_palm_z_range':[min(a.z-b.z for a,b in palm_pairs),max(a.z-b.z for a,b in palm_pairs)],
            'hands':{side:{'minimum_palm_up_dot':min(row['hands'][side]['palm_normal'][2] for row in checks),
                'maximum_wrist_direction_change_degrees':max(row['hands'][side]['wrist_direction_change_degrees'] for row in checks)} for side in ('L','R')},
            'samples':[row for row in checks if row['frame'] in (1,1+count//4,1+count//2,1+3*count//4,count+1)]}
    assert all(curve_signature(a)==signatures[n] for n,a in source_actions.items())
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bind(rig,clips['DualFireIdle']); scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(TEMP),export_format='GLB',use_selection=True,export_animations=True,
        export_animation_mode='ACTIONS',export_skins=True,export_rest_position_armature=True,export_current_frame=False)
    doc,blob=read_gltf(TEMP); offset=1/30
    output={'schema':1,'space':'glTF parent-node local TRS, compatible with original GLB animation tracks',
            'quaternion_order':'xyzw','up':'Y','model_front':'+Z', 'source_time_offset':offset,
            'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'replace_only_bones':ARMS,
            'palm_offsets':{s:{'bone':'hand.'+s,'position':list(palm_offset(rig,s))} for s in ('L','R')},
            'orbs':ORBS,'clips':{}}
    for animation in doc['animations']:
        if animation['name'] not in clips: continue
        tracks=[]; duration=evidence[animation['name']]['duration']
        for channel in animation['channels']:
            target=channel['target']; bone=doc['nodes'][target['node']]['name']
            if bone not in ARMS: continue
            # Pose solve preserves rest joint offsets/scale; the source animation
            # already owns these. Avoid replacing them with floating-point noise.
            if target['path'] != 'rotation': continue
            sampler=animation['samplers'][channel['sampler']]
            times=[v-offset for v in read_accessor(doc,blob,sampler['input'])]
            times=[0 if abs(v)<1e-6 else duration if abs(v-duration)<1e-6 else v for v in times]
            tracks.append({'bone':bone,'path':target['path'],'interpolation':sampler.get('interpolation','LINEAR'),
                           'times':times,'values':read_accessor(doc,blob,sampler['output'])})
        output['clips'][animation['name']]={'duration':duration,'tracks':tracks}
    assert set(output['clips'])==set(clips)
    (BASE/'dual-fire-animations.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
    (BASE/'build-report.json').write_text(json.dumps({'date':'2026-10-13','mesh_weights_materials_unchanged':True,
        'original_actions_unchanged':True,'modified_bones':ARMS,'evidence':evidence},indent=2)+'\n')
    print('DUAL_FIRE_EXPORT '+json.dumps({'bytes':(BASE/'dual-fire-animations.json').stat().st_size,
          'tracks':{k:len(v['tracks']) for k,v in output['clips'].items()}}),flush=True)
    if '--render' in sys.argv:
        orbs=make_orbs()
        for name,action in clips.items():
            bind(rig,action)
            for frame in ([1,31,61] if name=='DualFireIdle' else [1,6,11,16]):
                scene.frame_set(frame); update(); render_pose(scene,rig,orbs,f'{name}-{frame:03}')

if __name__=='__main__': main()
