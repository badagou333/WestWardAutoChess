"""Read-only GLB import audit and review rendering. Does not re-rig or export models."""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(Path(__file__).with_name("source.glb")))
    parser.add_argument("--output", default=str(Path(__file__).parent))
    parser.add_argument("--views", default="cardinal", choices=["cardinal", "game", "audit"])
    parser.add_argument("--front-y", type=int, default=-1, choices=[-1, 1])
    return parser.parse_args(argv)


def components(bm, matrix):
    remaining = set(bm.verts)
    sizes = []
    while remaining:
        seed = remaining.pop()
        stack = [seed]
        members = []
        while stack:
            vertex = stack.pop()
            members.append(vertex)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in remaining:
                    remaining.remove(other)
                    stack.append(other)
        points = [matrix @ vertex.co for vertex in members]
        sizes.append({
            "vertices": len(members),
            "faces": len({face for vertex in members for face in vertex.link_faces}),
            "bounds_world_min": [min(point[i] for point in points) for i in range(3)],
            "bounds_world_max": [max(point[i] for point in points) for i in range(3)],
        })
    return sorted(sizes, key=lambda item: item["vertices"], reverse=True)


def mesh_audit(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    extent = max(obj.dimensions)
    raw_boundaries = sum(edge.is_boundary for edge in bm.edges)
    # Diagnose coincident UV/normal-split vertices on a TEMPORARY copy only.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=max(extent * 1e-6, 1e-8))
    welded_components = components(bm, obj.matrix_world)
    boundary_points = [obj.matrix_world @ vertex.co for edge in bm.edges if edge.is_boundary for vertex in edge.verts]
    result = {
        "object": obj.name,
        "vertices_imported": len(mesh.vertices),
        "polygons": len(mesh.polygons),
        "triangles": len(mesh.loop_triangles),
        "uv_layers": [layer.name for layer in mesh.uv_layers],
        "materials": [mat.name if mat else None for mat in mesh.materials],
        "raw_boundary_edges": raw_boundaries,
        "diagnostic_weld_tolerance": max(extent * 1e-6, 1e-8),
        "welded_vertices": len(bm.verts),
        "welded_boundary_edges": sum(edge.is_boundary for edge in bm.edges),
        "welded_nonmanifold_edges": sum(not edge.is_manifold for edge in bm.edges),
        "welded_connected_components": len(welded_components),
        "welded_component_vertex_sizes": [item["vertices"] for item in welded_components[:20]],
        "welded_component_details": welded_components[:20],
        "welded_boundary_world_bounds": {
            "min": [min(point[i] for point in boundary_points) for i in range(3)],
            "max": [max(point[i] for point in boundary_points) for i in range(3)],
        } if boundary_points else None,
        "note": "Welding was diagnostic only; UV seams can look like open edges before welding. This does not test self-intersections.",
    }
    bm.free()
    return result


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, location, energy, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    aim(obj, target)


def main():
    args = arguments()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.source).resolve()), merge_vertices=False)
    source_objects = list(bpy.context.scene.objects)
    meshes = [obj for obj in source_objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("GLB imported without mesh objects")
    bpy.context.view_layer.update()
    audits = [mesh_audit(obj) for obj in meshes]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    lo = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    hi = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    report = {
        "blender_version": bpy.app.version_string,
        "source": "source.glb",
        "source_object_types": {kind: sum(obj.type == kind for obj in source_objects) for kind in ("MESH", "ARMATURE", "EMPTY")},
        "mesh_audits": audits,
        "triangles_total": sum(row["triangles"] for row in audits),
        "armature_bones": {obj.name: len(obj.data.bones) for obj in source_objects if obj.type == "ARMATURE"},
        "actions": [action.name for action in bpy.data.actions],
        "bounds_imported": {"min": list(lo), "max": list(hi), "size": list(hi - lo)},
        "images": [{"name": im.name, "size": list(im.size), "channels": im.channels, "packed": bool(im.packed_file)} for im in bpy.data.images],
        "materials": [{"name": mat.name, "nodes": [node.bl_idname for node in mat.node_tree.nodes] if mat.use_nodes else []} for mat in bpy.data.materials],
        "scope": "Import audit and native Blender still renders only; no rigging, model export or runtime integration.",
    }
    if args.views in ("cardinal", "audit"):
        (output / "blender-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    if args.views == "audit":
        print("REVIEW_AUDIT_COMPLETE " + json.dumps(report["mesh_audits"]))
        return
    # Only the review scene is normalized. The source GLB is never changed.
    root = bpy.data.objects.new("ReviewNormalize", None)
    bpy.context.collection.objects.link(root)
    for obj in source_objects:
        if obj.parent is None:
            obj.parent = root
    height = hi.z - lo.z
    if height <= 0:
        raise RuntimeError("Non-positive imported character height")
    scale = 2.0 / height
    root.scale = (scale, scale, scale)
    root.location = (-0.5 * (lo.x + hi.x) * scale, -0.5 * (lo.y + hi.y) * scale, -lo.z * scale)
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.world = bpy.data.worlds.new("ReviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.55, 0.55, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.005))
    floor = bpy.context.object
    floor.name = "ReviewFloor_NotInSource"
    mat = bpy.data.materials.new("ReviewFloorMaterial")
    mat.diffuse_color = (0.32, 0.34, 0.36, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.32, 0.34, 0.36, 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    floor.data.materials.append(mat)
    area("ReviewKey", (3, -4, 5), 650, 4, (0, 0, 1))
    area("ReviewFill", (-4, 2, 3), 450, 4, (0, 0, 1))
    area("ReviewRim", (1, 4, 4), 350, 3, (0, 0, 1))
    data = bpy.data.cameras.new("ReviewCamera")
    camera = bpy.data.objects.new("ReviewCamera", data)
    bpy.context.collection.objects.link(camera)
    data.type = "ORTHO"
    data.ortho_scale = 2.65
    scene.camera = camera
    if args.views == "cardinal":
        views = [("view_neg_y", (0, -6, 1.05)), ("view_pos_y", (0, 6, 1.05)), ("view_neg_x", (-6, 0, 1.05)), ("view_pos_x", (6, 0, 1.05))]
    else:
        data.ortho_scale = 2.9
        views = [("game_view", (4.2, args.front_y * 6, 4.7))]
    renders = []
    for name, location in views:
        camera.location = location
        aim(camera, (0, 0, 1.05))
        scene.render.filepath = str(output / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        renders.append({"file": name + ".png", "camera": list(location), "target": [0, 0, 1.05], "ortho_scale": data.ortho_scale})
    (output / ("render-cardinal.json" if args.views == "cardinal" else "render-game.json")).write_text(json.dumps({"render_mode": "Cycles CPU, 24 samples, Standard view transform", "source_materials_preserved": True, "renders": renders}, indent=2) + "\n")
    print("REVIEW_RENDER_COMPLETE " + json.dumps({"triangles": report["triangles_total"], "armatures": len(report["armature_bones"]), "renders": [row["file"] for row in renders]}))


if __name__ == "__main__":
    main()
