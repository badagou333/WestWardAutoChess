"""Verify a fixed authored flow; this does not exercise a runtime animation mixer."""
import hashlib
import json
import math
from pathlib import Path

import numpy as np

from check_rig import material_triangles, areas
from render_preview import mesh_points, mesh_uv_point, pose, sample

ROOT = Path(__file__).resolve().parent
SOURCE_BYTES = (ROOT / "foxfire-v3.json").read_bytes()
QA_BYTES = (ROOT / "foxfire-v3-qa.json").read_bytes()
DATA, QA = json.loads(SOURCE_BYTES), json.loads(QA_BYTES)
NOTES = json.loads((ROOT / "rig-notes.json").read_text())
FLOW = json.loads((ROOT / "flow-sequence.json").read_text())
SEGMENTS = FLOW["segments"]
RESULTS, METRICS = [], {}


def check(name, passed, actual=None, criterion=None):
    record = {"check": name, "passed": bool(passed)}
    if actual is not None:
        record["actual"] = actual
    if criterion is not None:
        record["criterion"] = criterion
    RESULTS.append(record)


def slot_alpha(data, anim, slot, t):
    default = next(s for s in data["slots"] if s["name"] == slot).get("color", "ffffffff")
    return sample(data["animations"][anim].get("slots", {}).get(slot, {}).get("alpha"),
                  t, "value", int(default[-2:], 16) / 255)


def segment_at(t):
    return next(segment for segment in reversed(SEGMENTS) if segment["at"] <= t + 1e-9)


def matrices_error(a, b):
    return max(abs(v-w) for name in a for v, w in zip(a[name], b[name]))


def root_reference_x(t):
    """Move left only during walk clips, retaining accumulated displacement.

    Start/stop are the authored stationary foot-placement transitions. This is
    an explicit QA reference, not gameplay displacement or a runtime contract.
    """
    return -NOTES["speed_source_px_per_second"] * sum(
        max(0, min(segment["duration"], t-segment["at"]))
        for segment in SEGMENTS if segment["animation"] == "move")


def expected_support(segment, t, leg, index):
    anim = segment["animation"]
    local = max(0, min(segment["duration"], t-segment["at"]))
    if anim == "move":
        phase = (local / NOTES["cycle_seconds"] + NOTES["legs"][leg]["phase"]) % 1
        return phase <= NOTES["stance_fraction"]
    if anim in ["move_start", "move_stop"]:
        phase = local / segment["duration"]
        return phase <= index * .5 or phase >= (index+1) * .5
    return True


def run():
    for name in DATA["animations"]:
        check(name + " unmodified in QA input", DATA["animations"][name] == QA["animations"][name])
    check("same setup rig and attachments", all(DATA[key] == QA[key] for key in ["bones", "slots", "skins", "skeleton"]))
    switches = sum(a["animation"] != b["animation"] for a, b in zip(SEGMENTS, SEGMENTS[1:]))
    check("declared state-change count is accurate", switches == FLOW["switches"], switches)
    final = SEGMENTS[-1]
    check("declared flow duration is accurate", abs(final["at"] + final["duration"] - FLOW["duration"]) < 1e-7)

    boundary_errors, source_errors = [], []
    for index, segment in enumerate(SEGMENTS):
        name, start, duration = segment["animation"], segment["at"], segment["duration"]
        hold = segment["hold_neutral"]
        source_error = 0.0
        for local in np.linspace(0, duration, 9):
            expected = pose(DATA, name, 0 if hold else float(local))
            actual = pose(QA, "qa_flow", start + float(local))
            source_error = max(source_error, matrices_error(expected, actual))
        source_errors.append(source_error)
        check(f"segment {index} {name} preserves source poses", source_error < 2e-4, source_error)
        for slot in ["flame", "projectile"]:
            error = max(abs(slot_alpha(DATA, name, slot, 0 if hold else float(local)) -
                            slot_alpha(QA, "qa_flow", slot, start+float(local)))
                        for local in np.linspace(0, duration, 17))
            check(f"segment {index} {name} preserves {slot} visibility", error < 2e-5, error)
        if index:
            previous = SEGMENTS[index-1]
            outgoing = pose(DATA, previous["animation"], 0 if previous["hold_neutral"] else previous["duration"])
            incoming = pose(DATA, name, 0)
            error = matrices_error(outgoing, incoming)
            boundary_errors.append(error)
            check(f"boundary {index} {previous['animation']} to {name} has matching pose", error < 1e-5, error)
    METRICS["max_source_pose_error"] = max(source_errors)
    METRICS["max_boundary_matrix_error"] = max(boundary_errors)
    seam = matrices_error(pose(QA, "qa_flow", 0), pose(QA, "qa_flow", FLOW["duration"]))
    check("whole authored flow loops without a pose jump", seam < 1e-5, seam)

    # Alpha-visible triangle bounds, plus inter-frame change at actual 60 Hz.
    skin = QA["skins"][0]["attachments"]
    times = np.linspace(0, FLOW["duration"], round(FLOW["duration"]*60)+1)
    for slot, variants in skin.items():
        for attachment_name, att in variants.items():
            if att.get("type") != "mesh":
                continue
            ids = np.asarray(att["triangles"]).reshape(-1, 3)
            visible, _ = material_triangles(att)
            material_vertices = np.unique(ids[visible])
            rest_area = areas(mesh_points(QA, att, "", 0), ids)
            minimum, maximum_step, previous = 1.0, 0.0, None
            for t in times:
                points = mesh_points(QA, att, "qa_flow", float(t))
                minimum = min(minimum, float((areas(points, ids)/rest_area)[visible].min()))
                if previous is not None:
                    maximum_step = max(maximum_step, float(np.linalg.norm(points[material_vertices] - previous[material_vertices], axis=1).max())*.085)
                previous = points
            METRICS[slot + "_flow_min_visible_area_ratio"] = minimum
            METRICS[slot + "_max_60hz_visible_vertex_step_game_px"] = maximum_step
            check(slot + " visible flow mesh retains area", minimum > .35, minimum, "visible-material area ratio > .35")
            check(slot + " has no large inter-frame mesh jump", maximum_step < 2, maximum_step, "< 2 game pixels per 60 Hz step at .085 source scale")

    # Contact landmark comes from alpha >= 128, independently of rectangle edges.
    from PIL import Image
    pixels = np.asarray(Image.open(ROOT / "images/leg-left.png").convert("RGBA"))
    y = int(np.where(pixels[:, :, 3] >= 128)[0].max())
    x = int(np.median(np.where(pixels[y, :, 3] >= 128)[0]))
    contact_uv = np.array([x, y]) / [pixels.shape[1], pixels.shape[0]]
    METRICS["actual_contact_image_pixels"] = [x, y]
    heights = []
    for index, leg in enumerate(NOTES["legs"]):
        att = skin[leg][leg]
        base = mesh_uv_point(QA, att, "", 0, contact_uv)
        points = np.array([mesh_uv_point(QA, att, "qa_flow", float(t), contact_uv) for t in times])
        height = points[:, 1] - base[1]
        heights.append(height)
        check(leg + " contact never materially penetrates ground", float(height.min()) > -.25,
              float(height.min()), "> -.25 source pixel in its own perspective lane")
        support = np.array([expected_support(segment_at(float(t)), float(t), leg, index) for t in times])
        indices = np.flatnonzero(support)
        groups = np.split(indices, np.where(np.diff(indices)>1)[0]+1)
        drift = 0.0
        reference = points.copy()
        reference[:, 0] += [root_reference_x(float(t)) for t in times]
        for group in groups:
            if len(group):
                drift = max(drift, float(np.ptp(reference[group], axis=0).max()))
        METRICS[leg + "_flow_visible_stance_drift_source_px"] = drift
        check(leg + " planted contact is stable across authored state changes", drift < .3, drift,
              "< .3 source pixel with explicitly accumulated walk-only displacement")
        toe = np.array(NOTES["visible_landmarks_image_px"]["toe"]) / [pixels.shape[1], pixels.shape[0]]
        heel = np.array(NOTES["visible_landmarks_image_px"]["heel"]) / [pixels.shape[1], pixels.shape[0]]
        forward = max(float((mesh_uv_point(QA, att, "qa_flow", float(t), toe) -
                             mesh_uv_point(QA, att, "qa_flow", float(t), heel))[0]) for t in times)
        check(leg + " paw facing stays consistent throughout flow", forward < -30, forward)
    both_air = float(np.min(np.array(heights), axis=0).max())
    check("authored flow never lifts both feet together", both_air < .25, both_air)

    expected_events = [(round(segment["at"]+event["time"], 7), event["name"])
                       for segment in SEGMENTS if not segment["hold_neutral"]
                       for event in DATA["animations"][segment["animation"]].get("events", [])]
    actual_events = [(event["time"], event["name"]) for event in QA["animations"]["qa_flow"].get("events", [])]
    check("flow preserves exact source event times", actual_events == expected_events, actual_events)
    for release, event in actual_events:
        if event != "release":
            continue
        matrices = pose(QA, "qa_flow", release)
        error = float(np.max(np.abs(np.array(matrices["flame"])-matrices["projectile"])))
        check(f"fire release at {release}s has matching world transforms", error < 2e-5, error)
        complement = max(abs(slot_alpha(QA, "qa_flow", "flame", float(t))+
                             slot_alpha(QA, "qa_flow", "projectile", float(t))-1)
                         for t in np.linspace(release-.001, release, 11))
        check(f"fire release at {release}s preserves alpha handoff", complement < 1e-6, complement)

    check("input files unchanged during flow check", SOURCE_BYTES == (ROOT/"foxfire-v3.json").read_bytes() and QA_BYTES == (ROOT/"foxfire-v3-qa.json").read_bytes())
    failures = [item for item in RESULTS if not item["passed"]]
    report = {"status": "failed" if failures else "passed",
              "scope": "Fixed, authored qa_flow only; not a general runtime mixer, arbitrary interruption test, native capture, or visual acceptance.",
              "source_sha256": hashlib.sha256(SOURCE_BYTES).hexdigest(),
              "qa_sha256": hashlib.sha256(QA_BYTES).hexdigest(),
              "duration": FLOW["duration"], "state_changes": switches,
              "checks": RESULTS, "metrics": METRICS}
    (ROOT/"flow-validation.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"status": report["status"], "checks": len(RESULTS), "failures": failures, "metrics": METRICS}, indent=2))
    return not failures


if __name__ == "__main__":
    raise SystemExit(0 if run() else 1)
