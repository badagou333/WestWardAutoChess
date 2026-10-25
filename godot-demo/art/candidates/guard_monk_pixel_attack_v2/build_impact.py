#!/usr/bin/env python3
"""Retiming and separate imagegen-FX packaging; existing body PNGs stay intact.

Read impact_spec.json beside this file (or --spec PATH), then write only into
that spec's directory. Requires Pillow and NumPy. No body pixels are drawn,
warped, resampled or palette-mapped by this script.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
TEXT_COLOR = (237, 230, 211)
HEADER = 32


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def rgb_codes(rgb: np.ndarray) -> np.ndarray:
    rgb = rgb.astype(np.uint32)
    return (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]


def color_code(color) -> int:
    return (int(color[0]) << 16) | (int(color[1]) << 8) | int(color[2])


def unique_colors(colors: list) -> list[tuple]:
    return list(dict.fromkeys(tuple(int(v) for v in color) for color in colors))


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "stage"


def validate_track(spec: dict, body_ids: set) -> list:
    track = spec["track"]
    duration = float(spec["action_duration"])
    if not track or duration <= 0:
        raise ValueError("A nonempty track and positive action_duration are required")
    previous = -1.0
    for stage in track:
        time, opacity = float(stage["at"]), float(stage["fx_opacity"])
        if not (previous < time < duration and 0 <= opacity <= 1):
            raise ValueError("Stage times must increase inside the action; opacity must be 0..1")
        if stage["body_frame"] not in body_ids or stage["body_frame"] == 1:
            raise ValueError("New track must use existing bodies and skip body frame 1")
        if opacity > 0 and not (.20 <= time < .30):
            raise ValueError("The short FX may only be active between .20 and .30 seconds")
        previous = time
    if float(track[0]["at"]) != 0 or track[0]["body_frame"] != 0 or track[-1]["body_frame"] != 0:
        raise ValueError("The new track must start and finish with original body 0")
    if set(stage["body_frame"] for stage in track) != {0, 2, 3, 4, 5}:
        raise ValueError("Expected the five unchanged bodies 0, 2, 3, 4 and 5")
    return track


def load_bodies(base: Path, canvas: tuple) -> tuple[dict, dict, list]:
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    if tuple(manifest["frame_size"]) != canvas:
        raise ValueError("Body canvas does not match; body resampling is forbidden")
    body_colors = unique_colors(manifest["shared_opaque_palette_rgb"])
    permitted_codes = np.array([color_code(color) for color in body_colors], dtype=np.uint32)
    bodies, records = {}, []
    for frame in manifest["frames"]:
        path = base / frame["file"]
        actual_hash = sha256(path)
        if actual_hash != frame["sha256"]:
            raise ValueError(f"Original body hash changed: {frame['file']}")
        body = Image.open(path).convert("RGBA")
        if body.size != canvas:
            raise ValueError(f"Original body has wrong canvas: {frame['file']}")
        array = np.asarray(body)
        if np.any((array[:, :, 3] != 0) & (array[:, :, 3] != 255)):
            raise ValueError("Original bodies need binary alpha for exact foreground preservation")
        opaque_codes = rgb_codes(array[:, :, :3][array[:, :, 3] == 255])
        if not np.all(np.isin(opaque_codes, permitted_codes)):
            raise ValueError(f"Body {frame['id']} has a color outside the original palette")
        bodies[frame["id"]] = body
        records.append({"id": frame["id"], "file": frame["file"], "sha256": actual_hash,
                        "matches_original_manifest": True})
    return bodies, manifest, records


def fit_trail(spec: dict, root: Path, canvas: tuple) -> tuple[Image.Image, dict]:
    item = spec["trail"]
    path = root / item["file"]
    source = Image.open(path).convert("RGBA")
    crop, target = item["crop"], item["target_rect"]
    if any(int(value) != value for value in crop + target):
        raise ValueError("FX crop and target_rect must use integer coordinates")
    left, top, right, bottom = crop
    x0, y0, x1, y1 = target
    if not (0 <= left < right <= source.width and 0 <= top < bottom <= source.height):
        raise ValueError("FX crop is outside the source image")
    if not (0 <= x0 < x1 <= canvas[0] and 0 <= y0 < y1 <= canvas[1]):
        raise ValueError("FX target_rect is outside the candidate canvas")
    clipped = source.crop(tuple(crop))
    amin, amax = clipped.getchannel("A").getextrema()
    if amin == 255 or amax == 0:
        raise ValueError("FX must contain visible artwork and genuine transparent background")
    fitted = clipped.resize((x1 - x0, y1 - y0), Image.Resampling.NEAREST)
    trail = Image.new("RGBA", canvas, (0, 0, 0, 0))
    trail.alpha_composite(fitted, (x0, y0))
    array = np.asarray(trail).copy()
    array[array[:, :, 3] == 0] = 0
    trail = Image.fromarray(array)
    return trail, {"source": item["file"], "source_sha256": sha256(path),
                   "source_canvas": list(source.size), "source_crop": crop,
                   "target_rect": target, "resampling": "nearest",
                   "body_resampling": False}


def composite_stage(body: Image.Image, trail: Image.Image, opacity: float) -> tuple:
    """Only opacity-scale the independent FX and put the unchanged body on top."""
    if body.size != trail.size or not 0 <= opacity <= 1:
        raise ValueError("Invalid stage canvas or opacity")
    if opacity == 0:
        # This preserves even transparent RGB in timing-only stages.
        result = body.copy()
    else:
        effect = np.asarray(trail).copy()
        effect[:, :, 3] = np.floor(effect[:, :, 3].astype(float) * opacity + .5).astype(np.uint8)
        effect[effect[:, :, 3] == 0] = 0
        result = Image.alpha_composite(Image.fromarray(effect), body)
    original, rendered = np.asarray(body), np.asarray(result)
    opaque = original[:, :, 3] == 255
    preserved = bool(np.array_equal(rendered[opaque], original[opaque]))
    if not preserved:
        raise ValueError("FX compositing changed an opaque body pixel")
    return result, {"body_opaque_rgba_exact": preserved,
                    "body_opaque_pixels_checked": int(opaque.sum()),
                    "rgba_alpha_binary": bool(np.all((rendered[:, :, 3] == 0)
                                                       | (rendered[:, :, 3] == 255))),
                    "semi_transparent_pixels": int(np.count_nonzero((rendered[:, :, 3] > 0)
                                                                     & (rendered[:, :, 3] < 255)))}


def stage_rgb(image: Image.Image, background: tuple) -> Image.Image:
    stage = Image.new("RGBA", image.size, (*background, 255))
    stage.alpha_composite(image)
    return stage.convert("RGB")


def rounded_tick(milliseconds: float) -> int:
    return int(math.floor(milliseconds / 10 + .5)) * 10


def timed_track(spec: dict, factor: float = 1) -> dict:
    starts = [float(stage["at"]) * factor * 1000 for stage in spec["track"]]
    end = (float(spec["action_duration"]) * factor + float(spec["preview_extra_idle"])) * 1000
    ticks = [rounded_tick(value) for value in starts + [end]]
    durations = [b - a for a, b in zip(ticks, ticks[1:])]
    if any(value <= 0 for value in durations):
        raise ValueError("A stage vanishes at GIF's 10 ms precision")
    return {"stage_starts_seconds": [value / 1000 for value in starts],
            "duration_ms": durations, "total_ms": ticks[-1], "action_speed_factor": factor,
            "extra_idle_seconds": float(spec["preview_extra_idle"]),
            "boundary_rounding_error_ms": [tick - value for tick, value in zip(ticks, starts + [end])]}


class ReservedPalette:
    """Exact indices for all original colors; only FX's new colors are approximate."""

    def __init__(self, body_colors: list, background: tuple, fx_samples: list):
        self.reserved = unique_colors([background] + body_colors + [TEXT_COLOR])
        self.codes = np.array([color_code(color) for color in self.reserved], dtype=np.uint32)
        self.lookup = {int(code): index for index, code in enumerate(self.codes)}
        samples = []
        for image in fx_samples:
            rgb = np.asarray(image.convert("RGB")).reshape(-1, 3)
            foreign = ~np.isin(rgb_codes(rgb), self.codes)
            if np.any(foreign):
                samples.append(rgb[foreign])
        extras = []
        if samples:
            rgb = np.concatenate(samples, axis=0)
            all_unique = np.unique(rgb, axis=0)
            if len(all_unique) <= 128:
                extras = [tuple(int(v) for v in color) for color in all_unique]
            else:
                trained = Image.fromarray(rgb.reshape(1, -1, 3)).quantize(
                    colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
                extras = [tuple(int(v) for v in color) for color in
                          np.unique(np.asarray(trained.convert("RGB")).reshape(-1, 3), axis=0)]
        self.additional = [color for color in unique_colors(extras) if color not in self.reserved]
        self.colors = self.reserved + self.additional
        if len(self.colors) > 256:
            raise ValueError("Reserved colors plus FX palette exceed GIF's 256 slots")
        values = [v for color in self.colors for v in color]
        self.values = values + list(self.colors[0]) * (256 - len(self.colors))
        self.palette = Image.new("P", (1, 1))
        self.palette.putpalette(self.values)

    def encode(self, image: Image.Image) -> Image.Image:
        rgb = image.convert("RGB")
        values = np.asarray(rgb)
        codes = rgb_codes(values)
        # Approximation here affects only unreserved FX/background mixtures;
        # all original body, background and header colors are overwritten exactly.
        mapped = np.asarray(rgb.quantize(palette=self.palette, dither=Image.Dither.NONE)).copy()
        unique, inverse = np.unique(codes, return_inverse=True)
        indices = np.array([self.lookup.get(int(code), -1) for code in unique], dtype=np.int16)
        exact = indices[inverse].reshape(codes.shape)
        selected = exact >= 0
        mapped[selected] = exact[selected].astype(np.uint8)
        result = Image.fromarray(mapped)
        result.putpalette(self.values)
        decoded = np.asarray(result.convert("RGB"))
        if not np.array_equal(values[selected], decoded[selected]):
            raise ValueError("An original reserved color changed during GIF mapping")
        return result


def save_gif(path: Path, frames: list, timing: dict, palette: ReservedPalette) -> dict:
    indexed = [palette.encode(image) for image in frames]
    indexed[0].save(path, save_all=True, append_images=indexed[1:],
                    duration=timing["duration_ms"], loop=0, optimize=False, disposal=2)
    decoded, ends, elapsed = [], [], 0
    with Image.open(path) as gif:
        for i in range(gif.n_frames):
            gif.seek(i)
            elapsed += int(gif.info.get("duration", 0))
            decoded.append(np.asarray(gif.convert("RGB")).copy())
            ends.append(elapsed)
    if elapsed != timing["total_ms"]:
        raise ValueError(f"GIF duration changed: {path.name}")
    elapsed, checked, maximum_fx_error = 0, 0, 0
    for expected, duration in zip(frames, timing["duration_ms"]):
        index = next(i for i, end in enumerate(ends) if end > elapsed)
        actual, wanted = decoded[index], np.asarray(expected.convert("RGB"))
        exact_mask = np.isin(rgb_codes(wanted), palette.codes)
        if not np.array_equal(actual[exact_mask], wanted[exact_mask]):
            raise ValueError(f"Encoded {path.name} changed an original reserved RGB")
        checked += int(exact_mask.sum())
        if np.any(~exact_mask):
            error = np.abs(actual[~exact_mask].astype(int) - wanted[~exact_mask].astype(int))
            maximum_fx_error = max(maximum_fx_error, int(error.max()))
        elapsed += duration
    return {**timing, "file": path.name, "sha256": sha256(path),
            "requested_samples": len(frames), "encoded_frames": len(decoded),
            "encoded_duration_ms": elapsed, "reserved_rgb_pixels_checked": checked,
            "reserved_rgb_preserved_exactly": True,
            "maximum_unreserved_fx_channel_error": maximum_fx_error}


def sample_track(track: list, time: float) -> dict:
    selected = track[0]
    for stage in track:
        if float(stage["at"]) > time + 1e-9:
            break
        selected = stage
    return selected


def comparison_frames(spec: dict, old_manifest: dict, bodies: dict,
                      rendered: list, background: tuple) -> tuple[list, dict]:
    period = float(spec.get("comparison_period", 1.17))
    old_duration = float(old_manifest["duration_seconds"])
    old_idle = float(old_manifest.get("previews", {}).get("preview.gif", {})
                     .get("extra_idle_ms", 350)) / 1000
    new_period = float(spec["action_duration"]) + float(spec["preview_extra_idle"])
    if period < max(old_duration + old_idle, new_period) - 1e-9:
        raise ValueError("Comparison period cannot truncate either original or new cycle")
    events = [float(item["at"]) for item in old_manifest["track"] + spec["track"]]
    events += [0, old_duration, float(spec["action_duration"]), new_period, period]
    boundaries = sorted(set(round(value * 1_000_000) for value in events
                            if 0 <= value <= period))
    if boundaries[-1] != round(period * 1_000_000):
        boundaries.append(round(period * 1_000_000))
    ticks = [rounded_tick(value / 1000) for value in boundaries]
    durations = [b - a for a, b in zip(ticks, ticks[1:])]
    if any(value <= 0 for value in durations):
        raise ValueError("Comparison union includes intervals below GIF precision")
    width, height = tuple(spec["canvas"])
    frames, old_ids, new_stages = [], [], []
    stage_index = {float(stage["at"]): index for index, stage in enumerate(spec["track"])}
    for value in boundaries[:-1]:
        time = value / 1_000_000
        old = sample_track(old_manifest["track"], time)
        new = sample_track(spec["track"], time)
        image = Image.new("RGB", (width * 2, height + HEADER), background)
        draw = ImageDraw.Draw(image)
        draw.text((12, 10), "BEFORE", fill=TEXT_COLOR)
        draw.text((width + 12, 10), "AFTER", fill=TEXT_COLOR)
        image.paste(stage_rgb(bodies[old["frame"]], background), (0, HEADER))
        new_index = stage_index[float(new["at"])]
        image.paste(stage_rgb(rendered[new_index], background), (width, HEADER))
        frames.append(image)
        old_ids.append(old["frame"])
        new_stages.append(new_index)
    return frames, {"union_event_boundaries_seconds": [value / 1_000_000 for value in boundaries],
                    "duration_ms": durations, "total_ms": ticks[-1],
                    "before_body_frames": old_ids, "after_stage_indices": new_stages,
                    "absolute_time_alignment": True,
                    "new_final_idle_extension_seconds": round(period - new_period, 6)}


def contact_sheet(rendered: list, track: list, background: tuple) -> Image.Image:
    width, height = rendered[0].size
    sheet = Image.new("RGB", (width * 4, (height + HEADER) * math.ceil(len(rendered) / 4)), background)
    draw = ImageDraw.Draw(sheet)
    for index, (image, stage) in enumerate(zip(rendered, track)):
        x, y = index % 4 * width, index // 4 * (height + HEADER)
        label = f"{index:02} BODY {stage['body_frame']} / {float(stage['at']):.2f}s / FX {float(stage['fx_opacity']):.1f}"
        draw.text((x + 10, y + 10), label, fill=TEXT_COLOR)
        sheet.paste(stage_rgb(image, background), (x, y + HEADER))
    return sheet


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=ROOT / "impact_spec.json")
    args = parser.parse_args()
    root = args.spec.resolve().parent
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    canvas, background = tuple(spec["canvas"]), tuple(spec["background"])
    bodies, old_manifest, body_records = load_bodies(root / spec["base_dir"], canvas)
    track = validate_track(spec, set(bodies))
    trail, trail_record = fit_trail(spec, root, canvas)
    (root / "fx").mkdir(exist_ok=True)
    trail.save(root / "fx/trail.png")
    trail_record.update({"file": "fx/trail.png", "sha256": sha256(root / "fx/trail.png")})
    (root / "render_frames").mkdir(exist_ok=True)
    rendered, stage_records = [], []
    for index, stage in enumerate(track):
        image, preservation = composite_stage(bodies[stage["body_frame"]], trail, float(stage["fx_opacity"]))
        filename = f"render_frames/{index:02}_{safe_name(stage['name'])}.png"
        image.save(root / filename)
        rendered.append(image)
        stage_records.append({**stage, **preservation, "file": filename,
                              "sha256": sha256(root / filename)})
    atlas = Image.new("RGBA", (canvas[0] * len(rendered), canvas[1]), (0, 0, 0, 0))
    for index, image in enumerate(rendered):
        atlas.alpha_composite(image, (index * canvas[0], 0))
    atlas.save(root / "composite_atlas.png")
    contact_sheet(rendered, track, background).save(root / "contact_sheet.png")

    normal_rgb = [stage_rgb(image, background) for image in rendered]
    palette = ReservedPalette(old_manifest["shared_opaque_palette_rgb"], background, normal_rgb)
    previews = {}
    previews["preview.gif"] = save_gif(root / "preview.gif", normal_rgb, timed_track(spec), palette)
    previews["preview_slow.gif"] = save_gif(root / "preview_slow.gif", normal_rgb, timed_track(spec, 2), palette)
    timing_only = [stage_rgb(bodies[stage["body_frame"]], background) for stage in track]
    previews["preview_timing_only.gif"] = save_gif(root / "preview_timing_only.gif", timing_only,
                                                 timed_track(spec), palette)
    compared, compared_timing = comparison_frames(spec, old_manifest, bodies, rendered, background)
    previews["comparison.gif"] = save_gif(root / "comparison.gif", compared, compared_timing, palette)

    manifest = {"schema": "pixel-attack-impact-candidate-v2", "character": "guard_monk",
                "status": "standalone_retiming_and_separate_fx_candidate",
                "canvas": list(canvas), "background": list(background), "base_dir": spec["base_dir"],
                "body_inputs": body_records, "body_pixels_resampled": False,
                "used_body_ids": sorted(set(stage["body_frame"] for stage in track)),
                "skipped_original_body_ids": [1], "fx": trail_record,
                "fx_layer_order": "FX behind unchanged original body",
                "fx_active_interval_seconds": [.20, .30],
                "stages": stage_records, "contact_seconds": float(spec.get("contact_seconds", .23)),
                "contact_is_preview_metadata_not_gameplay_damage": True,
                "action_duration_seconds": float(spec["action_duration"]),
                "preview_cycle_seconds": float(spec["action_duration"]) + float(spec["preview_extra_idle"]),
                "before_track": old_manifest["track"], "before_action_duration_seconds": old_manifest["duration_seconds"],
                "after_track": track, "previews": previews,
                "gif_palette": {"original_body_colors": old_manifest["shared_opaque_palette_rgb"],
                                "exact_reserved_colors": palette.reserved,
                                "additional_fx_colors": palette.additional,
                                "quantization_policy": "Only unreserved FX mixtures may be approximated; all reserved RGB exact"},
                "composite_alpha_policy": "RGBA may retain semitransparent FX; not claimed binary"}
    write_json(root / "manifest.json", manifest)
    report = {"result": "structural_packaging_pass", "body_input_hashes_match": True,
              "body_opaque_rgba_exact_all_stages": all(stage["body_opaque_rgba_exact"] for stage in stage_records),
              "body_resampling": False, "used_body_ids": manifest["used_body_ids"], "skipped_body_ids": [1],
              "render_stage_count": len(rendered), "body_pose_count": len(manifest["used_body_ids"]),
              "contact_seconds": manifest["contact_seconds"],
              "action_duration_seconds": manifest["action_duration_seconds"],
              "preview_cycle_seconds": manifest["preview_cycle_seconds"],
              "fx_interval_seconds": [.20, .30], "rgba_composites_not_assumed_binary": True,
              "original_body_palette_count": len(unique_colors(old_manifest["shared_opaque_palette_rgb"])),
              "additional_fx_palette_count": len(palette.additional), "total_gif_palette_count": len(palette.colors),
              "all_reserved_gif_rgb_exact": all(item["reserved_rgb_preserved_exactly"] for item in previews.values()),
              "previews": previews,
              "not_verified": ["visual_impact_quality", "owner_approval", "runtime_integration", "gameplay_damage_events"]}
    write_json(root / "report.json", report)
    print(json.dumps({"render_stages": len(rendered), "body_poses": manifest["used_body_ids"],
                      "palette_colors": len(palette.colors),
                      "gif_durations_ms": {key: item["encoded_duration_ms"] for key, item in previews.items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
