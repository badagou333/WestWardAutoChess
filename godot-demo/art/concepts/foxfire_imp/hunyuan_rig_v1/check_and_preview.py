"""Reopen exported GLB independently in Blender, test skinning, and render a turntable clip.

The camera orbits the actual skinned model; no 2D image warping or animation fabrication.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parent


def vertices(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    result = [obj.matrix_world @ v.co for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--count", type=int, default=49)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = BASE / "foxfire-rigged.glb"
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=False)
    scene = bpy.context.scene
    mesh = next(o for o in scene.objects if o.type == "MESH")
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    action_names = [a.name for a in bpy.data.actions]
    if rig.animation_data and rig.animation_data.nla_tracks:
        for track in rig.animation_data.nla_tracks:
            track.mute = False
    scene.frame_set(1)
    baseline = vertices(mesh)
    checks = []
    for frame in (13, 37, 61, 73, 85, 97, 145):
        scene.frame_set(frame)
        current = vertices(mesh)
        displacement = [(p - q).length for p, q in zip(current, baseline)]
        checks.append({"frame": frame, "max_deformation_from_frame_1": max(displacement),
                       "vertices_moved_over_1e_5": sum(d > 1e-5 for d in displacement),
                       "finite": all(math.isfinite(c) for p in current for c in p)})
    weighted = sum(bool(v.groups) for v in mesh.data.vertices)
    report = {"date": "2026-10-12", "blender": bpy.app.version_string,
              "glb_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "rigs": len([o for o in scene.objects if o.type == "ARMATURE"]),
              "bones": len(rig.data.bones), "tail_bones": [b.name for b in rig.data.bones if b.name.startswith("tail_")],
              "actions": action_names, "weighted_vertices": weighted, "vertices": len(mesh.data.vertices),
              "images": [{"size": list(i.size), "packed": bool(i.packed_file)} for i in bpy.data.images],
              "animation_deformation": checks,
              "scope": "Actual exported GLB reimport and mesh deformation, not Godot or gameplay performance."}
    assert report["bones"] == 25
    assert len(report["tail_bones"]) == 5
    assert action_names and weighted == len(mesh.data.vertices)
    assert all(c["finite"] for c in checks)
    assert all(c["max_deformation_from_frame_1"] > .01 for c in checks[:-1])
    assert checks[-1]["max_deformation_from_frame_1"] < .00001
    (BASE / "roundtrip-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("GLB_ROUNDTRIP_PASS " + json.dumps(report), flush=True)
    if not args.render:
        return
    # Preview the editable .blend as delivered, after the separate GLB import check.
    bpy.ops.wm.open_mainfile(filepath=str(BASE / "foxfire-rigged.blend"))
    scene = bpy.context.scene
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    scene.render.resolution_x, scene.render.resolution_y = 512, 512
    scene.cycles.samples = 8
    output = BASE / "preview_frames"
    output.mkdir(exist_ok=True)
    for i in range(args.count):
        frame = 1 + round(i * 144 / (args.count - 1))
        scene.frame_set(frame)
        # Show front-arm/knee poses, then back-tail poses. Smooth camera orbit closes loop.
        angle = math.radians(25) + 2 * math.pi * i / (args.count - 1)
        camera = scene.camera
        camera.location = (3 * math.sin(angle), -3 * math.cos(angle), 1.4)
        camera.rotation_euler = (Vector((0, -.015, .52)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(output / f"frame-{i:03}.png")
        bpy.ops.render.render(write_still=True)
    print("PREVIEW_FRAMES_COMPLETE " + str(args.count), flush=True)


if __name__ == "__main__":
    main()
