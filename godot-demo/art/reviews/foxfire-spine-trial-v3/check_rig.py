"""Independent visible-material geometry QA. A pass is not visual acceptance."""
from pathlib import Path
import hashlib
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from render_preview import load_data, mesh_points, mesh_uv_point, pose, sample

ROOT = Path(__file__).resolve().parent
SOURCE_BYTES = (ROOT / "foxfire-v3.json").read_bytes()
SOURCE_HASH = hashlib.sha256(SOURCE_BYTES).hexdigest()
D = json.loads(SOURCE_BYTES)
D["_preview_source_dir"] = str(ROOT)
NOTES = json.loads((ROOT / "rig-notes.json").read_text())
CYCLE = NOTES["cycle_seconds"]
STANCE = NOTES["stance_fraction"]
SPEED = NOTES["speed_source_px_per_second"]
LEGS = NOTES["legs"]
SKIN = D["skins"][0]["attachments"]
RESULTS, METRICS, FINDINGS = [], {}, []


def check(name, passed, actual=None, criterion=None):
    item = {"check": name, "passed": bool(passed)}
    if actual is not None:
        item["actual"] = actual
    if criterion is not None:
        item["criterion"] = criterion
    RESULTS.append(item)


def art(name):
    with Image.open(ROOT / "images" / (name + ".png")) as source:
        return np.asarray(source.convert("RGBA"))


def attachment(slot):
    return SKIN[slot][next(item["attachment"] for item in D["slots"] if item["name"] == slot)]


def material_triangles(att):
    """Require actual alpha material somewhere in each triangle, not only its center."""
    pixels = art(att["path"])
    uvs = np.asarray(att["uvs"]).reshape(-1, 2) * [pixels.shape[1], pixels.shape[0]]
    visible, fractions = [], []
    for ids in np.asarray(att["triangles"]).reshape(-1, 3):
        triangle = uvs[ids]
        low = np.maximum(np.floor(triangle.min(axis=0)).astype(int), 0)
        high = np.minimum(np.ceil(triangle.max(axis=0)).astype(int) + 1, [pixels.shape[1], pixels.shape[0]])
        width, height = high - low
        if min(width, height) <= 0:
            visible.append(False); fractions.append(0.0); continue
        mask = Image.new("L", (int(width), int(height)))
        ImageDraw.Draw(mask).polygon([tuple(point) for point in triangle - low], fill=255)
        region = pixels[low[1]:high[1], low[0]:high[0], 3]
        inside = np.asarray(mask) > 0
        opaque = inside & (region >= 128)
        visible.append(bool(opaque.any()))
        fractions.append(float(opaque.sum() / max(1, inside.sum())))
    return np.asarray(visible), fractions


def areas(points, ids):
    u, v = points[ids[:, 1]] - points[ids[:, 0]], points[ids[:, 2]] - points[ids[:, 0]]
    return u[:, 0] * v[:, 1] - u[:, 1] * v[:, 0]


def alpha(slot, anim, t):
    info = next(s for s in D["slots"] if s["name"] == slot)
    default = int(info.get("color", "ffffffff")[-2:], 16) / 255
    keys = D["animations"][anim].get("slots", {}).get(slot, {}).get("alpha")
    return sample(keys, t, "value", default)


def run():
    seen = set()
    for bone in D["bones"]:
        check("parent-first unique bone " + bone["name"],
              bone["name"] not in seen and ("parent" not in bone or bone["parent"] in seen))
        seen.add(bone["name"])

    texture = art("leg-left")
    height, width = texture.shape[:2]
    landmarks = dict(NOTES["visible_landmarks_image_px"])
    yy, xx = np.where(texture[:, :, 3] >= 128)
    lowest = int(yy.max())
    contact_x = int(np.median(np.where(texture[lowest, :, 3] >= 128)[0]))
    landmarks["contact"] = [contact_x, lowest]
    METRICS["landmark_image_pixels"] = landmarks
    for name in ["toe", "heel", "sole", "contact"]:
        x, y = landmarks[name]
        opacity = int(texture[y, x, 3])
        check("visible material anchor " + name, opacity >= 128, opacity, "alpha >= 128")
    if landmarks["sole"][1] < lowest - 5:
        FINDINGS.append("The authored sole anchor is inside the paw rather than on the lowest contact contour; QA additionally follows an alpha-derived contact point.")
    uv = {name: np.asarray(value) / [width, height]
          for name, value in landmarks.items() if name in ["toe", "heel", "sole", "contact"]}
    base = {leg: {name: mesh_uv_point(D, attachment(leg), "", 0, value)
                  for name, value in uv.items()} for leg in LEGS}

    # Sample between baked keys too, so the test exercises interpolation.
    move_times = np.linspace(0, CYCLE, 337)
    records = {}
    for leg, spec in LEGS.items():
        att = attachment(leg)
        tracks = {name: np.asarray([mesh_uv_point(D, att, "move", float(t), value)
                                   for t in move_times]) for name, value in uv.items()}
        records[leg] = tracks
        heading = tracks["toe"] - tracks["heel"]
        max_forward = float(heading[:, 0].max())
        check(leg + " visible toe points left throughout walk", max_forward < -30, max_forward, "toe.x - heel.x < -30 source pixels")
        # Test each connected support interval independently; one leg straddles time zero.
        phase = (move_times / CYCLE + spec["phase"]) % 1
        stance = phase <= STANCE
        split = np.where(np.diff(np.flatnonzero(stance)) > 1)[0] + 1
        segments = np.split(np.flatnonzero(stance), split)
        drift = 0.0
        for indices in segments:
            for name in uv:
                world = tracks[name][indices].copy()
                world[:, 0] -= SPEED * move_times[indices]
                drift = max(drift, float(np.ptp(world, axis=0).max()))
        METRICS[leg + "_visible_stance_drift_source_px"] = drift
        check(leg + " visible anchors remain planted in moving reference", drift < .25, drift, "< .25 source pixel")
        contact_height = tracks["contact"][:, 1] - base[leg]["contact"][1]
        METRICS[leg + "_contact_height_range_source_px"] = [float(contact_height.min()), float(contact_height.max())]
        check(leg + " visible contact never penetrates ground", float(contact_height.min()) > -.25,
              float(contact_height.min()), "> -.25 source pixel relative to own depth lane")
        check(leg + " visible swing clearance", 25 < float(contact_height.max()) < 65,
              float(contact_height.max()), "25..65 source pixels")

    leg_names = list(LEGS)
    separation = records[leg_names[1]]["contact"][:, 0] - records[leg_names[0]]["contact"][:, 0]
    METRICS["contact_fore_aft_difference_range"] = [float(separation.min()), float(separation.max())]
    check("visible feet exchange fore-aft order", separation.min() < -20 and separation.max() > 20,
          METRICS["contact_fore_aft_difference_range"], "both < -20 and > +20 source pixels")
    heights = np.array([records[leg]["contact"][:, 1] - base[leg]["contact"][1] for leg in leg_names])
    simultaneous_air = float(np.min(heights, axis=0).max())
    check("at least one visible foot remains grounded throughout walk", simultaneous_air < .25,
          simultaneous_air, "minimum of two contact heights < .25 source pixel")

    # Areas of all triangles with visible alpha material, including edge triangles.
    for slot, contents in SKIN.items():
        for att_name, att in contents.items():
            if att.get("type") != "mesh":
                continue
            ids = np.asarray(att["triangles"]).reshape(-1, 3)
            visible, fractions = material_triangles(att)
            values = iter(att["vertices"])
            sums = []
            for _ in range(len(att["uvs"]) // 2):
                total = 0.0
                for _ in range(int(next(values))):
                    index, lx, ly, weight = [next(values) for _ in range(4)]
                    total += weight
                sums.append(total)
            weight_error = max(abs(value - 1) for value in sums)
            check(slot + " normalized skinning weights", weight_error < 1e-7, weight_error)
            reference = mesh_points(D, att, "", 0)
            rest_area = areas(reference, ids)
            check(slot + " nondegenerate rest triangles", np.all(np.abs(rest_area) > 1e-7))
            extrema = {}
            for anim, duration in NOTES["durations"].items():
                minimum, maximum, worst_t, worst_triangle = 1.0, 1.0, 0.0, 0
                for t in np.linspace(0, duration, math.ceil(duration * 120) + 1):
                    ratio = areas(mesh_points(D, att, anim, float(t)), ids) / rest_area
                    low, high = float(ratio[visible].min()), float(ratio[visible].max())
                    if low < minimum:
                        minimum, worst_t = low, float(t)
                        worst_triangle = int(np.argmin(np.where(visible, ratio, np.inf)))
                    maximum = max(maximum, high)
                pixels = art(att["path"])
                uv_pixels = np.asarray(att["uvs"]).reshape(-1, 2) * [pixels.shape[1], pixels.shape[0]]
                extrema[anim] = {"min_area_ratio": minimum, "max_area_ratio": maximum,
                                 "worst_time": worst_t, "worst_triangle_index": worst_triangle,
                                 "worst_triangle_image_pixels": uv_pixels[ids[worst_triangle]].tolist(),
                                 "worst_triangle_opaque_fraction": fractions[worst_triangle]}
                check(slot + " visible triangles do not fold in " + anim, minimum > .05,
                      minimum, "signed visible-material triangle area ratio > .05")
                check(slot + " visible material avoids severe area collapse in " + anim, minimum > .35 and maximum < 2,
                      [minimum, maximum], "area ratio .35..2 (geometric warning threshold, not a shape-quality guarantee)")
            METRICS[slot + "_visible_triangle_areas"] = extrema
            METRICS[slot + "_material_triangle_count"] = int(visible.sum())

    # Reach margin and actual segment lengths, with the authored same-side knee branch.
    for leg, spec in LEGS.items():
        min_margin, max_length_error, min_signed_knee = 1e9, 0.0, 1e9
        for anim, duration in NOTES["durations"].items():
            for t in np.linspace(0, duration, math.ceil(duration * 120) + 1):
                matrices = pose(D, anim, float(t))
                hip = np.asarray(matrices[leg][4:]); knee = np.asarray(matrices[leg + "_calf"][4:]); foot = np.asarray(matrices[leg + "_foot"][4:])
                reach = float(np.linalg.norm(foot - hip))
                min_margin = min(min_margin, spec["l1"] + spec["l2"] - reach, reach - abs(spec["l1"] - spec["l2"]))
                max_length_error = max(max_length_error, abs(np.linalg.norm(knee - hip) - spec["l1"]), abs(np.linalg.norm(foot - knee) - spec["l2"]))
                a, b = knee - hip, foot - knee
                min_signed_knee = min(min_signed_knee, float(a[0] * b[1] - a[1] * b[0]))
        METRICS[leg + "_min_reach_margin"] = min_margin
        check(leg + " remains reachable with fixed lengths", min_margin > 0 and max_length_error < 1e-5,
              {"reach_margin": min_margin, "length_error": float(max_length_error)})
        check(leg + " knee branch never reverses", min_signed_knee > 0, min_signed_knee)

    for anim in ["idle", "move", "basic_attack"]:
        duration = NOTES["durations"][anim]
        a, b = pose(D, anim, 0), pose(D, anim, duration)
        seam = max(abs(x-y) for bone in a for x, y in zip(a[bone], b[bone]))
        check(anim + " pose returns without seam", seam < 1e-5, seam)
        dt = 1e-5
        velocity_error = 0.0
        for leg in LEGS:
            att = attachment(leg)
            for anchor in uv.values():
                p0 = mesh_uv_point(D, att, anim, 0, anchor)
                p1 = mesh_uv_point(D, att, anim, dt, anchor)
                pe = mesh_uv_point(D, att, anim, duration, anchor)
                pp = mesh_uv_point(D, att, anim, duration-dt, anchor)
                velocity_error = max(velocity_error, float(np.linalg.norm((p1-p0)/dt - (pe-pp)/dt)))
        METRICS[anim + "_visible_foot_seam_velocity_delta_source_px_per_s"] = velocity_error
        check(anim + " visible foot velocity has no material loop jump", velocity_error < 15,
              velocity_error, "< 15 source pixels/second, allowing piecewise-linear baking error")

    # Attack handoff uses the full world matrix; bone-name equality alone is insufficient.
    release = .48
    matrices = pose(D, "basic_attack", release)
    error = float(np.max(np.abs(np.asarray(matrices["flame"]) - matrices["projectile"])))
    check("released fire begins at identical world transform", error < 1e-5, error)
    events = D["animations"]["basic_attack"].get("events", [])
    event_times = [event["time"] for event in events if event["name"] == "release"]
    check("single release event agrees with handoff", event_times == [release], event_times)
    complement = max(abs(alpha("flame", "basic_attack", float(t)) + alpha("projectile", "basic_attack", float(t)) - 1)
                     for t in np.linspace(.479, .48, 21))
    check("fire alpha handoff has no flash or disappearance", complement < 1e-6, complement)
    check("hand fire off and projectile on at release", alpha("flame", "basic_attack", release) == 0 and alpha("projectile", "basic_attack", release) == 1)
    for anim in ["idle", "move", "move_start", "move_stop"]:
        check(anim + " explicitly hides projectile", alpha("projectile", anim, 0) == 0)

    check("input remained unchanged during QA", hashlib.sha256((ROOT / "foxfire-v3.json").read_bytes()).hexdigest() == SOURCE_HASH)
    failures = [item for item in RESULTS if not item["passed"]]
    report = {"status": "failed" if failures else "passed", "scope": "Independent visible-material geometry QA only; not native Spine capture, visual acceptance, or runtime integration acceptance.",
              "input_sha256": SOURCE_HASH,
              "checks": RESULTS, "metrics": METRICS, "findings": FINDINGS}
    (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "checks": len(RESULTS), "failures": failures,
                      "findings": FINDINGS, "metrics": {k: v for k, v in METRICS.items() if "triangle" not in k}}, indent=2))
    return not failures


if __name__ == "__main__":
    raise SystemExit(0 if run() else 1)
