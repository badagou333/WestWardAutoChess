"""Retarget licensed Kenney Run rotations through its targeting/reference pose.

No procedural limb sine targets; preserve source shoulder, elbow, wrist twist,
leg timing, pelvic motion and torso counter-rotation. Tail is an added secondary.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

BASE=Path(__file__).resolve().parent
RIG=BASE.parent/'hunyuan_run_v1/foxfire-run.blend'
MOTION=BASE/'motion_source/kenney-run.fbx'
N,FPS=20,30
MAPPING={'pelvis':'Hips','spine':'Spine','chest':'UpperChest','neck':'Neck','head':'Head'}
for side,word in [('L','Left'),('R','Right')]:
    for target,source in [('clavicle','Shoulder'),('upper_arm','Arm'),('forearm','ForeArm'),('hand','Hand'),('thigh','UpLeg'),('shin','Leg'),('foot','Foot')]:
        MAPPING[target+'.'+side]=word+source

def update(): bpy.context.view_layer.update()

def bind_action(obj,action):
    obj.animation_data_create()
    obj.animation_data.action=action
    if action.slots:
        obj.animation_data.action_slot=action.slots[0]
    update()

def positions(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data=obj.to_mesh()
    points=[obj.matrix_world@v.co for v in data.vertices]
    obj.to_mesh_clear()
    return points

def aim(camera,location):
    camera.location=location
    camera.rotation_euler=(Vector((0,-.06,.55))-camera.location).to_track_quat('-Z','Y').to_euler()

def render(scene,full=False):
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.cycles.samples=8
    folder=BASE/('preview_frames' if full else 'drafts')
    folder.mkdir(exist_ok=True)
    indices=range(N) if full else [0,3,5,8,10,13,15,18]
    for name,location in [('front',(1.4,-3,1.2)),('side',(3,-.05,.95))]:
        aim(scene.camera,location)
        for i in indices:
            scene.frame_set(i+1)
            scene.render.filepath=str(folder/f'{name}-{i:03}.png')
            bpy.ops.render.render(write_still=True)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--render',action='store_true')
    p.add_argument('--render-full',action='store_true')
    p.add_argument('--preview-only',action='store_true')
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.preview_only:
        bpy.ops.wm.open_mainfile(filepath=str(BASE/'foxfire-run.blend'))
        render(bpy.context.scene,True)
        return
    bpy.ops.wm.open_mainfile(filepath=str(RIG))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene
    rig,mesh=bpy.data.objects['Foxfire_Rig'],bpy.data.objects['Foxfire_Mesh']
    rig.animation_data_clear()
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    for pb in rig.pose.bones:
        pb.location,pb.rotation_quaternion,pb.scale=(0,0,0),(1,0,0,0),(1,1,1)
    update()
    before=set(bpy.data.objects)
    scene.render.fps=24
    bpy.ops.import_scene.fbx(filepath=str(MOTION),use_anim=True)
    imported=set(bpy.data.objects)-before
    src=next(o for o in imported if o.type=='ARMATURE')
    reference=next(a for a in bpy.data.actions if 'Targeting' in a.name)
    action=next(a for a in bpy.data.actions if a.name.endswith('|Run'))
    bind_action(src,reference)
    scene.frame_set(int(reference.frame_range[0]))
    update()
    ref={name:src.matrix_world@src.pose.bones[name].matrix for name in MAPPING.values()}
    rest={name:rig.data.bones[name].matrix_local.copy() for name in MAPPING}
    # Uniform leg-length scaling handles different units without changing mesh scale.
    a=sum(rig.data.bones[n+'.L'].length for n in ['thigh','shin'])
    b=sum(src.pose.bones[n].length for n in ['LeftUpLeg','LeftLeg'])
    scale=a/b
    reference_hips=(src.matrix_world@src.pose.bones['Hips'].matrix).translation.copy()
    source_range=list(action.frame_range)
    bind_action(src,action)
    samples=[]
    source_contact=[]
    for i in range(N):
        f=source_range[0]+(source_range[1]-source_range[0])*i/N
        scene.frame_set(int(f),subframe=f-int(f))
        update()
        samples.append({name:src.matrix_world@src.pose.bones[name].matrix for name in ref})
        source_contact.append({side:(src.matrix_world@src.pose.bones[word+'Toes'].head).z for side,word in [('L','Left'),('R','Right')]})
    # Remove all source objects before creating/saving the candidate and its action.
    for obj in imported: bpy.data.objects.remove(obj,do_unlink=True)
    for ac in list(bpy.data.actions): bpy.data.actions.remove(ac)
    scene.render.fps=FPS
    scene.frame_start,scene.frame_end=1,N+1
    scene.timeline_markers.clear()
    soles={side:[v.index for v in mesh.data.vertices if v.co.z<.064 and sign*v.co.x>.06] for sign,side in [(1,'L'),(-1,'R')]}
    previous={}
    raw=[]
    for i in range(N+1):
        for pb in rig.pose.bones:
            pb.location,pb.rotation_quaternion,pb.scale=(0,0,0),(1,0,0,0),(1,1,1)
        sample=samples[i%N]
        root=(sample['Hips'].translation-reference_hips)*scale
        # Retain cyclic pelvis sway, no accumulated locomotion translation.
        rig.pose.bones['root'].location=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@root
        update()
        for target,source in MAPPING.items():
            pb=rig.pose.bones[target]
            reference_q=ref[source].to_quaternion()
            if target.startswith(('thigh.','shin.')):
                # The source "targeting pose" has flexed knees; ours is straight.
                # Calibrate that reference swing out while retaining its bone roll.
                ref_dir=reference_q@Vector((0,1,0))
                dst_dir=rest[target].to_quaternion()@Vector((0,1,0))
                reference_q=ref_dir.rotation_difference(dst_dir)@reference_q
            q=sample[source].to_quaternion()@reference_q.inverted()@rest[target].to_quaternion()
            pb.matrix=Matrix.Translation(pb.head)@q.to_matrix().to_4x4()
            update()
        phase=(i%N)/N
        for j in range(5):
            name=f'tail_{j+1:02}'
            qrest=rig.data.bones[name].matrix_local.to_quaternion()
            bend=Quaternion(qrest.inverted()@Vector((1,0,0)),math.radians((13 if j==0 else 1.5)+3*math.sin(4*math.pi*phase-j*.55)))
            sway=Quaternion(qrest.inverted()@Vector((0,0,1)),math.radians(3*math.sin(2*math.pi*phase-j*.6)))
            rig.pose.bones[name].rotation_quaternion=sway@bend
        update()
        pts=positions(mesh)
        raw.append({'frame':i+1,'foot_min':{s:min(pts[v].z for v in ids) for s,ids in soles.items()},'root':list(root)})
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name])<0: pb.rotation_quaternion.negate()
            previous[pb.name]=pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion',frame=i+1,group=pb.name)
            pb.keyframe_insert(data_path='location',frame=i+1,group=pb.name)
    run=rig.animation_data.action
    run.name='Foxfire_Run_Kenney_Retarget_v2'
    # Preserve source support/flight timing after adapting differently proportioned
    # legs. A constant offset only grounded one key and left stance frames floating.
    # Source toe height approximates the contact sole; its ~0.014-unit rest clearance
    # and a small tolerance are removed before scaling aerial clearance to our rig.
    # All limbs retain their captured rotations; only cyclic whole-body height changes.
    offsets=[]
    for i in range(N+1):
        scene.frame_set(i+1)
        clearance=max(0,min(source_contact[i%N].values())-.035)*scale
        offset=.003+clearance-min(raw[i]['foot_min'].values())
        offsets.append(offset)
        rig.pose.bones['root'].location += rig.data.bones['root'].matrix_local.to_quaternion().inverted()@Vector((0,0,offset))
        rig.pose.bones['root'].keyframe_insert(data_path='location',frame=i+1,group='root')
    for layer in run.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    rig.hide_set(False)
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(BASE/'foxfire-run.glb'),export_format='GLB',use_selection=True,export_animations=True,export_skins=True,export_all_influences=False,export_rest_position_armature=True,export_current_frame=False)
    scene.camera.data.ortho_scale=1.42
    aim(scene.camera,(1.4,-3,1.2))
    bpy.data.objects['PreviewGround'].location.z=0
    rig.show_in_front=True
    mesh.select_set(False)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    scene.frame_end=N
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'foxfire-run.blend'),compress=True)
    (BASE/'build-report.json').write_text(json.dumps({'date':'2026-10-13','source_motion':'Kenney Animated Characters Protagonists 1.1 / Animations/run.fbx','license':'CC0','motion_sha256':hashlib.sha256(MOTION.read_bytes()).hexdigest(),'method':'Complete rotation deltas relative to source targeting pose; source-contact-aware vertical root correction for proportion differences','source_range':source_range,'leg_scale':scale,'reference_hips':list(reference_hips),'ground_offsets':offsets,'source_toe_heights':source_contact,'fps':FPS,'unique_frames':N,'duration':N/FPS,'raw_foot_checks':raw},indent=2)+'\n')
    print('RETARGET_COMPLETE '+json.dumps({'scale':scale,'offset_range':[min(offsets),max(offsets)],'reference_hips':list(reference_hips)}),flush=True)
    if args.render_full: render(scene,True)
    elif args.render: render(scene,False)

if __name__=='__main__': main()
