#!/usr/bin/env python3
"""Package a new step pose and repaired recovery with unchanged v4 hand poses.

Bodies are already prepared full-canvas PNGs. This builder never resamples,
recolors or draws a body; it only reuses the fitted v2 FX and packages tracks.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
PRESERVED_BODY_IDS = {0, 2, 3, 5}


def load_helpers(path: Path):
    definition = importlib.util.spec_from_file_location("natural_v2_helpers", path)
    if definition is None:
        raise ValueError("Cannot load v2 packaging helpers")
    module = importlib.util.module_from_spec(definition)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def delta(before: Image.Image, after: Image.Image) -> dict:
    if before.size != after.size:
        raise ValueError("Body canvases must stay identical")
    changed = np.any(np.asarray(before.convert("RGBA")) != np.asarray(after.convert("RGBA")), axis=2)
    ys, xs = np.nonzero(changed)
    return {"changed_pixels": int(changed.sum()),
            "changed_bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
            if len(xs) else None}


def read_body(path: Path, canvas: tuple, palette_rgb: list, helpers) -> Image.Image:
    body = Image.open(path).convert("RGBA")
    if body.size != canvas:
        raise ValueError(f"Body has wrong canvas; resampling is forbidden: {path.name}")
    array = np.asarray(body)
    if set(int(value) for value in np.unique(array[:, :, 3])) != {0, 255}:
        raise ValueError(f"Body must have genuine binary transparency: {path.name}")
    allowed = np.array([helpers.color_code(color) for color in palette_rgb], dtype=np.uint32)
    opaque = array[:, :, 3] == 255
    if not np.all(np.isin(helpers.rgb_codes(array[:, :, :3][opaque]), allowed)):
        raise ValueError(f"Body has RGB outside the original 96-color palette: {path.name}")
    return body


def validate_natural_track(spec: dict, body_ids: set):
    """Validate this expanded track without v2's hardcoded five-body rule."""
    track = spec["track"]
    if [stage["body_frame"] for stage in track] != [0, 6, 2, 3, 3, 3, 4, 5, 0]:
        raise ValueError("Expected the expanded nine-stage track with new body 6")
    for key, expected in (("action_duration", .80), ("preview_extra_idle", .35), ("contact_seconds", .23)):
        if not math.isclose(float(spec[key]), expected, abs_tol=1e-9):
            raise ValueError(f"This batch preserves {key}={expected}")
    previous = -1.0
    for stage in track:
        at, opacity = float(stage["at"]), float(stage["fx_opacity"])
        if stage["body_frame"] not in body_ids or not previous < at < float(spec["action_duration"]):
            raise ValueError("Stage bodies must exist and times must strictly increase")
        if not 0 <= opacity <= 1 or (opacity > 0 and not .20 <= at < .30):
            raise ValueError("FX opacity must remain in its existing short .20-.30 window")
        if stage["body_frame"] == 6 and opacity != 0:
            raise ValueError("The added step-lift pose does not receive a new FX event")
        previous = at
    if float(track[0]["at"]) != 0:
        raise ValueError("The first ready stage must start at zero")
    contact = next(stage for stage in track if stage["body_frame"] == 3)
    if not math.isclose(float(contact["at"]), float(spec["contact_seconds"]), abs_tol=1e-9):
        raise ValueError("First contact pose must remain at .23 seconds")


def load_inputs(root: Path, requested: dict, helpers) -> dict:
    base_v1, base_v2, base_v4 = (root / requested[key] for key in
                                ("base_v1_dir", "base_v2_dir", "base_v4_dir"))
    timing = json.loads((base_v2 / "impact_spec.json").read_text(encoding="utf-8"))
    for key in ("track", "action_duration", "preview_extra_idle", "contact_seconds"):
        if key in requested:
            timing[key] = requested[key]
    canvas = tuple(timing["canvas"])
    original_bodies, original_manifest, original_records = helpers.load_bodies(base_v1, canvas)
    palette = original_manifest["shared_opaque_palette_rgb"]
    previous = json.loads((base_v4 / "manifest.json").read_text(encoding="utf-8"))
    if len(previous["stages"]) != len(previous["track"]):
        raise ValueError("The v4 render count differs from its track")
    inherited = {item["id"]: item for item in previous["patches"]}
    if set(inherited) != {2, 3}:
        raise ValueError("Expected v4's two hand-fixed body overrides")
    bodies, inherited_records = dict(original_bodies), []
    for frame_id in (2, 3):
        item = inherited[frame_id]
        path = base_v4 / item["output_file"]
        actual_hash = helpers.sha256(path)
        if actual_hash != item["output_sha256"]:
            raise ValueError(f"The inherited v4 hand body {frame_id} changed")
        bodies[frame_id] = read_body(path, canvas, palette, helpers)
        inherited_records.append({"id": frame_id, "file": f"{requested['base_v4_dir']}/{item['output_file']}",
                                  "sha256": actual_hash, "rgba_unchanged_from_v4": True})
    override_paths = {int(key): value for key, value in requested["body_overrides"].items()}
    if set(override_paths) != {4, 6}:
        raise ValueError("Only repaired body 4 and new body 6 are allowed in this batch")
    override_records = []
    for frame_id in (4, 6):
        relative = override_paths[frame_id]
        path = root / relative
        replacement = read_body(path, canvas, palette, helpers)
        record = {"id": frame_id, "file": relative, "sha256": helpers.sha256(path),
                  "role": "recovery_override" if frame_id == 4 else "new_step_lift_pose",
                  "resampled": False, "palette_matches_original": True}
        if frame_id == 4:
            record["difference_from_v4_body"] = delta(bodies[4], replacement)
            if not record["difference_from_v4_body"]["changed_pixels"]:
                raise ValueError("The repaired recovery body is unchanged")
        bodies[frame_id] = replacement
        override_records.append(record)
    validate_natural_track(timing, set(bodies))
    trail_path = base_v2 / "fx/trail.png"
    fx_hash = helpers.sha256(trail_path)
    if fx_hash != previous["inputs"]["reused_fx"]["sha256"]:
        raise ValueError("The fitted v2 FX differs from the one used by v4")
    trail = Image.open(trail_path).convert("RGBA")
    if trail.size != canvas:
        raise ValueError("The fitted FX canvas changed; refitting is forbidden")
    before = []
    for stage, entry in zip(previous["stages"], previous["track"]):
        if any(stage[key] != entry[key] for key in ("at", "body_frame", "fx_opacity", "name")):
            raise ValueError("A saved v4 stage disagrees with its source track")
        path = base_v4 / stage["file"]
        if helpers.sha256(path) != stage["sha256"]:
            raise ValueError("A saved v4 RGBA stage changed")
        image = Image.open(path).convert("RGBA")
        if image.size != canvas:
            raise ValueError("A saved v4 RGBA stage has the wrong canvas")
        before.append(image)
    records = {"base_v1_dir": requested["base_v1_dir"], "base_v2_dir": requested["base_v2_dir"],
               "base_v4_dir": requested["base_v4_dir"], "original_v1_bodies": original_records,
               "inherited_v4_hand_bodies": inherited_records, "body_overrides": override_records,
               "unchanged_v1_used_body_ids": [0, 5],
               "reused_fx": {"file": f"{requested['base_v2_dir']}/fx/trail.png", "sha256": fx_hash,
                             "refitted": False, "resampled": False},
               "before_v4_manifest_sha256": helpers.sha256(base_v4 / "manifest.json")}
    return {"timing": timing, "bodies": bodies, "palette": palette, "trail": trail,
            "before_track": previous["track"], "before": before, "inputs": records}


def render_natural(state: dict, helpers):
    timing, before_track = state["timing"], state["before_track"]
    previous_index = {float(stage["at"]): index for index, stage in enumerate(before_track)}
    images, records = [], []
    for index, stage in enumerate(timing["track"]):
        frame_id = stage["body_frame"]
        image, preservation = helpers.composite_stage(state["bodies"][frame_id], state["trail"],
                                                      float(stage["fx_opacity"]))
        selected_before = helpers.sample_track(before_track, float(stage["at"]))
        old_index = previous_index[float(selected_before["at"])]
        difference = delta(state["before"][old_index], image)
        if frame_id in PRESERVED_BODY_IDS:
            if selected_before["body_frame"] != frame_id or difference["changed_pixels"]:
                raise ValueError(f"Preserved body {frame_id} at new stage {index} differs from saved v4 RGBA")
        records.append({**stage, **preservation, "body_preservation_target":
                        "inherited unchanged body" if frame_id in PRESERVED_BODY_IDS else "prepared v5 override/new body",
                        "preserved_body_stage": frame_id in PRESERVED_BODY_IDS,
                        "before_v4_stage_at_same_time": old_index, "difference_from_v4_at_same_time": difference})
        images.append(image)
    if not np.array_equal(np.asarray(images[0]), np.asarray(images[-1])):
        raise ValueError("First and final body0 stages must be identical")
    return images, records


def comparison(state: dict, after: list, helpers):
    new_spec, old_track = state["timing"], state["before_track"]
    new_track = new_spec["track"]
    period = float(new_spec["action_duration"]) + float(new_spec["preview_extra_idle"])
    events = [float(stage["at"]) for stage in old_track + new_track]
    events += [0, float(new_spec["action_duration"]), period]
    boundaries = sorted(set(round(value * 1_000_000) for value in events))
    ticks = [helpers.rounded_tick(value / 1000) for value in boundaries]
    durations = [b - a for a, b in zip(ticks, ticks[1:])]
    if any(value <= 0 for value in durations):
        raise ValueError("A union event interval vanishes at GIF precision")
    old_index = {float(stage["at"]): index for index, stage in enumerate(old_track)}
    new_index = {float(stage["at"]): index for index, stage in enumerate(new_track)}
    width, height = tuple(new_spec["canvas"])
    background = tuple(new_spec["background"])
    frames, before_indices, after_indices = [], [], []
    for value in boundaries[:-1]:
        time = value / 1_000_000
        old = old_index[float(helpers.sample_track(old_track, time)["at"])]
        new = new_index[float(helpers.sample_track(new_track, time)["at"])]
        image = Image.new("RGB", (width * 2, height + helpers.HEADER), background)
        draw = ImageDraw.Draw(image)
        draw.text((12, 10), "V4 BEFORE", fill=helpers.TEXT_COLOR)
        draw.text((width + 12, 10), "V5 NATURAL", fill=helpers.TEXT_COLOR)
        image.paste(helpers.stage_rgb(state["before"][old], background), (0, helpers.HEADER))
        image.paste(helpers.stage_rgb(after[new], background), (width, helpers.HEADER))
        frames.append(image)
        before_indices.append(old)
        after_indices.append(new)
    return frames, {"union_event_boundaries_seconds": [value / 1_000_000 for value in boundaries],
                    "duration_ms": durations, "total_ms": ticks[-1], "left": "v4", "right": "v5",
                    "absolute_time_alignment": True, "same_cycle_seconds": period,
                    "before_stage_indices": before_indices, "after_stage_indices": after_indices,
                    "includes_new_step_event_seconds": next(float(stage["at"]) for stage in new_track
                                                             if stage["body_frame"] == 6)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=ROOT / "natural_spec.json")
    args = parser.parse_args()
    root = args.spec.resolve().parent
    requested = json.loads(args.spec.read_text(encoding="utf-8"))
    helpers = load_helpers(root / requested["base_v2_dir"] / "build_impact.py")
    state = load_inputs(root, requested, helpers)
    timing, background = state["timing"], tuple(state["timing"]["background"])
    images, records = render_natural(state, helpers)
    (root / "render_frames").mkdir(exist_ok=True)
    for index, (image, record) in enumerate(zip(images, records)):
        filename = f"render_frames/{index:02}_{helpers.safe_name(record['name'])}.png"
        image.save(root / filename)
        record.update({"file": filename, "sha256": helpers.sha256(root / filename)})
    width, height = tuple(timing["canvas"])
    atlas = Image.new("RGBA", (width * len(images), height), (0, 0, 0, 0))
    for index, image in enumerate(images):
        atlas.alpha_composite(image, (index * width, 0))
    atlas.save(root / "composite_atlas.png")
    helpers.contact_sheet(images, timing["track"], background).save(root / "contact_sheet.png")
    rgb = [helpers.stage_rgb(image, background) for image in images]
    before_rgb = [helpers.stage_rgb(image, background) for image in state["before"]]
    palette = helpers.ReservedPalette(state["palette"], background, before_rgb + rgb)
    previews = {}
    for filename, factor in (("preview.gif", 1), ("preview_slow.gif", 2)):
        previews[filename] = helpers.save_gif(root / filename, rgb, helpers.timed_track(timing, factor), palette)
    compared, compared_timing = comparison(state, images, helpers)
    previews["comparison.gif"] = helpers.save_gif(root / "comparison.gif", compared, compared_timing, palette)
    manifest = {"schema": "pixel-attack-natural-transition-v5", "character": "guard_monk",
                "status": "standalone_step_and_recovery_candidate", "canvas": timing["canvas"],
                "inputs": state["inputs"], "overridden_existing_body_ids": [4], "inserted_body_ids": [6],
                "preserved_used_body_ids": sorted(PRESERVED_BODY_IDS), "used_body_ids": [0, 2, 3, 4, 5, 6],
                "body_pixels_resampled": False, "fx_reused_without_refit": True,
                "before_v4_track": state["before_track"], "track": timing["track"], "stages": records,
                "contact_seconds": timing["contact_seconds"], "contact_is_preview_metadata_only": True,
                "action_duration_seconds": timing["action_duration"],
                "preview_cycle_seconds": timing["action_duration"] + timing["preview_extra_idle"],
                "first_last_body0_identical": True, "previews": previews,
                "gif_palette": {"exact_body_rgb": state["palette"], "reserved": palette.reserved,
                                "additional_fx_rgb": palette.additional,
                                "only_unreserved_fx_colors_may_be_approximated": True},
                "rgba_alpha_policy": "Body PNGs binary; FX composites may retain partial alpha"}
    helpers.write_json(root / "manifest.json", manifest)
    report = {"result": "structural_packaging_pass", "overridden_existing_body_ids": [4], "inserted_body_ids": [6],
              "preserved_body_ids_rgba_exact_to_saved_v4": sorted(PRESERVED_BODY_IDS),
              "preserved_new_stage_indices": [index for index, record in enumerate(records) if record["preserved_body_stage"]],
              "all_preserved_stages_equal_saved_v4_at_same_time": True,
              "selected_body_opaque_rgba_exact": all(record["body_opaque_rgba_exact"] for record in records),
              "all_bodies_unchanged": False, "body_resampling": False, "fx_refitted": False,
              "render_stage_count": len(images), "distinct_body_pose_count": 6,
              "contact_seconds": timing["contact_seconds"], "action_duration_seconds": timing["action_duration"],
              "preview_cycle_seconds": timing["action_duration"] + timing["preview_extra_idle"],
              "first_last_body0_identical": True, "additional_fx_palette_count": len(palette.additional),
              "total_gif_palette_count": len(palette.colors), "previews": previews,
              "not_verified": ["grip_and_foot_visual_continuity", "owner_approval", "runtime_integration", "gameplay_damage"]}
    helpers.write_json(root / "report.json", report)
    print(json.dumps({"repaired_body": 4, "inserted_body": 6, "render_stages": len(images),
                      "preserved_bodies_equal_v4": sorted(PRESERVED_BODY_IDS),
                      "gif_durations_ms": {key: value["encoded_duration_ms"] for key, value in previews.items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
