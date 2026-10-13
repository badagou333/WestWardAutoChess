"""Grounded spell idle and asymmetric left/right casts on the unchanged rig.

Background Blender: --python build_spell.py -- --preview (pose gate)
Then --build --render exports compact complete glTF TRS and QA key frames.
"""
import hashlib, importlib.util, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

BASE=Path(__file__).resolve().parent
SOURCE=BASE.parent/'hunyuan_board_actor_v1/foxfire-board-actor.blend'
SOURCE_GLB=SOURCE.with_suffix('.glb')
DUAL=BASE.parent/'hunyuan_dual_fire_v1'
TEMP=Path('/private/tmp/foxfire-spell-actions.glb')
spec=importlib.util.spec_from_file_location('approved_dual_fire',DUAL/'build_dual_fire.py')
sys.dont_write_bytecode=True
dual=importlib.util.module_from_spec(spec); spec.loader.exec_module(dual)
approved=json.loads((DUAL/'dual-fire-animations.json').read_text())

def update(): bpy.context.view_layer.update()
def smooth(a):
    a=max(0,min(1,a)); return a*a*(3-2*a)
def interpolate(t, keys):
    for (a,v),(b,w) in zip(keys,keys[1:]):
        if t<=b:
            u=smooth((t-a)/(b-a))
            if isinstance(v,tuple): return Vector(v).lerp(Vector(w),u)
            return v*(1-u)+w*u
    return Vector(keys[-1][1]) if isinstance(keys[-1][1],tuple) else keys[-1][1]
def rotate_world(rig,name,axis,degrees):
    pb=rig.pose.bones[name]
    rotation=Quaternion(Vector(axis),math.radians(degrees))@pb.matrix.to_quaternion()
    pb.matrix=Matrix.Translation(pb.head)@rotation.to_matrix().to_4x4(); update()
def clear_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in list(bag.fcurves): bag.fcurves.remove(curve)
def restore(rig,base):
    for name,matrix in base.items(): rig.pose.bones[name].matrix_basis=matrix.copy()
    update()
def hand_measure(rig,side):
    hand=rig.pose.bones['hand.'+side]; fore=rig.pose.bones['forearm.'+side]
    socket=hand.matrix@Vector(approved['palm_offsets'][side]['position'])
    rest=rig.data.bones[hand.name].matrix_local.to_quaternion()
    normal=hand.matrix.to_quaternion()@(rest.inverted()@dual.PALM_REST_NORMAL)
    return {'socket':list(socket),'wrist':list(hand.head),'elbow':list(fore.head),
            'palm_normal':list(normal),
            'wrist_direction_change_degrees':math.degrees((hand.tail-hand.head).angle(fore.tail-fore.head))}
def idle_pose(rig,t):
    phase=2*math.pi*t/3
    # The lower body is the approved first standing pose, held exactly. Breathing
    # is upper-body rotation, not a bobbing root or a ground-sliding foot.
    breath=math.sin(phase)
    rotate_world(rig,'spine',(1,0,0),.75*breath)
    rotate_world(rig,'chest',(1,0,0),1.25*breath)
    rotate_world(rig,'chest',(0,0,1),.8*(math.sin(phase+.4)-math.sin(.4)))
    rotate_world(rig,'clavicle.L',(0,1,0),-.65*breath)
    rotate_world(rig,'clavicle.R',(0,1,0),.5*(math.sin(phase-.35)+math.sin(.35)))
    rotate_world(rig,'neck',(1,0,0),-.55*breath)
    rotate_world(rig,'head',(0,0,1),2.0*math.sin(phase)+.45*math.sin(2*phase))
    for i in range(1,6):
        lag=.32*i
        rotate_world(rig,f'tail_{i:02}',(0,0,1),(1.45-.13*i)*(math.sin(phase-lag)+math.sin(lag)))
    dual.dual_pose(rig,phase,False)

def attack_pose(rig,t,side='L'):
    # The entire 1.2 s gesture starts/ends at idle t0. Preparation is slower
    # than the thrust; the release event is the outward acceleration at 0.4 s.
    yaw=interpolate(t,[(0,0),(.20,9.0),(.40,-9.5),(.50,-10.5),(.72,-3.5),(1.2,0)])
    if side=='R': yaw=-yaw
    pitch=interpolate(t,[(0,0),(.20,-1.8),(.40,3.2),(.50,3.7),(.72,1.4),(1.2,0)])
    rotate_world(rig,'spine',(0,0,1),yaw*.45)
    rotate_world(rig,'chest',(0,0,1),yaw*.55)
    rotate_world(rig,'spine',(1,0,0),pitch*.35)
    rotate_world(rig,'chest',(1,0,0),pitch*.65)
    rotate_world(rig,'neck',(0,0,1),-yaw*.3)
    rotate_world(rig,'head',(0,0,1),-yaw*.45)
    rotate_world(rig,'head',(1,0,0),-pitch*.4)
    for i in range(1,6): rotate_world(rig,f'tail_{i:02}',(0,0,1),-yaw*(.09-.009*i))
    dual.dual_pose(rig,0,False)
    # Slight draw to the shoulder's outside, then forward with a retained bend.
    target=interpolate(t,[(0,(.265,-.245,.595)),(.20,(.225,-.175,.615)),
        (.40,(.185,-.435,.600)),(.50,(.185,-.440,.585)),
        (.72,(.205,-.290,.590)),(1.2,(.265,-.245,.595))])
    pole=interpolate(t,[(0,(.275,-.035,.435)),(.20,(.29,-.015,.46)),
        (.40,(.30,-.195,.455)),(.50,(.30,-.205,.45)),(1.2,(.275,-.035,.435))])
    fingers=interpolate(t,[(0,(.25,-.93,.27)),(.20,(.12,-.86,.40)),
        (.40,(.10,-.32,.94)),(.50,(.10,-.43,.88)),(.72,(.16,-.82,.55)),(1.2,(.25,-.93,.27))])
    palm=interpolate(t,[(0,(-.74,-.10,.665)),(.20,(-.6,-.15,.79)),
        (.40,(-.10,-.96,.27)),(.50,(-.10,-.93,.32)),(.72,(-.40,-.65,.62)),(1.2,(-.74,-.10,.665))])
    if side=='R':
        # Start from the existing low waist-side hand, not a mirrored high-hand
        # idle. Draw back, rise into a forward push, return to the same low hand.
        target=interpolate(t,[(0,(-.28,-.20,.485)),(.20,(-.255,-.125,.535)),
            (.40,(-.185,-.435,.565)),(.50,(-.185,-.440,.550)),
            (.72,(-.245,-.265,.510)),(1.2,(-.28,-.20,.485))])
        pole=interpolate(t,[(0,(-.225,-.055,.40)),(.20,(-.29,-.015,.425)),
            (.40,(-.30,-.195,.425)),(.50,(-.30,-.205,.42)),(1.2,(-.225,-.055,.40))])
        fingers=interpolate(t,[(0,(-.25,-.93,-.16)),(.20,(-.12,-.86,.32)),
            (.40,(-.10,-.32,.94)),(.50,(-.10,-.43,.88)),(.72,(-.16,-.90,.18)),(1.2,(-.25,-.93,-.16))])
        palm=interpolate(t,[(0,(.38,-.38,.844)),(.20,(.6,-.15,.79)),
            (.40,(.10,-.96,.27)),(.50,(.10,-.93,.32)),(.72,(.40,-.45,.75)),(1.2,(.38,-.38,.844))])
    chest=rig.pose.bones['chest'].matrix@rig.data.bones['chest'].matrix_local.inverted()
    arm='upper_arm.'+side; forearm='forearm.'+side; hand='hand.'+side
    rot=chest.to_quaternion(); shoulder=rig.pose.bones[arm].head.copy()
    elbow,wrist=dual.solve_elbow(shoulder,chest@target,chest@pole,
        rig.data.bones[arm].length,rig.data.bones[forearm].length)
    dual.set_bone(rig,arm,elbow-shoulder,rot@Vector((0,-1,.15)))
    dual.set_bone(rig,forearm,wrist-elbow,rot@Vector((-.16 if side=='L' else .16,-.10,.98)))
    dual.set_bone(rig,hand,rot@fingers,rot@palm)

def pose_frames(scene,rig,mesh,base,source_action):
    bones=list(base); clips={}; report={}; idle_start=None; idle_matrices=None
    fixed=['root','pelvis','thigh.L','shin.L','foot.L','thigh.R','shin.R','foot.R']
    for name,count,fn in [('SpellIdle',90,idle_pose),('FlameAttack',36,attack_pose),
                          ('FlameAttackRight',36,lambda rig,t: attack_pose(rig,t,'R'))]:
        action=source_action.copy(); action.name=name; clear_curves(action)
        dual.bind(rig,action); previous={}; samples=[]; maximum_foot_vertex_drift=0
        for i in range(count+1):
            scene.frame_set(i+1); restore(rig,base); fn(rig,i/30)
            for n in bones:
                pb=rig.pose.bones[n]
                if n in previous and pb.rotation_quaternion.dot(previous[n])<0: pb.rotation_quaternion.negate()
                previous[n]=pb.rotation_quaternion.copy()
                for path in ['rotation_quaternion','location','scale']:
                    pb.keyframe_insert(data_path=path,frame=i+1,group=n)
            update()
            for n in fixed:
                assert max(abs(rig.pose.bones[n].matrix_basis[r][c]-base[n][r][c]) for r in range(4) for c in range(4))<1e-6,(name,i,n)
            pts=dual.points(mesh)
            if i==0:
                start=pts; matrices={n:rig.pose.bones[n].matrix.copy() for n in bones}
                foot_indices=[j for j,p in enumerate(pts) if p.z<.09 and p.y<-.03 and abs(p.x)>.04]
                assert foot_indices
                if name=='SpellIdle': idle_start=pts; idle_matrices=matrices
                else:
                    assert max((a-b).length for a,b in zip(start,idle_start))<1e-5
            foot_drift=max((pts[j]-start[j]).length for j in foot_indices)
            maximum_foot_vertex_drift=max(maximum_foot_vertex_drift,foot_drift)
            assert foot_drift<1e-5,(name,i,'foot mesh drift',foot_drift)
            if i in [0,count//4,count//2,3*count//4,count] or (name.startswith('FlameAttack') and i in [6,12,15,22]):
                samples.append({'time':i/30,'hands':{s:hand_measure(rig,s) for s in ('L','R')},
                    'mesh_min_z':min(p.z for p in pts)})
        for curve in dual.fcurves(action):
            for k in curve.keyframe_points: k.interpolation='LINEAR'
        error=max((a-b).length for a,b in zip(start,pts)); assert error<1e-5,(name,error)
        endpoint=max(abs(rig.pose.bones[n].matrix[r][c]-idle_matrices[n][r][c]) for n in bones for r in range(4) for c in range(4))
        assert endpoint<1e-5,(name,'endpoint vs idle',endpoint)
        report[name]={'duration':count/30,'frames':count+1,'loop_mesh_error':error,
            'end_vs_idle_start_matrix_error':endpoint,'lower_body_fixed':fixed,
            'foot_mesh_samples':len(foot_indices),'maximum_foot_vertex_drift':maximum_foot_vertex_drift,'samples':samples}
        clips[name]=action
    return clips,report

def render_gate(scene,rig,clips):
    scene.render.resolution_x=scene.render.resolution_y=720; scene.cycles.samples=16
    scene.camera.data.ortho_scale=1.30
    orbs=dual.make_orbs()
    gates=[('FlameAttackRight',7,'right-windup'),('FlameAttackRight',13,'right-release'),('FlameAttackRight',19,'right-follow')]
    for name,frame,label in gates:
        dual.bind(rig,clips[name]); scene.frame_set(frame); update(); dual.place_orbs(rig,orbs)
        # Left source flame disappears after release in the final runtime. Here
        # keep a ball at release to identify the launch origin, hide on follow.
        orbs['R'].hide_render=(label=='right-follow')
        for view,loc in ([('threequarter',(-1.4,-3,1.25)),('side',(-3,-.35,1.15))] if label=='right-release' else [('threequarter',(-1.4,-3,1.25))]):
            scene.camera.location=loc
            scene.camera.rotation_euler=(Vector((0,-.10,.51))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(BASE/f'gate-{label}-{view}.png'); bpy.ops.render.render(write_still=True)

def export(scene,rig,clips,report):
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    dual.bind(rig,clips['SpellIdle']); scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(TEMP),export_format='GLB',use_selection=True,export_animations=True,
        export_animation_mode='ACTIONS',export_skins=True,export_rest_position_armature=True,export_current_frame=False)
    doc,blob=dual.read_gltf(TEMP); bones=[b.name for b in rig.data.bones]; nodes={n['name']:n for n in doc['nodes'] if n.get('name') in bones}
    offset=1/30
    out={'schema':1,'space':'glTF parent-node local TRS; complete 25-bone clips, not rest-relative deltas',
        'quaternion_order':'xyzw','up':'Y','model_front':'+Z','source_time_offset':offset,
        'base_glb_sha256':hashlib.sha256(SOURCE_GLB.read_bytes()).hexdigest(),
        'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'source_dual_fire_json_sha256':hashlib.sha256((DUAL/'dual-fire-animations.json').read_bytes()).hexdigest(),
        'bones':bones,'palm_offsets':approved['palm_offsets'],'orbs':approved['orbs'],'clips':{}}
    for animation in doc['animations']:
        name=animation['name']
        if name not in clips: continue
        duration=report[name]['duration']; tracks={}
        for channel in animation['channels']:
            target=channel['target']; bone=doc['nodes'][target['node']]['name']
            if bone not in bones: continue
            sampler=animation['samplers'][channel['sampler']]
            times=[v-offset for v in dual.read_accessor(doc,blob,sampler['input'])]
            times=[0 if abs(v)<1e-6 else duration if abs(v-duration)<1e-6 else v for v in times]
            tracks[(bone,target['path'])]={'bone':bone,'path':target['path'],'interpolation':sampler.get('interpolation','LINEAR'),
                'times':times,'values':dual.read_accessor(doc,blob,sampler['output'])}
        # Exporter may omit constant/default channels; explicitly fill from the
        # same official glTF bone nodes so a standalone Godot clip is complete.
        for bone in bones:
            for path,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]:
                if (bone,path) not in tracks:
                    value=nodes[bone].get(path,default)
                    tracks[(bone,path)]={'bone':bone,'path':path,'interpolation':'LINEAR',
                        'times':[0,duration],'values':[value,value],'constant_from_gltf_node':True}
        out['clips'][name]={'duration':duration,'loop':name=='SpellIdle','tracks':list(tracks.values())}
        if name.startswith('FlameAttack'):
            out['clips'][name]['events']=[{'name':'release','time':.4,'hand':'R' if name=='FlameAttackRight' else 'L'}]
            out['clips'][name]['recovery_complete_time']=duration
    assert set(out['clips'])==set(clips)
    (BASE/'spell-animations.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
    print('SPELL_EXPORT '+json.dumps({'bytes':(BASE/'spell-animations.json').stat().st_size,'tracks':{n:len(c['tracks']) for n,c in out['clips'].items()}}),flush=True)

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene; scene.render.fps=30
    rig=bpy.data.objects['Foxfire_Rig']; mesh=bpy.data.objects['Foxfire_Mesh']; original=bpy.data.actions['Idle']
    original_signature=dual.curve_signature(original)
    dual.bind(rig,original); scene.frame_set(1); update()
    base={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones}
    clips,report=pose_frames(scene,rig,mesh,base,original)
    assert dual.curve_signature(original)==original_signature
    (BASE/'build-report.json').write_text(json.dumps({'mesh_rig_material_unchanged':True,
        'source_actions_unchanged':True,'root_horizontal_drift':0,'events':[
            {'clip':'FlameAttack','name':'release','time':.4,'hand':'L'},
            {'clip':'FlameAttackRight','name':'release','time':.4,'hand':'R'}],
        'clips':report},indent=2)+'\n')
    if '--build' in sys.argv: export(scene,rig,clips,report)
    if '--preview' in sys.argv or '--render' in sys.argv: render_gate(scene,rig,clips)

if __name__=='__main__': main()
