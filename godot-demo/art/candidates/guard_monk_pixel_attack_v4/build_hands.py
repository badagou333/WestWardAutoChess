#!/usr/bin/env python3
"""Apply imagegen hand edits inside explicit masks and package the v4 candidate.

The original v3 lowered contact pose is inherited before the hand patch.
Only body 2/3 mask pixels may change. v2 timing and fitted FX are reused.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent


def load_without_cache(path: Path, name: str):
    definition = importlib.util.spec_from_file_location(name, path)
    if definition is None:
        raise ValueError(f"Cannot load helpers from {path}")
    module = importlib.util.module_from_spec(definition)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def effective_mask(canvas: tuple, crop_box: list, polygons: list) -> tuple[np.ndarray, int]:
    if len(crop_box) != 4 or any(int(value) != value for value in crop_box):
        raise ValueError("Hand crop_box requires four integer coordinates")
    left, top, right, bottom = crop_box
    if not (0 <= left < right <= canvas[0] and 0 <= top < bottom <= canvas[1]):
        raise ValueError("Hand crop_box is outside the unchanged body canvas")
    if not polygons:
        raise ValueError("At least one explicit hand-edit polygon is required")
    mask = Image.new("L", canvas, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        if len(polygon) < 3 or any(len(point) != 2 for point in polygon):
            raise ValueError("Each hand-edit polygon needs at least three 2D vertices")
        if any(int(value) != value for point in polygon for value in point):
            raise ValueError("Hand-edit polygon vertices must be integer body coordinates")
        draw.polygon([tuple(point) for point in polygon], fill=255)
    requested = np.asarray(mask) != 0
    restriction = np.zeros(requested.shape, dtype=bool)
    restriction[top:bottom, left:right] = True
    selected = requested & restriction
    if not np.any(selected):
        raise ValueError("Hand-edit mask is empty after restricting it to crop_box")
    return selected, int(np.count_nonzero(requested & ~restriction))


def normalize_edit(raw: Image.Image, size: tuple, palette_rgb: list) -> Image.Image:
    """Only normalize the tool crop, never resample the full body PNG."""
    normalized = raw.convert("RGBA").resize(size, Image.Resampling.NEAREST)
    alpha = np.where(np.asarray(normalized.getchannel("A")) >= 128, 255, 0).astype(np.uint8)
    values = [int(value) for color in palette_rgb for value in color]
    palette = Image.new("P", (1, 1))
    palette.putpalette(values + list(palette_rgb[0]) * (256 - len(palette_rgb)))
    mapped = normalized.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    array = np.asarray(mapped).copy()
    array[:, :, 3] = alpha
    array[alpha == 0] = 0
    return Image.fromarray(array)


def apply_hand_patch(base: Image.Image, raw_edit: Image.Image, item: dict,
                     palette_rgb: list, delta_helper) -> tuple:
    left, top, right, bottom = item["crop_box"]
    mask, clipped_mask = effective_mask(base.size, item["crop_box"], item["edit_polygons"])
    region = normalize_edit(raw_edit, (right - left, bottom - top), palette_rgb)
    original = np.asarray(base.convert("RGBA"))
    proposed = original.copy()
    local_mask = mask[top:bottom, left:right]
    destination = proposed[top:bottom, left:right]
    destination[local_mask] = np.asarray(region)[local_mask]
    if not np.array_equal(proposed[~mask], original[~mask]):
        raise ValueError("Hand patch changed a pixel outside its explicit mask")
    if np.any((proposed[:, :, 3] != 0) & (proposed[:, :, 3] != 255)):
        raise ValueError("Hand-patched body must retain binary alpha")
    result = Image.fromarray(proposed)
    delta = delta_helper(base, result)
    if delta["changed_pixels"] == 0:
        raise ValueError(f"Hand patch {item['id']} did not change the selected pixels")
    return result, region, mask, {"id": int(item["id"]), **delta,
                                  "crop_box": item["crop_box"],
                                  "edit_polygons": item["edit_polygons"],
                                  "effective_mask_pixels": int(mask.sum()),
                                  "requested_mask_pixels_outside_crop_discarded": clipped_mask,
                                  "outside_mask_rgba_exact": True,
                                  "outside_mask_changed_pixels": 0,
                                  "tool_raw_canvas": list(raw_edit.size),
                                  "normalized_region_canvas": list(region.size),
                                  "resampling": "nearest", "palette_source": "v1 original 96 colors",
                                  "alpha_values": [int(value) for value in np.unique(proposed[:, :, 3])]}


def load_previous(root: Path, spec: dict, v2):
    base_v1, base_v2, base_v3 = (root / spec[key] for key in
                                ("base_v1_dir", "base_v2_dir", "base_v3_dir"))
    impact = json.loads((base_v2 / "impact_spec.json").read_text(encoding="utf-8"))
    previous_manifest = json.loads((base_v3 / "manifest.json").read_text(encoding="utf-8"))
    bodies, body_manifest, v1_records = v2.load_bodies(base_v1, tuple(impact["canvas"]))
    inherited = previous_manifest["inputs"]["override"]
    if inherited["id"] != 3:
        raise ValueError("Expected v3 to override only lowered contact body 3")
    path = base_v3 / inherited["file"]
    if v2.sha256(path) != inherited["sha256"]:
        raise ValueError("The inherited v3 lowered contact body changed")
    bodies[3] = Image.open(path).convert("RGBA")
    if previous_manifest["track"] != impact["track"]:
        raise ValueError("v3 and v2 no longer have identical timing and FX opacity")
    if len(previous_manifest["stages"]) != len(impact["track"]):
        raise ValueError("v3 render stage count differs from its inherited track")
    v2.validate_track(impact, set(bodies))
    fx_record = previous_manifest["inputs"]["reused_fitted_fx"]
    trail_path = base_v2 / "fx/trail.png"
    if v2.sha256(trail_path) != fx_record["sha256"]:
        raise ValueError("The fitted FX no longer matches the v3 source")
    trail = Image.open(trail_path).convert("RGBA")
    if trail.size != tuple(impact["canvas"]):
        raise ValueError("The fitted FX has the wrong canvas; refitting is forbidden")
    before = []
    for stage, expected in zip(previous_manifest["stages"], impact["track"]):
        if any(stage[key] != expected[key] for key in ("at", "body_frame", "fx_opacity", "name")):
            raise ValueError("A v3 render stage differs from the inherited track")
        path = base_v3 / stage["file"]
        if v2.sha256(path) != stage["sha256"]:
            raise ValueError(f"A saved v3 RGBA stage changed: {stage['file']}")
        before.append(Image.open(path).convert("RGBA"))
    if len(before) != len(impact["track"]):
        raise ValueError("v3 render stage count differs from its inherited track")
    source_records = {"base_v1_dir": spec["base_v1_dir"], "base_v2_dir": spec["base_v2_dir"],
                      "base_v3_dir": spec["base_v3_dir"], "original_v1_bodies": v1_records,
                      "inherited_v3_lowered_contact": inherited,
                      "reused_fx": {"file": f"{spec['base_v2_dir']}/fx/trail.png",
                                    "sha256": v2.sha256(trail_path), "refitted": False},
                      "v2_track_spec_sha256": v2.sha256(base_v2 / "impact_spec.json"),
                      "before_v3_manifest_sha256": v2.sha256(base_v3 / "manifest.json")}
    return impact, bodies, body_manifest, trail, before, source_records


def hand_pairs(items: list, before_bodies: dict, after_bodies: dict, background: tuple, v2):
    ordered = sorted(items, key=lambda item: item["id"])
    cell_width = max((item["crop_box"][2] - item["crop_box"][0]) * 4 for item in ordered)
    cell_height = max((item["crop_box"][3] - item["crop_box"][1]) * 4 for item in ordered)
    sheet = Image.new("RGB", (cell_width * 2, (cell_height + v2.HEADER) * len(ordered)), background)
    draw = ImageDraw.Draw(sheet)
    for row, item in enumerate(ordered):
        frame_id, crop = item["id"], tuple(item["crop_box"])
        label = "ACCELERATE" if frame_id == 2 else "CONTACT"
        for col, (tag, bodies) in enumerate((("V3 BEFORE", before_bodies), ("V4 AFTER", after_bodies))):
            x, y = col * cell_width, row * (cell_height + v2.HEADER)
            draw.text((x + 10, y + 10), f"{label} / {tag}", fill=v2.TEXT_COLOR)
            region = bodies[frame_id].crop(crop)
            enlarged = region.resize((region.width * 4, region.height * 4), Image.Resampling.NEAREST)
            sheet.paste(v2.stage_rgb(enlarged, background), (x, y + v2.HEADER))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=ROOT / "hands_spec.json")
    args = parser.parse_args()
    root = args.spec.resolve().parent
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    v2 = load_without_cache(root / spec["base_v2_dir"] / "build_impact.py", "hands_v2_helpers")
    v3 = load_without_cache(root / spec["base_v3_dir"] / "build_lowered.py", "hands_v3_helpers")
    impact, before_bodies, body_manifest, trail, before, inputs = load_previous(root, spec, v2)
    items = spec["patches"]
    if len(items) != 2 or {item["id"] for item in items} != {2, 3}:
        raise ValueError("Exactly one hand patch for body 2 and body 3 is required")
    palette_rgb = body_manifest["shared_opaque_palette_rgb"]
    bodies, masks, patches = dict(before_bodies), {}, []
    for item in items:
        frame_id = item["id"]
        base_path, edit_path = root / item["base_file"], root / item["edit_file"]
        base = Image.open(base_path).convert("RGBA")
        if not np.array_equal(np.asarray(base), np.asarray(before_bodies[frame_id])):
            raise ValueError(f"Patch {frame_id} base_file is not the selected v3 body")
        raw_edit = Image.open(edit_path).convert("RGBA")
        patched, region, mask, record = apply_hand_patch(base, raw_edit, item, palette_rgb, v3.changed_pixels)
        output = root / item["output_file"]
        if not output.resolve().is_relative_to(root.resolve()):
            raise ValueError("Body output must remain inside the new v4 candidate")
        output.parent.mkdir(parents=True, exist_ok=True)
        patched.save(output)
        normalized_file = f"source/{frame_id}_edit_region.png"
        (root / "source").mkdir(exist_ok=True)
        region.save(root / normalized_file)
        record.update({"base_file": item["base_file"], "base_sha256": v2.sha256(base_path),
                       "edit_file": item["edit_file"], "edit_sha256": v2.sha256(edit_path),
                       "output_file": item["output_file"], "output_sha256": v2.sha256(output),
                       "normalized_region_file": normalized_file,
                       "normalized_region_sha256": v2.sha256(root / normalized_file)})
        bodies[frame_id], masks[frame_id] = patched, mask
        patches.append(record)
    v2.write_json(root / "patch_report.json", {"override_body_ids": [2, 3], "patches": patches,
                                               "body_3_inherits_v3_lowered_pose_before_hand_edit": True,
                                               "all_outside_mask_rgba_exact": True})
    background, canvas = tuple(impact["background"]), tuple(impact["canvas"])
    (root / "render_frames").mkdir(exist_ok=True)
    rendered, stages = [], []
    for index, stage in enumerate(impact["track"]):
        frame_id = stage["body_frame"]
        image, preservation = v2.composite_stage(bodies[frame_id], trail, float(stage["fx_opacity"]))
        difference = v3.changed_pixels(before[index], image)
        if frame_id not in masks and difference["changed_pixels"]:
            raise ValueError(f"Unchanged stage {index} differs from the saved v3 RGBA")
        if frame_id in masks:
            if not np.array_equal(np.asarray(image)[~masks[frame_id]], np.asarray(before[index])[~masks[frame_id]]):
                raise ValueError(f"Rendered stage {index} changed outside its body hand mask")
        filename = f"render_frames/{index:02}_{v2.safe_name(stage['name'])}.png"
        image.save(root / filename)
        stages.append({**stage, **preservation, "body_is_hand_override": frame_id in masks,
                       "body_preservation_target": "v4 hand override" if frame_id in masks else "unchanged v3 body",
                       "difference_from_v3": difference, "outside_hand_mask_rgba_exact_to_v3": True,
                       "file": filename, "sha256": v2.sha256(root / filename)})
        rendered.append(image)
    atlas = Image.new("RGBA", (canvas[0] * len(rendered), canvas[1]), (0, 0, 0, 0))
    for index, image in enumerate(rendered):
        atlas.alpha_composite(image, (index * canvas[0], 0))
    atlas.save(root / "composite_atlas.png")
    v2.contact_sheet(rendered, impact["track"], background).save(root / "contact_sheet.png")
    hand_pairs(items, before_bodies, bodies, background, v2).save(root / "hands_before_after.png")
    rgb = [v2.stage_rgb(image, background) for image in rendered]
    before_rgb = [v2.stage_rgb(image, background) for image in before]
    palette = v2.ReservedPalette(palette_rgb, background, before_rgb + rgb)
    previews = {}
    for name, factor in (("preview.gif", 1), ("preview_slow.gif", 2)):
        previews[name] = v2.save_gif(root / name, rgb, v2.timed_track(impact, factor), palette)
    compared, timing = v3.paired_comparison(impact, before, rendered, v2)
    for image in compared:
        draw = ImageDraw.Draw(image)
        draw.rectangle((0, 0, image.width - 1, v2.HEADER - 1), fill=background)
        draw.text((12, 10), "V3 BEFORE", fill=v2.TEXT_COLOR)
        draw.text((canvas[0] + 12, 10), "V4 HANDS", fill=v2.TEXT_COLOR)
    timing.update({"left": "v3", "right": "v4"})
    previews["comparison.gif"] = v2.save_gif(root / "comparison.gif", compared, timing, palette)
    first_last_equal = np.array_equal(np.asarray(rendered[0]), np.asarray(rendered[-1]))
    if not first_last_equal:
        raise ValueError("First and final ready stages differ")
    manifest = {"schema": "pixel-attack-hand-repair-v4", "character": "guard_monk",
                "status": "standalone_masked_hand_edit_candidate", "canvas": list(canvas),
                "inputs": inputs, "hand_override_body_ids": [2, 3], "patches": patches,
                "body_3_inherits_v3_lowered_pose_before_hand_edit": True,
                "unchanged_used_body_ids": [0, 4, 5], "used_body_ids": [0, 2, 3, 4, 5],
                "body_pixels_resampled": False, "fx_reused_without_refit": True,
                "track_unchanged_from_v2_v3": True, "track": impact["track"], "stages": stages,
                "contact_seconds": impact["contact_seconds"], "contact_is_preview_metadata_only": True,
                "action_duration_seconds": impact["action_duration"],
                "preview_cycle_seconds": impact["action_duration"] + impact["preview_extra_idle"],
                "first_last_ready_identical": first_last_equal, "previews": previews,
                "gif_palette": {"exact_body_rgb": palette_rgb, "reserved": palette.reserved,
                                "additional_fx_rgb": palette.additional,
                                "only_unreserved_fx_colors_may_be_approximated": True},
                "rgba_alpha_policy": "Bodies binary; FX composites may remain semitransparent"}
    v2.write_json(root / "manifest.json", manifest)
    report = {"result": "structural_packaging_pass", "hand_override_body_ids": [2, 3],
              "patches": patches, "all_body_patches_preserve_outside_mask_rgba": True,
              "unchanged_stage_indices": [0, 5, 6, 7], "unchanged_stages_equal_saved_v3_rgba": True,
              "all_rendered_stages_preserve_outside_hand_mask_rgba": True,
              "selected_body_opaque_rgba_exact": all(stage["body_opaque_rgba_exact"] for stage in stages),
              "all_original_bodies_unchanged": False, "body_resampling": False,
              "fx_refitted": False, "track_unchanged_from_v2_v3": True,
              "first_last_ready_identical": first_last_equal, "render_stage_count": len(stages),
              "contact_seconds": impact["contact_seconds"], "action_duration_seconds": impact["action_duration"],
              "preview_cycle_seconds": impact["action_duration"] + impact["preview_extra_idle"],
              "additional_fx_palette_count": len(palette.additional), "total_gif_palette_count": len(palette.colors),
              "previews": previews,
              "not_verified": ["hand_anatomy_visual_quality", "owner_approval", "runtime_integration", "gameplay_damage"]}
    v2.write_json(root / "report.json", report)
    print(json.dumps({"hand_overrides": [2, 3], "patch_pixels": {record["id"]: record["changed_pixels"] for record in patches},
                      "unchanged_stages_equal_v3": True,
                      "gif_durations_ms": {key: value["encoded_duration_ms"] for key, value in previews.items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
