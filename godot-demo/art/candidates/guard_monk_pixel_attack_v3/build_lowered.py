#!/usr/bin/env python3
"""Package a single contact-pose override using unchanged v2 timing and FX.

Only body 3 is replaced. All other body PNGs and the fitted v2 FX are read
without resampling. Run with Pillow/NumPy from any working directory.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent


def load_v2_without_cache(path: Path):
    """Use v2 helpers without exec_module's optional bytecode-cache writes."""
    definition = importlib.util.spec_from_file_location("impact_v2_reused_helpers", path)
    if definition is None:
        raise ValueError("Cannot load the v2 helper module")
    module = importlib.util.module_from_spec(definition)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def changed_pixels(before: Image.Image, after: Image.Image) -> dict:
    if before.size != after.size:
        raise ValueError("Comparison requires unchanged canvas sizes")
    changed = np.any(np.asarray(before.convert("RGBA")) != np.asarray(after.convert("RGBA")), axis=2)
    ys, xs = np.nonzero(changed)
    return {"changed_pixels": int(changed.sum()),
            "changed_bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
            if len(xs) else None}


def load_inputs(root: Path, spec: dict, v2):
    if int(spec["override_id"]) != 3:
        raise ValueError("This batch permits only the contact body 3 override")
    base_v1, base_v2 = root / spec["base_v1_dir"], root / spec["base_v2_dir"]
    impact = json.loads((base_v2 / "impact_spec.json").read_text(encoding="utf-8"))
    before_manifest = json.loads((base_v2 / "manifest.json").read_text(encoding="utf-8"))
    bodies, original_manifest, original_records = v2.load_bodies(base_v1, tuple(impact["canvas"]))
    v2.validate_track(impact, set(bodies))
    override_path = root / spec["override_file"]
    override = Image.open(override_path).convert("RGBA")
    if override.size != bodies[3].size:
        raise ValueError("Override canvas differs; body resampling is forbidden")
    array = np.asarray(override)
    if np.any((array[:, :, 3] != 0) & (array[:, :, 3] != 255)):
        raise ValueError("The contact-body override must use binary alpha")
    permitted = np.array([v2.color_code(color) for color in
                          original_manifest["shared_opaque_palette_rgb"]], dtype=np.uint32)
    if not np.all(np.isin(v2.rgb_codes(array[:, :, :3][array[:, :, 3] == 255]), permitted)):
        raise ValueError("Override body contains RGB outside the original 96-color palette")
    delta = changed_pixels(bodies[3], override)
    if delta["changed_pixels"] == 0:
        raise ValueError("The contact override is identical to its original")
    selected = dict(bodies)
    selected[3] = override
    trail_path = base_v2 / "fx/trail.png"
    if v2.sha256(trail_path) != before_manifest["fx"]["sha256"]:
        raise ValueError("The fitted v2 FX hash no longer matches its manifest")
    trail = Image.open(trail_path).convert("RGBA")
    if trail.size != tuple(impact["canvas"]):
        raise ValueError("The fitted v2 FX has the wrong canvas")
    if len(before_manifest["stages"]) != len(impact["track"]):
        raise ValueError("The v2 manifest stage count differs from its original spec")
    before = []
    for old, stage in zip(before_manifest["stages"], impact["track"]):
        if any(old[key] != stage[key] for key in ("at", "body_frame", "fx_opacity", "name")):
            raise ValueError("The v2 stage timing/opacity differs from its original spec")
        path = base_v2 / old["file"]
        if v2.sha256(path) != old["sha256"]:
            raise ValueError(f"An original v2 render changed: {old['file']}")
        before.append(Image.open(path).convert("RGBA"))
    inputs = {"base_v1_dir": spec["base_v1_dir"], "base_v2_dir": spec["base_v2_dir"],
              "original_v1_body_inputs": original_records,
              "override": {"id": 3, "file": spec["override_file"],
                           "sha256": v2.sha256(override_path),
                           "original_sha256": v2.sha256(base_v1 / next(frame["file"] for frame in
                                                                      original_manifest["frames"] if frame["id"] == 3)),
                           "palette_matches_original": True, **delta},
              "reused_fitted_fx": {"file": f"{spec['base_v2_dir']}/fx/trail.png",
                                   "sha256": v2.sha256(trail_path),
                                   "refitted": False, "resampled": False},
              "v2_impact_spec_sha256": v2.sha256(base_v2 / "impact_spec.json")}
    return impact, bodies, selected, original_manifest, trail, before, inputs


def paired_comparison(impact: dict, before: list, after: list, v2):
    """Compare v2 and v3 at the same absolute times on their common 1.15 s cycle."""
    period = float(impact["action_duration"]) + float(impact["preview_extra_idle"])
    events = [float(stage["at"]) for stage in impact["track"]]
    events += [float(impact["action_duration"]), period]
    boundaries = sorted(set(round(value * 1_000_000) for value in events))
    ticks = [v2.rounded_tick(value / 1000) for value in boundaries]
    durations = [b - a for a, b in zip(ticks, ticks[1:])]
    if any(value <= 0 for value in durations):
        raise ValueError("A comparison event interval vanishes at GIF precision")
    width, height = tuple(impact["canvas"])
    background = tuple(impact["background"])
    indices = {float(stage["at"]): index for index, stage in enumerate(impact["track"])}
    frames, chosen = [], []
    for value in boundaries[:-1]:
        stage = v2.sample_track(impact["track"], value / 1_000_000)
        index = indices[float(stage["at"])]
        image = Image.new("RGB", (width * 2, height + v2.HEADER), background)
        draw = ImageDraw.Draw(image)
        draw.text((12, 10), "V2 BEFORE", fill=v2.TEXT_COLOR)
        draw.text((width + 12, 10), "V3 LOWERED", fill=v2.TEXT_COLOR)
        image.paste(v2.stage_rgb(before[index], background), (0, v2.HEADER))
        image.paste(v2.stage_rgb(after[index], background), (width, v2.HEADER))
        frames.append(image)
        chosen.append(index)
    return frames, {"union_event_boundaries_seconds": [value / 1_000_000 for value in boundaries],
                    "duration_ms": durations, "total_ms": ticks[-1],
                    "absolute_time_alignment": True, "same_before_after_track": True,
                    "before_stage_indices": chosen, "after_stage_indices": chosen,
                    "left": "v2", "right": "v3", "extra_cycle_padding_seconds": 0}


def clean_contact_pair(old_body: Image.Image, new_body: Image.Image, background: tuple, v2):
    width, height = old_body.size
    image = Image.new("RGB", (width * 2, height + v2.HEADER), background)
    draw = ImageDraw.Draw(image)
    draw.text((12, 10), "V2 CONTACT / NO FX", fill=v2.TEXT_COLOR)
    draw.text((width + 12, 10), "V3 CONTACT / NO FX", fill=v2.TEXT_COLOR)
    image.paste(v2.stage_rgb(old_body, background), (0, v2.HEADER))
    image.paste(v2.stage_rgb(new_body, background), (width, v2.HEADER))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=ROOT / "lowered_spec.json")
    args = parser.parse_args()
    root = args.spec.resolve().parent
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    v2 = load_v2_without_cache(root / spec["base_v2_dir"] / "build_impact.py")
    impact, old_bodies, bodies, body_manifest, trail, before, inputs = load_inputs(root, spec, v2)
    background, canvas = tuple(impact["background"]), tuple(impact["canvas"])
    (root / "render_frames").mkdir(exist_ok=True)
    rendered, stages = [], []
    for index, stage in enumerate(impact["track"]):
        image, preservation = v2.composite_stage(bodies[stage["body_frame"]], trail, float(stage["fx_opacity"]))
        delta = changed_pixels(before[index], image)
        if stage["body_frame"] != 3 and delta["changed_pixels"]:
            raise ValueError(f"Unchanged body stage {index} differs from the saved v2 RGBA")
        filename = f"render_frames/{index:02}_{v2.safe_name(stage['name'])}.png"
        image.save(root / filename)
        stages.append({**stage, **preservation, "body_preservation_target":
                       "v3 contact override" if stage["body_frame"] == 3 else "unchanged v1 body",
                       "body_is_override": stage["body_frame"] == 3,
                       "unchanged_stage_rgba_equals_v2": delta["changed_pixels"] == 0,
                       "difference_from_v2": delta, "file": filename,
                       "sha256": v2.sha256(root / filename)})
        rendered.append(image)
    atlas = Image.new("RGBA", (canvas[0] * len(rendered), canvas[1]), (0, 0, 0, 0))
    for index, image in enumerate(rendered):
        atlas.alpha_composite(image, (index * canvas[0], 0))
    atlas.save(root / "composite_atlas.png")
    v2.contact_sheet(rendered, impact["track"], background).save(root / "contact_sheet.png")
    clean_contact_pair(old_bodies[3], bodies[3], background, v2).save(root / "contact_before_after.png")
    rgb = [v2.stage_rgb(image, background) for image in rendered]
    before_rgb = [v2.stage_rgb(image, background) for image in before]
    palette = v2.ReservedPalette(body_manifest["shared_opaque_palette_rgb"], background, before_rgb + rgb)
    previews = {}
    for name, factor in (("preview.gif", 1), ("preview_slow.gif", 2)):
        previews[name] = v2.save_gif(root / name, rgb, v2.timed_track(impact, factor), palette)
    compared, timing = paired_comparison(impact, before, rendered, v2)
    previews["comparison.gif"] = v2.save_gif(root / "comparison.gif", compared, timing, palette)
    manifest = {"schema": "pixel-attack-lowered-contact-v3", "character": "guard_monk",
                "status": "standalone_single_contact_override_candidate", "canvas": list(canvas),
                "inputs": inputs, "override_body_ids": [3], "unchanged_body_ids": [0, 1, 2, 4, 5],
                "used_body_ids": [0, 2, 3, 4, 5], "skipped_body_ids": [1],
                "body_pixels_resampled": False, "fx_reused_without_refit": True,
                "track_unchanged_from_v2": True, "track": impact["track"], "stages": stages,
                "contact_seconds": impact["contact_seconds"], "contact_is_preview_metadata_only": True,
                "action_duration_seconds": impact["action_duration"],
                "preview_cycle_seconds": impact["action_duration"] + impact["preview_extra_idle"],
                "previews": previews, "gif_palette": {"exact_body_rgb": body_manifest["shared_opaque_palette_rgb"],
                                                      "reserved": palette.reserved,
                                                      "additional_fx_rgb": palette.additional,
                                                      "only_unreserved_fx_colors_may_be_approximated": True},
                "rgba_alpha_policy": "FX composites can be semitransparent, not claimed binary"}
    v2.write_json(root / "manifest.json", manifest)
    report = {"result": "structural_packaging_pass", "override_body_ids": [3],
              "body_3_differs_from_v1": inputs["override"],
              "other_used_bodies_unchanged_from_v1": [0, 2, 4, 5],
              "unchanged_stage_indices": [i for i, stage in enumerate(stages) if not stage["body_is_override"]],
              "all_unchanged_stage_rgba_equal_saved_v2": True,
              "selected_body_opaque_rgba_preserved_all_stages": all(s["body_opaque_rgba_exact"] for s in stages),
              "all_original_bodies_unchanged": False, "body_resampling": False,
              "fx_hash_matches_v2": True, "fx_refitted": False, "track_unchanged_from_v2": True,
              "render_stage_count": len(stages), "contact_seconds": impact["contact_seconds"],
              "action_duration_seconds": impact["action_duration"],
              "preview_cycle_seconds": impact["action_duration"] + impact["preview_extra_idle"],
              "additional_fx_palette_count": len(palette.additional), "total_gif_palette_count": len(palette.colors),
              "previews": previews,
              "not_verified": ["visual_lowered_staff_quality", "owner_approval", "runtime_integration", "gameplay_damage"]}
    v2.write_json(root / "report.json", report)
    print(json.dumps({"override_body": 3, "render_stages": len(stages),
                      "unchanged_stages_equal_v2": True,
                      "preview_durations_ms": {key: value["encoded_duration_ms"] for key, value in previews.items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
