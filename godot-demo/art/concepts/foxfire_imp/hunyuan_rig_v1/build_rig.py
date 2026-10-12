"""Local FK rig candidate. Preserve source mesh/UV/materials; no heat-weight claim.

Run with Blender --background --factory-startup --disable-autoexec --python-exit-code 1
--python build_rig.py. All model coordinates below use the imported Blender world.
"""
import argparse
import hashlib
import json
import math
import sys
from collections import defaultdict, deque
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

BASE = Path(__file__).resolve().parent
SOURCE = BASE.parent / "hunyuan_model_review_v1" / "source.glb"
EXPECTED_SHA = "0bef120b2d008b67d57df7bbe5317fec8da1e1a07c860533eb9eb838daf0a425"
TAIL = [(0, .005, .420), (0, .130, .405), (0, .235, .320),
        (0, .260, .205), (0, .235, .095), (0, .190, .022)]


def smooth(a, b, x):
    t = max(0., min(1., (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def blend(result, values, amount):
    for name, weight in values.items():
        result[name] += amount * weight


def along(value, stops):
    if value <= stops[0][0]:
        return {stops[0][1]: 1.}
    for (a, name_a), (b, name_b) in zip(stops, stops[1:]):
        if value <= b:
            t = smooth(a, b, value)
            return {name_a: 1 - t, name_b: t}
    return {stops[-1][1]: 1.}


def graph(mesh):
    lookup, positions, original_to_unique = {}, [], []
    for v in mesh.vertices:
        key = tuple(round(float(c), 6) for c in v.co)
        if key not in lookup:
            lookup[key] = len(positions)
            positions.append(v.co.copy())
        original_to_unique.append(lookup[key])
    neighbors = [set() for _ in positions]
    for edge in mesh.edges:
        a, b = (original_to_unique[i] for i in edge.vertices)
        if a != b:
            neighbors[a].add(b)
            neighbors[b].add(a)
    return positions, neighbors, original_to_unique


def flood(seed, allowed, neighbors):
    found, queue = {seed}, deque([seed])
    while queue:
        for other in neighbors[queue.popleft()]:
            if other not in found and other in allowed:
                found.add(other)
                queue.append(other)
    return found


def tail_region(points, neighbors):
    allowed = {i for i, p in enumerate(points) if p.y > .06 and p.z < .50}
    seed = min(allowed, key=lambda i: (points[i] - Vector((0, .35, .30))).length_squared)
    core = flood(seed, allowed, neighbors)
    # Extend the connected tail toward its root, including small pale fur islands.
    # Texture-assisted audit distinguished these from the lower red scarf ends.
    root_allowed = {i for i, p in enumerate(points) if p.y > -.01 and p.z < .49}
    region = flood(seed, root_allowed | core, neighbors)
    # Preserve the small closed interior island and follow the tail, never delete it.
    remaining, components = set(range(len(points))), []
    while remaining:
        part = flood(next(iter(remaining)), remaining, neighbors)
        components.append(part)
        remaining.difference_update(part)
    inner = set()
    for part in components:
        if len(part) < 500 and all(points[i].y > .12 and points[i].z < .42 for i in part):
            inner |= part
    return core, region, inner, sorted([len(c) for c in components], reverse=True)


def tail_weights(p):
    nearest = None
    distance_along, lengths = 0., []
    for i in range(5):
        a, b = Vector(TAIL[i]), Vector(TAIL[i + 1])
        length = (b - a).length
        t = max(0., min(1., (p - a).dot(b - a) / length ** 2))
        distance = (p - (a + (b - a) * t)).length_squared
        candidate = (distance, distance_along + t * length)
        if nearest is None or candidate[0] < nearest[0]:
            nearest = candidate
        lengths.append(length)
        distance_along += length
    total = 0.
    stops = []
    for i, length in enumerate(lengths):
        stops.append((total + .5 * length, f"tail_{i + 1:02}"))
        total += length
    return along(nearest[1], stops)


def body_weights(p):
    x, y, z = p
    side = "L" if x >= 0 else "R"
    ax = abs(x)
    head = smooth(.691, .742, z)
    arm = smooth(.11, .185, ax) * smooth(.425, .505, z) * (1 - head)
    leg = (1 - smooth(.315, .415, z)) * (1 - head) * (1 - arm)
    # Stabilize central crotch/robe seam on pelvis; it must not split between legs.
    leg *= 1 - (1 - smooth(.015, .065, ax)) * smooth(.16, .27, z)
    body = max(0., 1 - head - arm - leg)
    result = defaultdict(float)
    result["head"] += head
    blend(result, along(z, [(.46, "pelvis"), (.535, "spine"), (.61, "chest"), (.703, "neck")]), body)
    blend(result, along(ax, [(.12, f"clavicle.{side}"), (.20, f"upper_arm.{side}"),
                             (.34, f"forearm.{side}"), (.46, f"hand.{side}")]), arm)
    # Left/right blend only in the crotch seam; distal legs never get opposite-side bones.
    left = smooth(-.035, .035, x)
    for sign, fraction in (("L", left), ("R", 1 - left)):
        blend(result, along(z, [(.07, f"foot.{sign}"), (.13, f"shin.{sign}"),
                                 (.29, f"thigh.{sign}"), (.41, "pelvis")]), leg * fraction)
    return result


def make_rig(mesh):
    data = bpy.data.armatures.new("FoxfireSkeleton")
    rig = bpy.data.objects.new("Foxfire_Rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    definitions = []

    def bone(name, head, tail, parent=None, deform=True):
        b = data.edit_bones.new(name)
        b.head, b.tail, b.use_deform = head, tail, deform
        if parent:
            b.parent = data.edit_bones[parent]
        definitions.append({"name": name, "head": list(head), "tail": list(tail), "parent": parent, "deform": deform})

    bone("root", (0, 0, 0), (0, 0, .12), deform=False)
    bone("pelvis", (0, -.108, .385), (0, -.10, .50), "root")
    bone("spine", (0, -.10, .50), (0, -.108, .585), "pelvis")
    bone("chest", (0, -.108, .585), (0, -.11, .665), "spine")
    bone("neck", (0, -.11, .665), (0, -.115, .742), "chest")
    bone("head", (0, -.115, .742), (0, -.12, .91), "neck")
    for s, side in ((1, "L"), (-1, "R")):
        shoulder, elbow, wrist = (s * .13, -.108, .645), (s * .275, -.108, .643), (s * .410, -.107, .641)
        bone(f"clavicle.{side}", (0, -.108, .637), shoulder, "chest")
        bone(f"upper_arm.{side}", shoulder, elbow, f"clavicle.{side}")
        bone(f"forearm.{side}", elbow, wrist, f"upper_arm.{side}")
        bone(f"hand.{side}", wrist, (s * .50, -.108, .640), f"forearm.{side}")
        bone(f"thigh.{side}", (s * .087, -.108, .385), (s * .096, -.115, .215), "pelvis")
        bone(f"shin.{side}", (s * .096, -.115, .215), (s * .108, -.116, .070), f"thigh.{side}")
        bone(f"foot.{side}", (s * .108, -.116, .070), (s * .115, -.222, .025), f"shin.{side}")
    for i in range(5):
        bone(f"tail_{i + 1:02}", TAIL[i], TAIL[i + 1], "pelvis" if i == 0 else f"tail_{i:02}")
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "OCTAHEDRAL"
    rig.show_in_front = True
    for b in data.bones:
        group = "Tail" if b.name.startswith("tail_") else ("Root" if b.name == "root" else "Body")
        collection = data.collections.get(group) or data.collections.new(group)
        collection.assign(b)
        b.color.palette = "THEME04" if group == "Tail" else "THEME03"
    rig["README"] = "FK rig candidate. Pose Mode: select a bone and rotate. Space: binding-test action. Source preserved. Not production animation."
    rig["tail_chain"] = "tail_01 -> tail_05; parent pelvis; no cloth simulation"
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return rig, definitions


def assign_weights(mesh, rig):
    points, neighbors, index = graph(mesh.data)
    core, region, inner, components = tail_region(points, neighbors)
    weights = []
    for i, p in enumerate(points):
        result = body_weights(p)
        amount = 1. if i in core or i in inner else (smooth(.005, .065, p.y) if i in region else 0.)
        if amount:
            result = defaultdict(float, {k: v * (1 - amount) for k, v in result.items()})
            blend(result, tail_weights(p), amount)
        weights.append(result)
    # Smooth on the temporary seam-joined adjacency graph, not on UV-split vertices.
    for _ in range(3):
        smoothed = []
        for i, result in enumerate(weights):
            new = defaultdict(float)
            blend(new, result, .8)
            if neighbors[i]:
                for other in neighbors[i]:
                    blend(new, weights[other], .2 / len(neighbors[i]))
            else:
                blend(new, result, .2)
            smoothed.append(new)
        weights = smoothed
    groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in rig.data.bones if b.use_deform}
    influence_counts, totals, bone_counts = [], [], defaultdict(int)
    for original, unique in enumerate(index):
        best = sorted([(name, w) for name, w in weights[unique].items() if w > .00001], key=lambda pair: -pair[1])[:4]
        total = sum(w for _, w in best)
        if not total:
            raise RuntimeError(f"Unweighted vertex: {original}")
        totals.append(sum(w / total for _, w in best))
        influence_counts.append(len(best))
        for name, w in best:
            groups[name].add([original], w / total, "REPLACE")
            bone_counts[name] += 1
    modifier = mesh.modifiers.new("FoxfireSkin", "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = False  # Match glTF linear blend skinning.
    mesh.parent = rig
    return {"method": "anatomical coordinate fields plus temporary topology tail mask, seam-consistent smoothing, top-4 normalized influences; not automatic heat weights",
            "vertices": len(index), "temporary_graph_vertices": len(points), "components": components,
            "tail_core_unique_vertices": len(core), "tail_inner_unique_vertices": len(inner),
            "zero_weight_vertices": 0, "max_influences": max(influence_counts),
            "max_weight_sum_error": max(abs(x - 1) for x in totals), "influenced_vertices_by_bone": dict(bone_counts)}


def rotate(rig, name, world_axis, degrees):
    pb = rig.pose.bones[name]
    axis = rig.data.bones[name].matrix_local.to_quaternion().inverted() @ Vector(world_axis)
    pb.rotation_quaternion = Quaternion(axis, math.radians(degrees))


def set_pose(rig, variant, amount=1.):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    if variant == "rest":
        return
    for s, side in ((1, "L"), (-1, "R")):
        rotate(rig, f"upper_arm.{side}", (0, 1, 0), s * 42)
        rotate(rig, f"forearm.{side}", (0, 0, 1), -s * 9)
    if variant == "tail":
        for i in range(5):
            rotate(rig, f"tail_{i + 1:02}", (0, 0, 1), (10 if i == 0 else 6) * amount)
        rotate(rig, "head", (0, 0, 1), -8 * amount)
    if variant in ("arm", "arm_right"):
        side, sign = ("L", 1) if variant == "arm" else ("R", -1)
        rotate(rig, "upper_arm." + side, (0, 1, 0), sign * 15)
        rotate(rig, "forearm." + side, (0, 0, 1), -sign * 40 * amount)
        rotate(rig, "hand." + side, (0, 0, 1), -sign * 8 * amount)
        rotate(rig, "head", (0, 0, 1), -sign * 10 * amount)
    if variant in ("leg", "leg_right"):
        side = "L" if variant == "leg" else "R"
        rotate(rig, "thigh." + side, (1, 0, 0), -18 * amount)
        rotate(rig, "shin." + side, (1, 0, 0), 28 * amount)
        rotate(rig, "foot." + side, (1, 0, 0), -10 * amount)
    bpy.context.view_layer.update()


def animate(rig):
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.render.fps = 1, 145, 24
    keys = [(1, "relaxed", 0), (13, "tail", 1), (25, "tail", 0), (37, "tail", -1),
            (49, "relaxed", 0), (61, "arm", 1), (73, "arm_right", 1),
            (85, "leg", 1), (97, "leg_right", 1), (109, "tail", 1),
            (121, "tail", 0), (133, "tail", -1), (145, "relaxed", 0)]
    for frame, variant, amount in keys:
        set_pose(rig, variant, amount)
        for pb in rig.pose.bones:
            pb.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=pb.name)
            pb.keyframe_insert(data_path="location", frame=frame, group=pb.name)
    action = rig.animation_data.action
    action.name = "Rig_Check_Tail_Arms_Leg_NOT_GAME_ANIMATION"
    for frame, name in [(1, "Relaxed"), (13, "Tail left"), (37, "Tail right"),
                        (61, "Left elbow / wrist"), (73, "Right elbow / wrist"),
                        (85, "Left knee / ankle"), (97, "Right knee / ankle"), (145, "Loop")]:
        scene.timeline_markers.new(name, frame=frame)
    scene.frame_set(1)
    return action


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def stage():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device, scene.cycles.samples = "CPU", 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode, scene.render.threads = "FIXED", 6
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.32, .36, .42, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .5
    review = bpy.data.collections.new("Preview_Stage_NOT_EXPORTED")
    scene.collection.children.link(review)
    def move_stage(obj):
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        review.objects.link(obj)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.01))
    floor = bpy.context.object
    floor.name = "PreviewGround"
    material = bpy.data.materials.new("PreviewGroundMaterial")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.09, .11, .14, 1)
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .95
    floor.data.materials.append(material)
    move_stage(floor)
    for name, location, energy, size in [("Key", (2, -3, 4), 180, 3), ("Fill", (-3, -1, 2), 100, 3), ("Rim", (1, 3, 3), 150, 3)]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = "Preview" + name
        light.data.energy, light.data.size = energy, size
        aim(light, (0, 0, .55))
        move_stage(light)
    bpy.ops.object.camera_add(location=(1.65, -3, 1.5))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    camera.data.type, camera.data.ortho_scale = "ORTHO", 1.40
    aim(camera, (0, -.015, .52))
    scene.camera = camera
    move_stage(camera)
    return camera, review


def evaluated_vertices(mesh):
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    result = evaluated.to_mesh()
    coords = [mesh.matrix_world @ v.co for v in result.vertices]
    evaluated.to_mesh_clear()
    return coords


def validate_deformation(mesh, rig):
    scene = bpy.context.scene
    saved = rig.animation_data.action
    rig.animation_data.action = None
    set_pose(rig, "rest")
    rest = evaluated_vertices(mesh)
    rest_error = max((v.co - p).length for v, p in zip(mesh.data.vertices, rest))
    tests = []
    for name, amount in [("relaxed", 0), ("tail", 1), ("tail", -1), ("arm", 1), ("arm_right", 1), ("leg", 1), ("leg_right", 1)]:
        set_pose(rig, name, amount)
        points = evaluated_vertices(mesh)
        ratios = []
        for e in mesh.data.edges:
            a, b = e.vertices
            original = (rest[a] - rest[b]).length
            if original > .00005:
                ratios.append((points[a] - points[b]).length / original)
        ratios.sort()
        tests.append({"pose": name, "amount": amount,
                      "finite": all(math.isfinite(c) for p in points for c in p),
                      "max_displacement": max((a - b).length for a, b in zip(points, rest)),
                      "edge_stretch_p99": ratios[int(.99 * len(ratios))], "max_edge_stretch": max(ratios)})
    rig.animation_data.action = saved
    scene.frame_set(1)
    if rest_error > .00001 or not all(t["finite"] for t in tests):
        raise RuntimeError("Invalid rest pose or nonfinite deformed vertices")
    return {"rest_pose_max_vertex_error": rest_error, "poses": tests,
            "scope": "Numeric finite/stretch sanity, not self-intersection or final deformation acceptance"}


def render_stills(camera):
    scene = bpy.context.scene
    for frame, name, location in [(1, "relaxed_front", (1.2, -3, 1.35)),
                                  (13, "tail_test_back", (1.6, 3, 1.3)),
                                  (61, "arm_test_front", (1.2, -3, 1.35)),
                                  (85, "leg_test_side", (3, -.9, 1.10))]:
        scene.frame_set(frame)
        camera.location = location
        aim(camera, (0, -.015, .52))
        scene.render.filepath = str(BASE / (name + ".png"))
        bpy.ops.render.render(write_still=True)
    camera.location = (1.65, -3, 1.5)
    aim(camera, (0, -.015, .52))
    scene.frame_set(1)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(argv)
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != EXPECTED_SHA:
        raise RuntimeError("Unexpected source file")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(SOURCE), merge_vertices=False)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    mesh.name = "Foxfire_Mesh"
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    original_positions = [v.co.copy() for v in mesh.data.vertices]
    rig, definitions = make_rig(mesh)
    weights = assign_weights(mesh, rig)
    action = animate(rig)
    deformation = validate_deformation(mesh, rig)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(BASE / "foxfire-rigged.glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_skins=True, export_all_influences=False,
                              export_rest_position_armature=True, export_current_frame=False)
    camera, review = stage()
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.shading.type = "MATERIAL"
                space.overlay.show_floor = False
                space.region_3d.view_distance = 2.1
                space.region_3d.view_location = (0, -.01, .54)
                space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
    # Preview helpers are hidden only in the interactive viewport, still renderable.
    for obj in review.objects:
        obj.hide_set(True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE / "foxfire-rigged.blend"), compress=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    report = {"date": "2026-10-12", "blender": bpy.app.version_string, "source": "../hunyuan_model_review_v1/source.glb",
              "source_sha256": EXPECTED_SHA, "bones": definitions, "bone_count": len(definitions),
              "mesh_vertices": len(mesh.data.vertices), "mesh_triangles": len(mesh.data.polygons),
              "source_geometry_changed": any((v.co - p).length > 1e-7 for v, p in zip(mesh.data.vertices, original_positions)),
              "source_mesh_uv_material_preserved": True, "weighting": weights, "deformation_checks": deformation,
              "action": action.name, "frames": [1, 145], "fps": 24,
              "limitations": ["FK prototype, no IK controllers, fingers, face or cloth simulation", "No self-intersection or game performance certification", "Binding-test motion only; not completed idle/walk/attack animations"]}
    (BASE / "rig-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    if args.render:
        render_stills(camera)
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != EXPECTED_SHA:
        raise RuntimeError("Source unexpectedly changed")
    print("RIG_COMPLETE " + json.dumps({"bones": len(definitions), "weights": weights, "deformation": deformation}))


if __name__ == "__main__":
    main()
