"""Contact-corrected short-stride fire-carry jog, on the unchanged fox rig.

Retain restrained Kenney torso/tail motion; re-author the feet for this short
legged model using explicit stance speed and two-bone IK. No mesh duplication.
Blender --background --python build_locomotion.py -- --render (optional).
"""
import hashlib, importlib.util, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

BASE=Path(__file__).resolve().parent
SOURCE=BASE.parent/'hunyuan_board_actor_v1/foxfire-board-actor.blend'
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('dual',BASE.parent/'hunyuan_dual_fire_v1/build_dual_fire.py')
dual=importlib.util.module_from_spec(spec);spec.loader.exec_module(dual)
N,FPS,DURATION,STRIDE,STANCE=72,120,.6,.8,.4
TEMP=Path('/private/tmp/foxfire-locomotion-actions.glb')
def update(): bpy.context.view_layer.update()
def restore(rig, matrices):
    for n,m in matrices.items(): rig.pose.bones[n].matrix_basis=m.copy()
    update()
def world_rotate(rig,name,axis,angle):
    b=rig.pose.bones[name]
    q=Quaternion(Vector(axis),math.radians(angle))@b.matrix.to_quaternion()
    b.matrix=Matrix.Translation(b.head)@q.to_matrix().to_4x4();update()
def aim_bone(rig,name,direction):
    # Preserve calibrated rest roll instead of applying an arbitrary IK roll.
    pb=rig.pose.bones[name]; rest=rig.data.bones[name].matrix_local.to_quaternion()
    q=(rest@Vector((0,1,0))).rotation_difference(direction.normalized())@rest
    pb.matrix=Matrix.Translation(pb.head)@q.to_matrix().to_4x4();update()
def foot_path(p):
    if p<=STANCE:
        return -.5*STRIDE*STANCE+STRIDE*p,0.,0.
    u=(p-STANCE)/(1-STANCE)
    a=.5*STRIDE*STANCE;b=-a;m=STRIDE*(1-STANCE)
    y=(2*u**3-3*u*u+1)*a+(u**3-2*u*u+u)*m+(-2*u**3+3*u*u)*b+(u**3-u*u)*m
    lift=.085*math.sin(math.pi*u)**2
    pitch=14*math.sin(2*math.pi*u)*math.sin(math.pi*u)
    return y,lift,pitch
def leg(rig,side,target,foot_q):
    a=rig.pose.bones['thigh.'+side]; sign=1 if side=='L' else -1
    knee,ankle=dual.solve_elbow(a.head,target,Vector((sign*.10,-.55,.22)),a.length,rig.pose.bones['shin.'+side].length)
    aim_bone(rig,'thigh.'+side,knee-a.head)
    aim_bone(rig,'shin.'+side,ankle-rig.pose.bones['shin.'+side].head)
    pb=rig.pose.bones['foot.'+side]
    pb.matrix=Matrix.Translation(pb.head)@foot_q.to_matrix().to_4x4();update()
    return (ankle-target).length
def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    scene=bpy.context.scene;rig=bpy.data.objects['Foxfire_Rig'];mesh=bpy.data.objects['Foxfire_Mesh']
    original={n:bpy.data.actions[n] for n in ('Idle','Run')}
    signatures={n:dual.curve_signature(a) for n,a in original.items()}
    dual.bind(rig,original['Idle']);scene.frame_set(1);update()
    base={b.name:b.matrix_basis.copy() for b in rig.pose.bones}
    feet={s:rig.data.bones['foot.'+s].matrix_local.to_quaternion() for s in ('L','R')}
    # Sole landmarks are selected once from the original rest mesh, never changed
    # by the candidate. These same vertices measure old and new animation.
    soles={s:[v.index for v in mesh.data.vertices if v.co.z<.048 and sign*v.co.x>.045 and v.co.y<-.06] for s,sign in [('L',1),('R',-1)]}
    refs={s:min(ids,key=lambda i:mesh.data.vertices[i].co.z) for s,ids in soles.items()}
    sole_probes={}
    for side,ids in soles.items():
        group=mesh.vertex_groups['foot.'+side].index
        full=[j for j in ids if any(g.group==group and g.weight>.99999 for g in mesh.data.vertices[j].groups)]
        assert full,'Need rigid sole landmarks for runtime grounding'
        # Extreme sole points across a wider tilt range than this clip. Keep
        # only their convex support subset rather than skinning the whole foot
        # every frame. Independent QA verifies against ALL original vertices.
        chosen={min(full,key=lambda j:mesh.data.vertices[j].co.dot(Vector((a/10,b/10,1))))
                for a in range(-8,9,2) for b in range(-8,9,2)}
        inv=rig.data.bones['foot.'+side].matrix_local.inverted()
        sole_probes[side]=[list(inv@mesh.data.vertices[j].co) for j in sorted(chosen)]
    src=[];baseline=[]
    dual.bind(rig,original['Run'])
    for i in range(N+1):
        f=1+(i%N)/N*20;scene.frame_set(int(f),subframe=f-int(f));update()
        src.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
        pts=dual.points(mesh)
        baseline.append({'phase':i/N,'hip_z':rig.pose.bones['pelvis'].head.z,
            'feet':{s:{'min_z':min(pts[j].z for j in ids),'landmark':list(pts[refs[s]])} for s,ids in soles.items()}})
    action=original['Idle'].copy();action.name='NaturalRun'
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in list(bag.fcurves): bag.fcurves.remove(fc)
    dual.bind(rig,action);scene.render.fps=FPS;scene.frame_start=1;scene.frame_end=N+1
    rows=[];previous={};max_reach_error=0
    for i in range(N+1):
        scene.frame_set(i+1);restore(rig,base);phase=(i%N)/N;wave=2*math.pi*phase
        # Retain a modest version of the reference torso counter-rotation; the
        # large old vertical correction (about 6 cm) is not reused.
        for name in ['pelvis','spine','chest','neck','head']+[f'tail_{j:02}' for j in range(1,6)]:
            rig.pose.bones[name].rotation_quaternion=base[name].to_quaternion().slerp(src[i][name].to_quaternion(),.45)
        update()
        hip=rig.pose.bones['pelvis'].head.copy()
        desired=Vector((.0035*math.sin(wave),-.115,.325+.009*math.cos(2*wave)))
        rig.pose.bones['root'].location+=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@(desired-hip)
        update();world_rotate(rig,'spine',(1,0,0),3.0)
        world_rotate(rig,'chest',(0,0,1),2.3*math.sin(wave))
        world_rotate(rig,'head',(0,0,1),-1.4*math.sin(wave))
        # Lowering the gait cannot leave the old tail curve cutting the board.
        # Lift at its base only; preserve the approved body/idle/attack assets.
        world_rotate(rig,'tail_01',(1,0,0),12.0)
        contacts={};targets={};quats={}
        for side,sign in [('L',1),('R',-1)]:
            p=(phase+(0 if side=='L' else .5))%1
            y,lift,pitch=foot_path(p);contacts[side]=p<=STANCE
            target=Vector((sign*.087,-.115+y,.073+lift))
            q=Quaternion(Vector((1,0,0)),math.radians(pitch))@feet[side]
            # Correct the actual deformed sole, not just a bone-tip proxy.
            for repeat in range(3):
                max_reach_error=max(max_reach_error,leg(rig,side,target,q))
                pts=dual.points(mesh)
                target.z+=.003+lift-min(pts[j].z for j in soles[side])
            leg(rig,side,target,q);targets[side]=list(target);quats[side]=q
        dual.dual_pose(rig,wave,True)
        # A small opposite shoulder response, while keeping the two fires apart.
        pts=dual.points(mesh)
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name])<0:pb.rotation_quaternion.negate()
            previous[pb.name]=pb.rotation_quaternion.copy()
            for prop in ['rotation_quaternion','location','scale']:pb.keyframe_insert(data_path=prop,frame=i+1,group=pb.name)
        if i==0:first=pts
        rows.append({'phase':i/N,'hip_z':rig.pose.bones['pelvis'].head.z,'mesh_min_z':min(p.z for p in pts),
            'feet':{s:{'stance':contacts[s],'min_z':min(pts[j].z for j in ids),'landmark':list(pts[refs[s]])} for s,ids in soles.items()}})
    for fc in dual.fcurves(action):
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    loop_error=max((a-b).length for a,b in zip(first,pts))
    assert loop_error<1e-5,loop_error
    assert max_reach_error<.002,max_reach_error
    assert min(row['mesh_min_z'] for row in rows)>.001, 'Candidate mesh cuts floor'
    assert all(dual.curve_signature(a)==signatures[n] for n,a in original.items())
    def metrics(samples,stride):
        speeds=[];heights=[]
        for a,b in zip(samples,samples[1:]):
            for s in ('L','R'):
                x,y=a['feet'][s],b['feet'][s]
                if x['min_z']<.008 and y['min_z']<.008:
                    # In-place Blender runs toward -Y. Add world travel before
                    # calculating drift, normalized per cycle for the old clip.
                    d=Vector(y['landmark'])-Vector(x['landmark']);d.y-=stride/N
                    speeds.append(d.xy.length*N/stride)
                heights.append(x['min_z'])
        return {'hip_z_range':max(r['hip_z'] for r in samples)-min(r['hip_z'] for r in samples),
            'sole_min_z':min(heights),'maximum_sole_lift':max(heights),
            'stance_samples':len(speeds),'mean_stance_slip_fraction_of_travel_speed':sum(speeds)/len(speeds) if speeds else None,
            'maximum_stance_slip_fraction':max(speeds) if speeds else None}
    report={'source_mesh_weights_materials_unchanged':True,'source_actions_unchanged':True,'loop_mesh_error':loop_error,
        'maximum_ik_reach_error':max_reach_error,'duration':DURATION,'stride_model_units':STRIDE,'stance_fraction':STANCE,
        'new':metrics(rows,STRIDE),'old_at_previous_runtime_speed':metrics(baseline,2.35*(2/3)/.65/1.65),
        'sole_landmarks':refs,'samples':rows}
    (BASE/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
    dual.bind(rig,action);scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(TEMP),export_format='GLB',use_selection=True,export_animations=True,
        export_animation_mode='ACTIONS',export_skins=True,export_rest_position_armature=True,export_current_frame=False)
    doc,blob=dual.read_gltf(TEMP);bones=[b.name for b in rig.data.bones];nodes={n['name']:n for n in doc['nodes'] if n.get('name') in bones};tracks={}
    for animation in doc['animations']:
        if animation['name']!='NaturalRun':continue
        for channel in animation['channels']:
            target=channel['target'];bone=doc['nodes'][target['node']]['name']
            if bone not in bones:continue
            sampler=animation['samplers'][channel['sampler']]
            times=[max(0,min(DURATION,v-1/FPS)) for v in dual.read_accessor(doc,blob,sampler['input'])]
            tracks[(bone,target['path'])]={'bone':bone,'path':target['path'],'times':times,'values':dual.read_accessor(doc,blob,sampler['output'])}
    for bone in bones:
        for path,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]:
            if (bone,path) not in tracks:
                value=nodes[bone].get(path,default);tracks[(bone,path)]={'bone':bone,'path':path,'times':[0,DURATION],'values':[value,value]}
    output={'schema':1,'space':'glTF absolute parent-node local TRS','base_glb_sha256':hashlib.sha256(SOURCE.with_suffix('.glb').read_bytes()).hexdigest(),
        'source_blend_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'duration':DURATION,'stride_model_units':STRIDE,
        'nominal_model_speed':STRIDE/DURATION,'stance_fraction':STANCE,'sole_probes':sole_probes,
        'clips':{'NaturalRun':{'duration':DURATION,'tracks':list(tracks.values())}}}
    (BASE/'locomotion-animations.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
    print('LOCOMOTION '+json.dumps({k:v for k,v in report.items() if k!='samples'}),flush=True)
    if '--save-preview' in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath='/private/tmp/foxfire-locomotion-preview.blend',compress=True)
    if '--render' in sys.argv:
        orbs=dual.make_orbs();scene.cycles.samples=8;scene.render.resolution_x=scene.render.resolution_y=480;scene.camera.data.ortho_scale=1.25
        for view,loc in [('side',(3,-.05,.88)),('front',(.1,-3,1.05))]:
            scene.camera.location=loc;scene.camera.rotation_euler=(Vector((0,-.08,.48))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
            for i in [0,9,18,27,36,45,54,63]:
                scene.frame_set(i+1);update();dual.place_orbs(rig,orbs)
                scene.render.filepath=str(BASE/f'gate-{view}-{i:03}.png');bpy.ops.render.render(write_still=True)
if __name__=='__main__':main()
