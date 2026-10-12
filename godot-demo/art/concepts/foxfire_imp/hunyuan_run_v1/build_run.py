"""Bake an in-place run to the existing FK candidate. No source-model changes.

Analytical two-bone leg placement is baked to rotations, not an exported IK rig.
Run with Blender background --python build_run.py [-- --render].
"""
import argparse
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

BASE = Path(__file__).resolve().parent
SOURCE = BASE.parent / "hunyuan_rig_v1" / "foxfire-rigged.blend"
N, FPS, DUTY = 24, 30, .34


def refine_run_weights(mesh, rig):
    """Run-only correction; preserve topology/UV, use existing groups/modifier."""
    spec = importlib.util.spec_from_file_location('rig_fields', SOURCE.parent/'build_rig.py')
    fields = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fields)
    points, neighbors, mapping = fields.graph(mesh.data)
    core, region, inner, _ = fields.tail_region(points, neighbors)
    names = [g.name for g in mesh.vertex_groups]
    columns = {n:i for i,n in enumerate(names)}
    w = np.zeros((len(points),len(names)))
    tail_mask = np.zeros(len(points), dtype=bool)
    for i,p in enumerate(points):
        x,y,z = p
        ax, side = abs(x), 'L' if x >= 0 else 'R'
        head = fields.smooth(.691,.742,z)
        arm = fields.smooth(.11,.185,ax)*fields.smooth(.425,.505,z)*(1-head)
        leg = (1-fields.smooth(.315,.415,z))*(1-head)*(1-arm)
        # Keep crotch stabilization above the knee, not down on the inner shins.
        leg *= 1-(1-fields.smooth(.015,.065,ax))*fields.smooth(.28,.39,z)
        body = max(0.,1-head-arm-leg)
        result = {n:0. for n in names}
        result['head'] = head
        fields.blend(result, fields.along(z,[(.46,'pelvis'),(.535,'spine'),(.61,'chest'),(.703,'neck')]),body)
        fields.blend(result, fields.along(ax,[(.12,'clavicle.'+side),(.20,'upper_arm.'+side),(.34,'forearm.'+side),(.46,'hand.'+side)]),arm)
        left = fields.smooth(-.035,.035,x)
        for s,fraction in [('L',left),('R',1-left)]:
            fields.blend(result,fields.along(z,[(.07,'foot.'+s),(.13,'shin.'+s),(.29,'thigh.'+s),(.41,'pelvis')]),leg*fraction)
        amount = 1. if i in core or i in inner else (fields.smooth(.005,.065,y) if i in region else 0.)
        if amount:
            result = {k:v*(1-amount) for k,v in result.items()}
            fields.blend(result,fields.tail_weights(p),amount)
            tail_mask[i] = True
        for name,value in result.items():
            w[i,columns[name]] = value
    pairs = np.array([(i,j) for i,adj in enumerate(neighbors) for j in adj],dtype=np.int32)
    src,dst = pairs[:,0],pairs[:,1]
    degree = np.maximum(1,np.bincount(src,minlength=len(points)))
    for _ in range(3):
        avg = np.zeros_like(w)
        np.add.at(avg,src,w[dst])
        w = .8*w + .2*avg/degree[:,None]
    coords = np.array(points)
    metric = 1/np.maximum(1e-6,np.linalg.norm(coords[src]-coords[dst],axis=1))
    denom = np.bincount(src,weights=metric,minlength=len(points))
    mask = np.array([fields.smooth(.14,.19,p.z)*(1-fields.smooth(.40,.44,p.z))*(1-fields.smooth(.15,.22,abs(p.x))) for p in points])
    mask[tail_mask] = 0
    for _ in range(20):
        avg = np.zeros_like(w)
        np.add.at(avg,src,w[dst]*metric[:,None])
        avg /= np.maximum(1e-8,denom)[:,None]
        w += .5*mask[:,None]*(avg-w)
    keep = np.argsort(w,axis=1)[:,-4:]
    pruned = np.zeros_like(w)
    np.put_along_axis(pruned,keep,np.take_along_axis(w,keep,axis=1),axis=1)
    pruned[pruned<1e-5] = 0
    pruned /= pruned.sum(axis=1)[:,None]
    old = np.zeros((len(mapping),len(names)))
    for v in mesh.data.vertices:
        for g in v.groups:
            old[v.index,g.group] = g.weight
    # Protect the ORIGINAL weighted tail, including its partially body-weighted
    # border. A topology tail-core mask alone misses smoothing-spill vertices.
    old_unique = np.zeros_like(pruned)
    for vi,ui in enumerate(mapping):
        old_unique[ui] = old[vi]
    tail_columns = [columns[n] for n in names if n.startswith('tail_')]
    locked = old_unique[:,tail_columns].sum(axis=1) > 1e-5
    reached = locked.copy()
    strength = np.ones(len(points))
    strength[locked] = 0
    for ring in range(1,6):
        next_reached = reached.copy()
        next_reached[src[reached[dst]]] = True
        strength[next_reached & ~reached] = fields.smooth(0,5,ring)
        reached = next_reached
    pruned = old_unique + strength[:,None]*(pruned-old_unique)
    keep = np.argsort(pruned,axis=1)[:,-4:]
    filtered = np.zeros_like(pruned)
    np.put_along_axis(filtered,keep,np.take_along_axis(pruned,keep,axis=1),axis=1)
    pruned = filtered/filtered.sum(axis=1)[:,None]
    indices = list(range(len(mapping)))
    for group in mesh.vertex_groups:
        group.remove(indices)
    for vi,ui in enumerate(mapping):
        for column in np.flatnonzero(pruned[ui]):
            mesh.vertex_groups[names[column]].add([vi],float(pruned[ui,column]),'REPLACE')
    update()
    return {'method':'Raised central pelvis stabilization from Z .16-.27 to .28-.39; 20 inverse-edge-length local smoothing iterations, strength .5; tail excluded; top 4 normalized',
            'source_rig_unchanged':True,'topology_unchanged':True,'max_weight_delta':float(np.max(np.abs(pruned[mapping]-old))),
            'modified_vertices_over_1e_4':int(np.count_nonzero(np.max(np.abs(pruned[mapping]-old),axis=1)>1e-4)),
            'original_tail_weighted_vertex_max_delta':float(np.max(np.abs(pruned[locked]-old_unique[locked]))),
            'armature_modifier_count':sum(m.type=='ARMATURE' for m in mesh.modifiers)}


def update():
    bpy.context.view_layer.update()


def local_rotation(rig, name, axis, degrees):
    axis = rig.data.bones[name].matrix_local.to_quaternion().inverted() @ Vector(axis)
    rig.pose.bones[name].rotation_quaternion = Quaternion(axis, math.radians(degrees))


def direction(rig, name, target):
    """Aim a bone in armature space, maintaining rest roll and its current head."""
    pb, rest = rig.pose.bones[name], rig.data.bones[name]
    head = pb.head.copy()
    rotation = (rest.tail_local - rest.head_local).rotation_difference(Vector(target)) @ rest.matrix_local.to_quaternion()
    pb.matrix = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
    update()


def evaluated(mesh):
    obj = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = obj.to_mesh()
    result = [obj.matrix_world @ v.co for v in data.vertices]
    obj.to_mesh_clear()
    return result


def place_leg(rig, side, ankle, pitch):
    thigh, shin = rig.pose.bones['thigh.' + side], rig.pose.bones['shin.' + side]
    hip = thigh.head.copy()
    delta = ankle - hip
    distance = delta.length
    a, b = thigh.length, shin.length
    if not abs(a - b) + .0001 < distance < a + b - .0001:
        raise ValueError(f"Unreachable foot {side}: {distance} vs {a + b}")
    forward = delta.normalized()
    pole = Vector((0, -1, 0))
    pole = (pole - forward * pole.dot(forward)).normalized()
    along = (a * a - b * b + distance * distance) / (2 * distance)
    knee = hip + forward * along + pole * math.sqrt(max(0, a * a - along * along))
    direction(rig, 'thigh.' + side, knee - hip)
    direction(rig, 'shin.' + side, ankle - rig.pose.bones['shin.' + side].head)
    rest = rig.data.bones['foot.' + side]
    foot_vector = Quaternion(Vector((1, 0, 0)), math.radians(pitch)) @ (rest.tail_local - rest.head_local)
    direction(rig, 'foot.' + side, foot_vector)
    return (rig.pose.bones['foot.' + side].head - ankle).length


def hermite(a, b, da, db, u):
    return (2*u**3-3*u*u+1)*a + (u**3-2*u*u+u)*da + (-2*u**3+3*u*u)*b + (u**3-u*u)*db


def foot_path(p):
    if p < DUTY:
        u = p / DUTY
        return -.226 + .22*u, .071, -8 + 28*u*u, True
    u = (p - DUTY) / (1 - DUTY)
    tangent = .22 / DUTY * (1 - DUTY)
    y = -.116 + hermite(.11, -.11, tangent, tangent, u)
    z = .071 + .115 * math.sin(math.pi*u)**1.5
    pitch = 20 * (1-u) - 8*u + 13*math.sin(math.pi*u)
    return y, z, pitch, False


def pose(rig, mesh, phase, soles):
    for pb in rig.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    bob = -.053 + .033 * (1 - math.cos(4*math.pi*(phase-.17))) / 2
    rig.pose.bones['root'].location = rig.data.bones['root'].matrix_local.to_quaternion().inverted() @ Vector((0, 0, bob))
    local_rotation(rig, 'pelvis', (1, 0, 0), 6)
    local_rotation(rig, 'spine', (1, 0, 0), 6)
    local_rotation(rig, 'chest', (0, 0, 1), 3*math.sin(2*math.pi*phase))
    local_rotation(rig, 'head', (1, 0, 0), -8)
    update()
    contacts, targets, errors = {}, {}, {}
    for sign, side, offset in ((1, 'L', 0), (-1, 'R', .5)):
        p = (phase + offset) % 1
        y, z, pitch, stance = foot_path(p)
        ankle = Vector((sign*.108, y, z))
        # Correct actual visible sole height, not merely the ankle joint.
        for _ in range(3):
            errors[side] = place_leg(rig, side, ankle, pitch)
            points = evaluated(mesh)
            bottom = min(points[i].z for i in soles[side])
            desired = .002 if stance else .002 + .10*math.sin(math.pi*(p-DUTY)/(1-DUTY))**1.5
            ankle.z += desired - bottom
        errors[side] = place_leg(rig, side, ankle, pitch)
        contacts[side], targets[side] = stance, list(ankle)
        swing = math.cos(2*math.pi*p)
        direction(rig, 'upper_arm.' + side, Vector((sign*.040, -.025 + .080*swing, -.132)))
        forearm = Vector((sign*.016, -.060 - .050*swing, .040 - .070*swing))
        direction(rig, 'forearm.' + side, forearm)
        direction(rig, 'hand.' + side, forearm)
    for i in range(5):
        name = f'tail_{i+1:02}'
        rest = rig.data.bones[name].matrix_local.to_quaternion()
        bend = Quaternion(rest.inverted() @ Vector((1, 0, 0)), math.radians((12 if i == 0 else 2) + 2*math.sin(4*math.pi*phase-i*.45)))
        sway = Quaternion(rest.inverted() @ Vector((0, 0, 1)), math.radians(4*math.sin(2*math.pi*phase-i*.55)))
        rig.pose.bones[name].rotation_quaternion = sway @ bend
    update()
    return {'phase': phase, 'stance': contacts, 'ankle_targets': targets, 'ik_bake_error': errors}


def aim(camera, location):
    camera.location = location
    camera.rotation_euler = (Vector((0, -.03, .57)) - camera.location).to_track_quat('-Z', 'Y').to_euler()


def render_current():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    scene, camera = bpy.context.scene, bpy.context.scene.camera
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.cycles.samples = 8
    output = BASE/'preview_frames'
    output.mkdir(exist_ok=True)
    for view, location in [('front', (1.8,-3,1.5)), ('side', (3,-.15,1.1))]:
        aim(camera, location)
        for i in range(N):
            scene.frame_set(i+1)
            scene.render.filepath = str(output/f'{view}-{i:03}.png')
            bpy.ops.render.render(write_still=True)
        print('VIEW_COMPLETE '+view, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--preview-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.preview_only:
        bpy.ops.wm.open_mainfile(filepath=str(BASE/'foxfire-run.blend'))
        render_current()
        return
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.preferences.filepaths.save_version = 0
    rig, mesh, scene = bpy.data.objects['Foxfire_Rig'], bpy.data.objects['Foxfire_Mesh'], bpy.context.scene
    rig.animation_data_clear()
    weight_report = refine_run_weights(mesh, rig)
    # Old test remains in the separate v1 file; this file exports only Run.
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    scene.timeline_markers.clear()
    scene.frame_start, scene.frame_end, scene.render.fps = 1, N+1, FPS
    soles = {side: [v.index for v in mesh.data.vertices if v.co.z < .064 and sign*v.co.x > .06]
             for sign, side in ((1, 'L'), (-1, 'R'))}
    keys, previous = [], {}
    for i in range(N+1):
        scene.frame_set(i+1)
        row = pose(rig, mesh, (i % N) / N, soles)
        row['frame'] = i+1
        keys.append(row)
        for pb in rig.pose.bones:
            if pb.name in previous and pb.rotation_quaternion.dot(previous[pb.name]) < 0:
                pb.rotation_quaternion.negate()
            previous[pb.name] = pb.rotation_quaternion.copy()
            pb.keyframe_insert(data_path='rotation_quaternion', frame=i+1, group=pb.name)
            pb.keyframe_insert(data_path='location', frame=i+1, group=pb.name)
    action = rig.animation_data.action
    action.name = 'Foxfire_Run_InPlace_v1'
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    for frame, label in ((1, 'Left contact'), (5, 'Left support'), (10, 'Flight'), (13, 'Right contact'), (22, 'Flight'), (25, 'Loop endpoint')):
        scene.timeline_markers.new(label, frame=frame)
    metrics, first, last = [], None, None
    for i in range(2*N+1):
        f = 1 + i/2
        scene.frame_set(int(f), subframe=f-int(f))
        points = evaluated(mesh)
        row = {'frame': f, 'sole_min_z': {s: min(points[j].z for j in ids) for s, ids in soles.items()},
               'all_mesh_min_z': min(p.z for p in points), 'finite': all(math.isfinite(c) for p in points for c in p)}
        metrics.append(row)
        if i == 0: first = points
        if i == 2*N: last = points
    loop_error = max((a-b).length for a,b in zip(first,last))
    assert loop_error < 1e-5 and all(r['finite'] for r in metrics)
    scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    rig.hide_set(False)
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(BASE/'foxfire-run.glb'), export_format='GLB', use_selection=True,
                              export_animations=True, export_skins=True, export_all_influences=False,
                              export_rest_position_armature=True, export_current_frame=False)
    camera = scene.camera
    bpy.data.objects['PreviewGround'].location.z = 0
    camera.data.ortho_scale = 1.42
    aim(camera, (1.8, -3.0, 1.5))
    rig.show_in_front = True
    rig['README'] = 'Run in place: Space to play. Pose mode; overlay and In Front enabled. 30 fps, frames 1-24; frame 25 duplicates 1. Not game integrated.'
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                space = area.spaces.active
                space.overlay.show_overlays = True
                space.shading.type = 'MATERIAL'
                space.region_3d.view_distance = 2.0
                space.region_3d.view_location = (0, -.03, .57)
                space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
    mesh.select_set(False)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.file.pack_all()
    # Interactive playback excludes the duplicate endpoint; glb above includes it.
    scene.frame_end = N
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'foxfire-run.blend'), compress=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    report = {'date': '2026-10-13', 'source_sha256': source_hash, 'source': '../hunyuan_rig_v1/foxfire-rigged.blend',
              'action': action.name, 'fps': FPS, 'unique_frames': N, 'endpoint_frame': N+1, 'duration_seconds': N/FPS,
              'mode': 'in-place; analytic leg placement baked to FK rotations, not live IK',
              'bones': len(rig.data.bones), 'loop_vertex_error': loop_error, 'keyframes': keys, 'half_frame_mesh_checks': metrics,
              'original_geometry_uv_material_unchanged': True, 'run_only_weight_refinement': weight_report,
              'limitations': ['Candidate only, no game integration', 'Wide sleeves/robe are skinned with existing approximate weights, no cloth simulation',
                              'No finger or facial animation; no IK control handles; no complete collision certification']}
    (BASE/'run-report.json').write_text(json.dumps(report, indent=2)+'\n')
    assert source_hash == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    print('RUN_BUILD_COMPLETE '+json.dumps({'loop_error':loop_error, 'min_sole_z': min(min(r['sole_min_z'].values()) for r in metrics),
                                           'max_both_feet_clearance': max(min(r['sole_min_z'].values()) for r in metrics)}), flush=True)
    if args.render:
        render_current()


if __name__ == '__main__':
    main()
