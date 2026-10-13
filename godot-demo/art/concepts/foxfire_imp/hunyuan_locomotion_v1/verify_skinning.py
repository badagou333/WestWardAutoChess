"""Independent CPU skinning audit. Requires Python 3.10+ and NumPy.

Run: python3 verify_skinning.py [--output report.json]
Diagnostic: --no-grounding reproduces the uncorrected blend and must fail.
No Blender, GPU, build script, runtime process, or personal path is required.
"""

import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path
import struct

import numpy as np


DIRECTORY = Path(__file__).resolve().parent
BASE_GLB = DIRECTORY.parent / "hunyuan_board_actor_v1/foxfire-board-actor.glb"
RUN_JSON = DIRECTORY / "locomotion-animations.json"
IDLE_JSON = DIRECTORY.parent / "hunyuan_spell_v1/spell-animations.json"
RUN_WEIGHTS = (0, .125, .25, .375, .5, .625, .75, .875, 1)
PHASES = 120
WORLD_SCALE = 1.65
BOARD_SURFACE_Y = -.002
PROBE_TARGET_Y = .002
PENETRATION_TOLERANCE_WORLD = 1e-6
LOOP_TOLERANCE_MODEL = 1e-5


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def slerp(a, b, weight):
    a, b = np.asarray(a, float), np.asarray(b, float)
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    dot = float(a @ b)
    if dot < 0:
        b, dot = -b, -dot
    dot = min(1., dot)
    if dot > .9995:
        q = a + (b - a) * weight
        return q / np.linalg.norm(q)
    theta = math.acos(dot)
    return (a * math.sin((1-weight)*theta) + b * math.sin(weight*theta)) / math.sin(theta)


def trs(translation, rotation, scale):
    x, y, z, w = np.asarray(rotation) / np.linalg.norm(rotation)
    matrix = np.eye(4)
    matrix[:3, :3] = np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)],
    ]) @ np.diag(scale)
    matrix[:3, 3] = translation
    return matrix


def defaults(node):
    return {"translation": node.get("translation", [0, 0, 0]),
            "rotation": node.get("rotation", [0, 0, 0, 1]),
            "scale": node.get("scale", [1, 1, 1])}


class Skin:
    def __init__(self, path):
        blob = path.read_bytes()
        magic, version, length = struct.unpack_from("<III", blob)
        require(magic == 0x46546C67 and version == 2 and length == len(blob), "Invalid GLB header")
        json_size, kind = struct.unpack_from("<II", blob, 12)
        require(kind == 0x4E4F534A, "Missing GLB JSON")
        self.doc = json.loads(blob[20:20+json_size])
        bin_size, kind = struct.unpack_from("<II", blob, 20+json_size)
        require(kind == 0x004E4942, "Missing GLB binary buffer")
        self.data = blob[28+json_size:28+json_size+bin_size]
        self.nodes = self.doc["nodes"]
        self.parents = {child: i for i, node in enumerate(self.nodes) for child in node.get("children", [])}
        meshes = [i for i, node in enumerate(self.nodes) if "mesh" in node and "skin" in node]
        require(len(meshes) == 1, "Expected one skinned fox mesh")
        mesh_index = meshes[0]
        node = self.nodes[mesh_index]
        skin = self.doc["skins"][node["skin"]]
        self.joints = skin["joints"]
        self.names = [self.nodes[index]["name"] for index in self.joints]
        require(len(self.names) == 25 and len(set(self.names)) == 25, "Expected unchanged 25-bone fox skeleton")
        self.inverse_bind = self.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        positions, joints, weights = [], [], []
        for primitive in self.doc["meshes"][node["mesh"]]["primitives"]:
            attributes = primitive["attributes"]
            require("JOINTS_1" not in attributes and not primitive.get("targets"), "Unsupported extra influences or morph targets")
            positions.append(self.accessor(attributes["POSITION"]))
            joints.append(self.accessor(attributes["JOINTS_0"]).astype(int))
            weights.append(self.accessor(attributes["WEIGHTS_0"]))
        positions = np.concatenate(positions)
        self.joint_indices, self.weights = np.concatenate(joints), np.concatenate(weights)
        self.positions = np.concatenate([positions, np.ones((len(positions), 1))], axis=1)
        require(np.isfinite(self.positions).all() and np.isfinite(self.weights).all(), "Nonfinite mesh data")
        require(np.max(np.abs(self.weights.sum(axis=1)-1)) < 1e-5, "Invalid vertex weight sums")
        require(self.joint_indices.min() >= 0 and self.joint_indices.max() < len(self.joints), "Invalid joint index")
        rest = (self.global_matrices()[mesh_index] @ self.positions.T).T[:, :3]
        self.sole, self.fullfoot = {}, {}
        for side in ("L", "R"):
            weight = np.sum(self.weights * (self.joint_indices == self.names.index("foot."+side)), axis=1)
            self.sole[side] = np.where((rest[:, 1] <= .05) & (weight >= .5))[0]
            self.fullfoot[side] = np.where(weight >= .5)[0]
            require(len(self.sole[side]) > 0, "Empty sole selection")
        tail_joints = [i for i, name in enumerate(self.names) if name.startswith("tail_")]
        self.tail = np.where(np.sum(self.weights*np.isin(self.joint_indices, tail_joints), axis=1) >= .5)[0]
        require(len(self.tail) > 0, "Empty tail selection")

    def accessor(self, index):
        accessor = self.doc["accessors"][index]
        require("sparse" not in accessor, "Sparse accessors are unsupported")
        view = self.doc["bufferViews"][accessor["bufferView"]]
        types = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
        widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
        dtype, width = np.dtype(types[accessor["componentType"]]), widths[accessor["type"]]
        result = np.ndarray((accessor["count"], width), dtype=dtype, buffer=self.data,
                            offset=view.get("byteOffset", 0)+accessor.get("byteOffset", 0),
                            strides=(view.get("byteStride", dtype.itemsize*width), dtype.itemsize)).copy()
        if accessor.get("normalized") and accessor["componentType"] != 5126:
            result = result.astype(float)/np.iinfo(dtype).max
        return result

    def global_matrices(self, pose=None):
        result = {}
        def solve(index):
            if index in result:
                return result[index]
            node = self.nodes[index]
            values = pose.get(node.get("name"), defaults(node)) if pose else defaults(node)
            if "matrix" in node and (not pose or node.get("name") not in pose):
                matrix = np.asarray(node["matrix"]).reshape(4, 4).T
            else:
                matrix = trs(values["translation"], values["rotation"], values["scale"])
            if index in self.parents:
                matrix = solve(self.parents[index]) @ matrix
            result[index] = matrix
            return matrix
        for index in range(len(self.nodes)):
            solve(index)
        return result

    def points(self, pose):
        global_pose = self.global_matrices(pose)
        matrices = np.asarray([global_pose[joint] @ self.inverse_bind[k] for k, joint in enumerate(self.joints)])
        points = np.zeros_like(self.positions)
        for k in range(self.weights.shape[1]):
            points += np.einsum("nij,nj->ni", matrices[self.joint_indices[:, k]], self.positions) * self.weights[:, k, None]
        return points[:, :3]

    def ground(self, pose, probes, weight, enabled):
        global_pose = self.global_matrices(pose)
        heights = []
        for side in ("L", "R"):
            matrix = global_pose[self.joints[self.names.index("foot."+side)]]
            heights.extend(float((matrix @ np.array([*point, 1.]))[1]) for point in probes[side])
        minimum = min(heights)
        lift = max(0., PROBE_TARGET_Y-minimum) if enabled and 0 < weight < 1 else 0.
        result = {name: {key: value.copy() for key, value in values.items()} for name, values in pose.items()}
        result["root"]["translation"][1] += lift
        return result, minimum, lift


def validate_tracks(tracks, names, duration):
    seen = set()
    for track in tracks:
        key = track["bone"], track["path"]
        require(key not in seen, "Duplicate animation track")
        seen.add(key)
        times, values = np.asarray(track["times"]), np.asarray(track["values"])
        width = 4 if track["path"] == "rotation" else 3
        require(len(times) >= 2 and values.shape == (len(times), width), "Incomplete animation values")
        require(np.isfinite(times).all() and np.isfinite(values).all(), "Nonfinite animation values")
        require(abs(times[0]) < 1e-6 and abs(times[-1]-duration) < 1e-6 and (np.diff(times) > 0).all(), "Invalid animation timeline")
        if track["path"] == "rotation":
            require(np.max(np.abs(np.linalg.norm(values, axis=1)-1)) < .001, "Invalid quaternion norm")
    expected = {(name, prop) for name in names for prop in ("translation", "rotation", "scale")}
    require(seen == expected, "Missing or unexpected bone tracks")


def pose_at(tracks, time):
    result = {}
    for track in tracks:
        times, values, prop = track["times"], track["values"], track["path"]
        index = max(0, min(len(times)-2, bisect.bisect_right(times, time)-1))
        weight = max(0., min(1., (time-times[index])/(times[index+1]-times[index])))
        value = (slerp(values[index], values[index+1], weight) if prop == "rotation"
                 else np.asarray(values[index])*(1-weight)+np.asarray(values[index+1])*weight)
        result.setdefault(track["bone"], {})[prop] = value
    return result


def audit(grounding):
    skin = Skin(BASE_GLB)
    run_data, idle_data = json.loads(RUN_JSON.read_text()), json.loads(IDLE_JSON.read_text())
    require(run_data["base_glb_sha256"] == idle_data["base_glb_sha256"] == sha(BASE_GLB), "Source GLB hash mismatch")
    run, idle_clip = run_data["clips"]["NaturalRun"], idle_data["clips"]["SpellIdle"]
    validate_tracks(run["tracks"], skin.names, run["duration"])
    validate_tracks(idle_clip["tracks"], skin.names, idle_clip["duration"])
    probes = run_data["sole_probes"]
    for side in ("L", "R"):
        array = np.asarray(probes[side])
        require(array.ndim == 2 and array.shape[0] > 0 and array.shape[1] == 3 and np.isfinite(array).all(), "Invalid sole probes")
    idle = pose_at(idle_clip["tracks"], 0)
    rows, failures = [], []
    for weight in RUN_WEIGHTS:
        samples, first = [], None
        for index in range(PHASES+1):
            phase = index/PHASES
            running = pose_at(run["tracks"], phase*run["duration"])
            mixed = {name: {prop: slerp(idle[name][prop], running[name][prop], weight) if prop == "rotation"
                            else idle[name][prop]*(1-weight)+running[name][prop]*weight
                            for prop in ("translation", "rotation", "scale")} for name in skin.names}
            raw = skin.points(mixed)
            pose, probe_minimum, lift = skin.ground(mixed, probes, weight, grounding)
            points = skin.points(pose)
            require(np.isfinite(points).all(), "Nonfinite skinned points")
            if first is None:
                first = points.copy()
            minimum_vertex = int(np.argmin(points[:, 1]))
            feet = {side: float(points[vertices, 1].min()) for side, vertices in skin.fullfoot.items()}
            sample = {"phase": phase, "root_lift_model": lift,
                      "probe_overestimate_model": probe_minimum-min(float(raw[v, 1].min()) for v in skin.fullfoot.values()),
                      "mesh_min_y_model": float(points[minimum_vertex, 1]), "mesh_min_vertex": minimum_vertex,
                      "fullfoot_min_y_model": feet, "tail_min_y_model": float(points[skin.tail, 1].min())}
            samples.append(sample)
            if sample["mesh_min_y_model"]*WORLD_SCALE < BOARD_SURFACE_Y-PENETRATION_TOLERANCE_WORLD:
                failures.append({"check": "full_mesh_ground_clearance", "run_weight": weight, **sample})
        seam = float(np.linalg.norm(first-points, axis=1).max())
        if seam > LOOP_TOLERANCE_MODEL:
            failures.append({"check": "loop_position", "run_weight": weight, "error_model": seam})
        row = {"run_weight": weight, "evaluated_poses": PHASES+1,
               "minimum_mesh_height_model": min(s["mesh_min_y_model"] for s in samples),
               "minimum_fullfoot_height_model": min(min(s["fullfoot_min_y_model"].values()) for s in samples),
               "minimum_tail_height_model": min(s["tail_min_y_model"] for s in samples),
               "maximum_root_lift_model": max(s["root_lift_model"] for s in samples),
               "maximum_probe_overestimate_model": max(s["probe_overestimate_model"] for s in samples),
               "max_adjacent_root_lift_change_model": max(abs(a["root_lift_model"]-b["root_lift_model"]) for a, b in zip(samples, samples[1:])),
               "seam_max_position_error_model": seam,
               "worst_mesh_sample": min(samples, key=lambda s: s["mesh_min_y_model"]), "samples": samples}
        rows.append(row)
        print(f"weight={weight:.3f} mesh_min={row['minimum_mesh_height_model']:.9f} max_lift={row['maximum_root_lift_model']:.9f}", flush=True)
    return {"passed": not failures, "failure_count": len(failures), "failures": failures,
            "method": {"algorithm": "Independent glTF parent-local TRS lerp / shortest quaternion slerp; hierarchy composition; exact source vertex linear blend skinning. No build or runtime code imported.",
                       "grounding_enabled": grounding, "grounding": "For 0<run_weight<1, evaluate source sole probes in posed foot coordinates, then root local Y += max(0, .002-probe_minY). Check actual full mesh after correction.",
                       "weights": list(RUN_WEIGHTS), "weight_definition": "Post-smoothstep pose weights, not raw speed fractions; runtime weight=smoothstep(0,.5,actual_speed/2.35).",
                       "unique_phases_per_weight": PHASES, "extra_loop_endpoint_per_weight": 1, "total_evaluated_poses": len(RUN_WEIGHTS)*(PHASES+1),
                       "world_scale": WORLD_SCALE, "board_surface_world_y": BOARD_SURFACE_Y,
                       "board_surface_basis": "world_builder.gd tile center Y=-.062 plus half height .12/2",
                       "penetration_tolerance_world": PENETRATION_TOLERANCE_WORLD, "loop_position_tolerance_model": LOOP_TOLERANCE_MODEL,
                       "probe_target_y_model": PROBE_TARGET_Y, "threshold_policy": "Pass requires every actual skinned mesh vertex above the real board plane within fixed numerical tolerance and closed loop position; no probe-only acceptance or compensation-size quality threshold.",
                       "vertex_count": len(skin.positions), "bone_count": len(skin.names),
                       "fullfoot_selection": "Foot-bone weight >= .5 on the entire foot, with no rest-height or fore-aft exclusion.",
                       "fullfoot_counts": {side: len(vertices) for side, vertices in skin.fullfoot.items()},
                       "sole_counts_rest_height_le_005": {side: len(vertices) for side, vertices in skin.sole.items()},
                       "probe_counts": {side: len(probes[side]) for side in ("L", "R")},
                       "limits": "Discrete fixed-weight straight-cycle poses. Does not certify arbitrary in-between weights/times, dynamic Godot transitions, foot sliding during acceleration/turns, full-body self-collision, GPU output, or human naturalness."},
            "inputs": {"base_glb": "../hunyuan_board_actor_v1/foxfire-board-actor.glb", "base_glb_sha256": sha(BASE_GLB),
                       "run_json": "locomotion-animations.json", "run_json_sha256": sha(RUN_JSON),
                       "idle_json": "../hunyuan_spell_v1/spell-animations.json", "idle_json_sha256": sha(IDLE_JSON)},
            "results": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DIRECTORY/"independent-skinning-report.json")
    parser.add_argument("--no-grounding", action="store_true", help="Diagnostic negative control; uncorrected blending should fail")
    args = parser.parse_args()
    try:
        report = audit(not args.no_grounding)
    except (ValueError, KeyError, IndexError, OSError, struct.error) as error:
        report = {"passed": False, "failure_count": 1, "failures": [{"check": "input_or_evaluation", "error": str(error)}]}
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False)+"\n")
    print(f"SKINNING_AUDIT {'PASS' if report['passed'] else 'FAIL'}: {args.output}")
    if not report["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
