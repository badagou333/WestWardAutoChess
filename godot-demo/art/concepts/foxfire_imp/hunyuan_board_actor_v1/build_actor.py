"""Independent Idle + unchanged Run actor for the shared 3D board trial."""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

BASE=Path(__file__).resolve().parent
SOURCE=BASE.parent/'hunyuan_run_v2/foxfire-run.blend'
MOTION=BASE/'motion_source/idle.fbx'
N,FPS=90,30
MAP={'pelvis':'Hips','spine':'Spine','chest':'UpperChest','neck':'Neck','head':'Head'}
for side,word in [('L','Left'),('R','Right')]:
    for dst,src in [('clavicle','Shoulder'),('upper_arm','Arm'),('forearm','ForeArm'),('hand','Hand'),('thigh','UpLeg'),('shin','Leg'),('foot','Foot')]:
        MAP[dst+'.'+side]=word+src

def update(): bpy.context.view_layer.update()
def bind(obj,action):
    obj.animation_data_create()
    obj.animation_data.action=action
    if action.slots: obj.animation_data.action_slot=action.slots[0]
    update()
def points(mesh):
    obj=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data=obj.to_mesh()
    result=[obj.matrix_world@v.co for v in data.vertices]
    obj.to_mesh_clear()
    return result
def curve_values(action):
    return [(f.data_path,f.array_index,[(list(k.co),k.interpolation) for k in f.keyframe_points])
            for layer in action.layers for strip in layer.strips for bag in strip.channelbags for f in bag.fcurves]
def render(scene):
    folder=BASE/'drafts'; folder.mkdir(exist_ok=True)
    scene.render.resolution_x=scene.render.resolution_y=560
    scene.cycles.samples=16
    scene.camera.data.ortho_scale=1.36
    for view,loc in [('front',(1.1,-3,1.4)),('side',(3,-.06,1.2)),('board',(2.4,-3,3.1))]:
        scene.camera.location=loc
        scene.camera.rotation_euler=(Vector((0,-.04,.51))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        for frame in [1,23,46,68]:
            scene.frame_set(frame)
            scene.render.filepath=str(folder/f'{view}-{frame:03}.png')
            bpy.ops.render.render(write_still=True)

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene
    rig,mesh=bpy.data.objects['Foxfire_Rig'],bpy.data.objects['Foxfire_Mesh']
    run=rig.animation_data.action
    before_run=curve_values(run)
    run.name='Run'; run.use_fake_user=True
    rig.animation_data_clear()
    for pb in rig.pose.bones:
        pb.location,pb.rotation_quaternion,pb.scale=(0,0,0),(1,0,0,0),(1,1,1)
    update()
    before=set(bpy.data.objects)
    scene.render.fps=24
    bpy.ops.import_scene.fbx(filepath=str(MOTION),use_anim=True)
    imported=set(bpy.data.objects)-before
    src=next(o for o in imported if o.type=='ARMATURE')
    refact=next(a for a in bpy.data.actions if 'Targeting' in a.name)
    srcact=next(a for a in bpy.data.actions if a!=run and a!=refact)
    bind(src,refact); scene.frame_set(int(refact.frame_range[0])); update()
    reference={n:src.matrix_world@src.pose.bones[n].matrix for n in MAP.values()}
    rest={n:rig.data.bones[n].matrix_local.copy() for n in MAP}
    refhips=reference['Hips'].translation.copy()
    scale=sum(rig.data.bones[n+'.L'].length for n in ['thigh','shin'])/sum(src.pose.bones[n].length for n in ['LeftUpLeg','LeftLeg'])
    source_range=list(srcact.frame_range)
    bind(src,srcact)
    samples=[]
    for i in range(N):
        frame=source_range[0]+(source_range[1]-source_range[0])*i/N
        scene.frame_set(int(frame),subframe=frame-int(frame)); update()
        samples.append({n:src.matrix_world@src.pose.bones[n].matrix for n in reference})
    for obj in imported: bpy.data.objects.remove(obj,do_unlink=True)
    for action in list(bpy.data.actions):
        if action!=run: bpy.data.actions.remove(action)
    scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=N+1
    soles={s:[v.index for v in mesh.data.vertices if v.co.z<.064 and sign*v.co.x>.06] for sign,s in [(1,'L'),(-1,'R')]}
    previous={}; checks=[]
    for i in range(N+1):
        for pb in rig.pose.bones:
            pb.location,pb.rotation_quaternion,pb.scale=(0,0,0),(1,0,0,0),(1,1,1)
        sample=samples[i%N]
        root=(sample['Hips'].translation-refhips)*scale
        rig.pose.bones['root'].location=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@root
        update()
        for target,source in MAP.items():
            reference_q=reference[source].to_quaternion()
            if target.startswith(('thigh.','shin.')):
                direction=reference_q@Vector((0,1,0))
                reference_q=direction.rotation_difference(rest[target].to_quaternion()@Vector((0,1,0)))@reference_q
            pb=rig.pose.bones[target]
            rotation=sample[source].to_quaternion()@reference_q.inverted()@rest[target].to_quaternion()
            pb.matrix=Matrix.Translation(pb.head)@rotation.to_matrix().to_4x4(); update()
        phase=(i%N)/N
        for j in range(5):
            name=f'tail_{j+1:02}'; qrest=rig.data.bones[name].matrix_local.to_quaternion()
            bend=Quaternion(qrest.inverted()@Vector((1,0,0)),math.radians((14 if j==0 else 1)+.8*math.sin(2*math.pi*phase-j*.45)))
            sway=Quaternion(qrest.inverted()@Vector((0,0,1)),math.radians(1.6*math.sin(2*math.pi*phase-j*.45)))
            rig.pose.bones[name].rotation_quaternion=sway@bend
        update()
        pts=points(mesh)
        foot_min={s:min(pts[v].z for v in ids) for s,ids in soles.items()}
        shift=.002-min(foot_min.values())
        rig.pose.bones['root'].location+=rig.data.bones['root'].matrix_local.to_quaternion().inverted()@Vector((0,0,shift))
        update(); pts=points(mesh)
        checks.append({'frame':i+1,'sole_min':{s:min(pts[v].z for v in ids) for s,ids in soles.items()},'root':list(rig.pose.bones['root'].location)})
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name])<0: pb.rotation_quaternion.negate()
            previous[pb.name]=pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion',frame=i+1,group=pb.name)
            pb.keyframe_insert(data_path='location',frame=i+1,group=pb.name)
    idle=rig.animation_data.action; idle.name='Idle'; idle.use_fake_user=True
    for layer in idle.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    assert before_run==curve_values(run),'Run action must remain exact'
    scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(BASE/'foxfire-board-actor.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_all_influences=False,export_rest_position_armature=True,export_current_frame=False)
    rig.show_in_front=False
    scene.frame_end=N
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'foxfire-board-actor.blend'),compress=True)
    report={'date':'2026-10-13','source_blend':str(SOURCE.relative_to(BASE.parent)), 'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'idle_motion':'Kenney Animated Characters Protagonists 1.1 idle.fbx / CC0','idle_motion_sha256':hashlib.sha256(MOTION.read_bytes()).hexdigest(),'source_idle_range':source_range,'run_curves_exact':before_run==curve_values(run),'animations':{'Idle':{'duration':N/FPS,'unique_frames':N},'Run':{'duration':2/3,'unique_frames':20}},'bones':len(rig.data.bones),'geometry_changed':False,'textures_changed':False,'idle_foot_checks':checks}
    (BASE/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ACTOR_BUILD_COMPLETE '+json.dumps({k:report[k] for k in ['source_idle_range','run_curves_exact','animations','bones']}),flush=True)
    if '--render' in args: render(scene)

if __name__=='__main__': main()
