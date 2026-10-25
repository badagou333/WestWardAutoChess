#!/usr/bin/env python3
"""Pack explicit imagegen pose crops into a pixel-art animation candidate.

This file only extracts, aligns, palette-maps and packages existing artwork.
It does not draw, warp, rotate, interpolate or invent character poses.
Run with Python containing Pillow and NumPy, from any working directory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
BACKGROUND = (35, 40, 48)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_sha(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]+", "_", name).strip("_") or "frame"


def seeded_component(mask: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    """Keep precisely the eight-connected opaque component at a local seed."""
    x, y = seed
    height, width = mask.shape
    if not (0 <= x < width and 0 <= y < height):
        raise ValueError("component_seed is outside its explicit source_box")
    if not mask[y, x]:
        raise ValueError("component_seed is transparent at alpha threshold 128")
    selected = np.zeros(mask.shape, dtype=bool)
    selected[y, x] = True
    queue = deque([(x, y)])
    while queue:
        current_x, current_y = queue.popleft()
        for neighbor_y in range(max(0, current_y - 1), min(height, current_y + 2)):
            for neighbor_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                if mask[neighbor_y, neighbor_x] and not selected[neighbor_y, neighbor_x]:
                    selected[neighbor_y, neighbor_x] = True
                    queue.append((neighbor_x, neighbor_y))
    return selected


def validate_track(spec: dict, frame_ids: set[int]) -> list[dict]:
    track = spec["track"]
    duration = float(spec["duration_seconds"])
    if duration <= 0 or not track:
        raise ValueError("A positive duration and a nonempty track are required")
    if track[0]["frame"] != 0 or track[-1]["frame"] != 0:
        raise ValueError("The first and last track entries must reuse frame 0")
    if float(track[0]["at"]) != 0:
        raise ValueError("The first track entry must start at zero")
    previous = -1.0
    for entry in track:
        at = float(entry["at"])
        if entry["frame"] not in frame_ids:
            raise ValueError(f"Unknown frame in track: {entry['frame']}")
        if not previous < at < duration:
            raise ValueError("Track times must increase and remain below duration")
        previous = at
    contact = float(spec["contact_seconds"])
    if not 0 <= contact < duration:
        raise ValueError("Contact reference must be inside the action duration")
    return track


def extract_aligned(spec: dict, root: Path = ROOT) -> tuple[list, list, dict]:
    """Return aligned RGBA images, source records and per-frame metadata."""
    canvas = tuple(int(v) for v in spec["canvas"])
    destination_anchor = tuple(float(v) for v in spec["foot_anchor"])
    if len(canvas) != 2 or min(canvas) <= 0 or len(destination_anchor) != 2:
        raise ValueError("Invalid canvas or destination anchor")
    if not (0 <= destination_anchor[0] <= canvas[0]
            and 0 <= destination_anchor[1] <= canvas[1]):
        raise ValueError("Destination anchor is outside the canvas")

    sources, source_records = {}, []
    for key, entry in spec["sources"].items():
        path = root / entry["file"]
        scale = float(entry["scale"])
        if not math.isfinite(scale) or scale <= 0:
            raise ValueError(f"Invalid source scale: {key}")
        source = Image.open(path).convert("RGBA")
        if source.getchannel("A").getextrema()[0] == 255:
            raise ValueError(f"Source has no genuine transparency: {entry['file']}")
        sources[key] = source
        source_records.append({"id": key, "file": entry["file"],
                               "sha256": sha256(path), "scale": scale,
                               "size": list(source.size)})

    ids = [entry["id"] for entry in spec["frames"]]
    if len(ids) != len(set(ids)) or 0 not in ids:
        raise ValueError("Frame IDs must be unique and include zero")
    validate_track(spec, set(ids))
    images, metadata = [], []
    for entry in spec["frames"]:
        key = entry["source"]
        source = sources[key]
        scale = float(spec["sources"][key]["scale"])
        box = entry["source_box"]
        if len(box) != 4 or any(int(v) != v for v in box):
            raise ValueError(f"Frame {entry['id']} needs an explicit integer crop")
        left, top, right, bottom = (int(v) for v in box)
        if not (0 <= left < right <= source.width
                and 0 <= top < bottom <= source.height):
            raise ValueError(f"Frame {entry['id']} crop is outside its source")
        point = tuple(float(v) for v in entry["source_foot_anchor"])
        if len(point) != 2 or not all(math.isfinite(v) for v in point):
            raise ValueError(f"Invalid source anchor for frame {entry['id']}")
        crop = source.crop((left, top, right, bottom))
        alpha = np.asarray(crop.getchannel("A"))
        foreground = alpha >= 128
        removed_foreign_pixels = 0
        component_seed = entry.get("component_seed")
        if component_seed is not None:
            if len(component_seed) != 2 or any(int(v) != v for v in component_seed):
                raise ValueError(f"Frame {entry['id']} needs an integer component_seed")
            seed = (int(component_seed[0]) - left, int(component_seed[1]) - top)
            selected = seeded_component(foreground, seed)
            removed_foreign_pixels = int(foreground.sum() - selected.sum())
            foreground = selected
        crop.putalpha(Image.fromarray(np.where(foreground, 255, 0).astype("uint8")))
        bounds = crop.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"Frame {entry['id']} has no visible pixels")
        tight = crop.crop(bounds)
        tight_origin = (left + bounds[0], top + bounds[1])
        target_size = (max(1, round(tight.width * scale)),
                       max(1, round(tight.height * scale)))
        resized = tight.resize(target_size, Image.Resampling.NEAREST)
        relative_anchor = ((point[0] - tight_origin[0]) * scale,
                           (point[1] - tight_origin[1]) * scale)
        offset = (round(destination_anchor[0] - relative_anchor[0]),
                  round(destination_anchor[1] - relative_anchor[1]))
        resized_bounds = resized.getchannel("A").getbbox()
        if resized_bounds is None:
            raise ValueError(f"Frame {entry['id']} disappeared at the given scale")
        placed_bounds = [resized_bounds[0] + offset[0],
                         resized_bounds[1] + offset[1],
                         resized_bounds[2] + offset[0],
                         resized_bounds[3] + offset[1]]
        if not (0 <= placed_bounds[0] < placed_bounds[2] <= canvas[0]
                and 0 <= placed_bounds[1] < placed_bounds[3] <= canvas[1]):
            raise ValueError(f"Frame {entry['id']} would clip visible artwork: "
                             f"{placed_bounds} on {canvas}; adjust the explicit spec")
        output = Image.new("RGBA", canvas, (0, 0, 0, 0))
        output.alpha_composite(resized, offset)
        images.append(output)
        touches_crop = (bounds[0] == 0 or bounds[1] == 0
                        or bounds[2] == crop.width or bounds[3] == crop.height)
        metadata.append({"id": entry["id"], "name": entry["name"],
                         "source": key, "source_box": list(box),
                         "component_seed": component_seed,
                         "removed_foreign_opaque_pixels": removed_foreign_pixels,
                         "source_foot_anchor": list(point), "source_scale": scale,
                         "tight_source_bbox": [tight_origin[0], tight_origin[1],
                                               left + bounds[2], top + bounds[3]],
                         "raster_offset": list(offset),
                         "foot_anchor": list(destination_anchor),
                         "anchor_rounding_error_px": [offset[0] + relative_anchor[0]
                                                      - destination_anchor[0],
                                                      offset[1] + relative_anchor[1]
                                                      - destination_anchor[1]],
                         "source_crop_touches_opaque_content": touches_crop})
    return images, metadata, {"sources": source_records, "canvas": list(canvas)}


def shared_palette(images: list[Image.Image], count: int) -> tuple[list, list]:
    """Quantize visible samples together, retaining binary transparent alpha."""
    if not 2 <= count <= 254:
        raise ValueError("palette_colors must be between 2 and 254")
    samples = []
    for image in images:
        array = np.asarray(image)
        samples.append(array[:, :, :3][array[:, :, 3] != 0])
    sample_array = np.concatenate(samples, axis=0).astype("uint8")
    sample_image = Image.fromarray(sample_array.reshape(1, -1, 3))
    palette_image = sample_image.quantize(colors=count, method=Image.Quantize.MEDIANCUT,
                                          dither=Image.Dither.NONE)
    # Fill unused palette slots with an existing color, rather than black;
    # otherwise a near-black source pixel could introduce a 97th color.
    trained_colors = np.unique(np.asarray(palette_image.convert("RGB")).reshape(-1, 3), axis=0)
    entries = [int(v) for color in trained_colors for v in color]
    first_color = [int(v) for v in trained_colors[0]]
    palette_image.putpalette(entries + first_color * (256 - len(trained_colors)))
    output, all_colors = [], set()
    for image in images:
        quantized = image.convert("RGB").quantize(palette=palette_image,
                                                   dither=Image.Dither.NONE).convert("RGBA")
        array = np.asarray(quantized).copy()
        alpha = np.asarray(image.getchannel("A"))
        array[:, :, 3] = alpha
        array[alpha == 0] = 0
        colors = np.unique(array[:, :, :3][alpha != 0], axis=0)
        all_colors.update(tuple(int(v) for v in color) for color in colors)
        output.append(Image.fromarray(array))
    return output, sorted(all_colors)


def make_contact_sheet(images: list, metadata: list, anchor: list) -> Image.Image:
    width, height = images[0].size
    header, columns = 32, 4
    rows = math.ceil(len(images) / columns)
    sheet = Image.new("RGB", (columns * width, rows * (height + header)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for index, (image, record) in enumerate(zip(images, metadata)):
        x, y = (index % columns) * width, (index // columns) * (height + header)
        draw.text((x + 10, y + 10), f"{record['id']:02}  {record['name']}", fill=(235, 229, 210))
        panel = Image.new("RGBA", image.size, (*BACKGROUND, 255))
        guide = ImageDraw.Draw(panel)
        ax, ay = (round(v) for v in anchor)
        guide.line((10, ay, width - 10, ay), fill=(61, 75, 83), width=1)
        guide.line((ax - 4, ay, ax + 4, ay), fill=(96, 154, 165), width=1)
        guide.line((ax, ay - 4, ax, ay + 4), fill=(96, 154, 165), width=1)
        panel.alpha_composite(image)
        sheet.paste(panel.convert("RGB"), (x, y + header))
    return sheet


def round_tick(milliseconds: float) -> int:
    return int(math.floor(milliseconds / 10.0 + 0.5)) * 10


def preview_timing(spec: dict, slow_factor: float = 1.0) -> dict:
    """Round cumulative boundaries to GIF's 10 ms units, rather than intervals."""
    rest = int(spec.get("preview_extra_idle_ms", 350))
    if rest < 0 or slow_factor <= 0:
        raise ValueError("Preview rest and slow factor are invalid")
    track = spec["track"]
    # The first/last use the same ready image. The additional rest belongs
    # after the completed action; contact time is read from the current spec.
    ideal_starts = [float(entry["at"]) * 1000 * slow_factor for entry in track]
    ideal_end = rest + float(spec["duration_seconds"]) * 1000 * slow_factor
    actual_boundaries = [round_tick(v) for v in ideal_starts + [ideal_end]]
    durations = [b - a for a, b in zip(actual_boundaries, actual_boundaries[1:])]
    if any(v <= 0 for v in durations):
        raise ValueError("A track interval vanishes at GIF's 10 ms precision")
    contact_ideal = float(spec["contact_seconds"]) * 1000 * slow_factor
    return {"slow_factor": slow_factor, "extra_idle_ms": rest,
            "frame_ids": [entry["frame"] for entry in track],
            "ideal_start_ms": ideal_starts, "gif_start_ms": actual_boundaries[:-1],
            "gif_frame_duration_ms": durations,
            "ideal_total_ms": ideal_end, "gif_total_ms": actual_boundaries[-1],
            "boundary_rounding_error_ms": [actual - ideal for actual, ideal in
                                            zip(actual_boundaries, ideal_starts + [ideal_end])],
            "contact_reference_ideal_ms": contact_ideal,
            "contact_reference_nearest_tick_ms": round_tick(contact_ideal),
            "contact_is_metadata_only": True}


def preview_frames(images: list, frame_ids: list, track_ids: list, colors: list) -> list:
    """Map binary RGBA frames to exact palette indices, without requantization."""
    palette_colors = [BACKGROUND] + [tuple(color) for color in colors]
    if len(palette_colors) > 256:
        raise ValueError("GIF preview needs at most 255 sprite colors plus its background")
    values = [v for color in palette_colors for v in color]
    palette_values = values + [0] * (768 - len(values))
    color_indices = {(int(red) << 16) | (int(green) << 8) | int(blue): index
                     for index, (red, green, blue) in enumerate(colors, start=1)}
    frames_by_id = {}
    for frame_id, image in zip(frame_ids, images):
        array = np.asarray(image.convert("RGBA"))
        alpha = array[:, :, 3]
        if np.any((alpha != 0) & (alpha != 255)):
            raise ValueError(f"Preview frame {frame_id} does not have binary alpha")
        opaque = alpha == 255
        indices = np.zeros(alpha.shape, dtype=np.uint8)
        if np.any(opaque):
            rgb = array[:, :, :3][opaque].astype(np.uint32)
            packed = (rgb[:, 0] << 16) | (rgb[:, 1] << 8) | rgb[:, 2]
            unique_colors, inverse = np.unique(packed, return_inverse=True)
            missing = [int(color) for color in unique_colors if int(color) not in color_indices]
            if missing:
                examples = [(color >> 16, (color >> 8) & 255, color & 255)
                            for color in missing[:8]]
                raise ValueError(f"Preview frame {frame_id} has RGB absent from the shared palette: "
                                 f"{examples}")
            exact_indices = np.array([color_indices[int(color)] for color in unique_colors],
                                     dtype=np.uint8)
            indices[opaque] = exact_indices[inverse]
        indexed = Image.fromarray(indices)
        indexed.putpalette(palette_values)
        frames_by_id[frame_id] = indexed
    return [frames_by_id[frame_id].copy() for frame_id in track_ids]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, default=ROOT / "frames_spec.json")
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    root = args.spec.resolve().parent
    images, metadata, source_info = extract_aligned(spec, root)
    images, colors = shared_palette(images, int(spec.get("palette_colors", 96)))
    frames_directory = root / "frames"
    frames_directory.mkdir(exist_ok=True)

    for image, record in zip(images, metadata):
        relative_path = f"frames/{record['id']:02}_{safe_name(record['name'])}.png"
        path = root / relative_path
        image.save(path)
        array = np.asarray(image)
        visible = array[:, :, 3] != 0
        bbox = image.getchannel("A").getbbox()
        record.update({"file": relative_path, "sha256": sha256(path),
                       "pixel_sha256": pixel_sha(image), "visible_bbox": list(bbox),
                       "opaque_pixels": int(visible.sum()),
                       "opaque_colors": int(len(np.unique(array[:, :, :3][visible], axis=0))),
                       "alpha_values": [int(v) for v in np.unique(array[:, :, 3])],
                       "transparent_rgb_zero": bool(np.all(array[:, :, :3][~visible] == 0)),
                       "within_canvas": True})

    width, height = images[0].size
    atlas = Image.new("RGBA", (width * len(images), height), (0, 0, 0, 0))
    for index, image in enumerate(images):
        atlas.alpha_composite(image, (index * width, 0))
        metadata[index]["atlas_rect"] = [index * width, 0, width, height]
    atlas.save(root / "atlas.png")
    make_contact_sheet(images, metadata, spec["foot_anchor"]).save(root / "contact_sheet.png")

    previews = {}
    frame_ids = [record["id"] for record in metadata]
    for name, factor in (("preview.gif", 1.0), ("preview_slow.gif", 2.0)):
        timing = preview_timing(spec, factor)
        sequence = preview_frames(images, frame_ids, timing["frame_ids"], colors)
        sequence[0].save(root / name, save_all=True, append_images=sequence[1:],
                         duration=timing["gif_frame_duration_ms"], loop=0,
                         optimize=False, disposal=2)
        with Image.open(root / name) as encoded:
            actual_duration, actual_count = 0, encoded.n_frames
            for index in range(actual_count):
                encoded.seek(index)
                actual_duration += int(encoded.info.get("duration", 0))
        if actual_duration != timing["gif_total_ms"]:
            raise ValueError(f"Encoded GIF duration mismatch: {name}")
        timing.update({"sha256": sha256(root / name), "encoded_frames": actual_count,
                       "encoded_duration_ms": actual_duration})
        previews[name] = timing

    manifest = {"schema": "pixel-attack-candidate-v1", "character": "guard_monk",
                "status": "standalone_animation_candidate_not_runtime_integrated",
                "frame_size": list(images[0].size), "foot_anchor": spec["foot_anchor"],
                "sampling": "nearest", "palette_limit": int(spec.get("palette_colors", 96)),
                "shared_opaque_palette_rgb": colors, "atlas": "atlas.png",
                "atlas_sha256": sha256(root / "atlas.png"),
                "sources": source_info["sources"], "frames": metadata,
                "track": spec["track"], "duration_seconds": spec["duration_seconds"],
                "contact_seconds": spec["contact_seconds"],
                "contact_is_metadata_not_gameplay_damage": True,
                "first_last_reuse_frame": 0, "previews": previews}
    if "reference_motion" in spec:
        manifest["reference_motion"] = spec["reference_motion"]
    write_json(root / "manifest.json", manifest)
    report = {"result": "structural_packaging_pass", "frame_count": len(images),
              "unique_frame_pixel_hashes": len(set(record["pixel_sha256"] for record in metadata)),
              "shared_opaque_colors": len(colors), "canvas": list(images[0].size),
              "all_alpha_binary": all(record["alpha_values"] == [0, 255] for record in metadata),
              "all_transparent_rgb_zero": all(record["transparent_rgb_zero"] for record in metadata),
              "all_visible_content_within_canvas": True,
              "crop_edge_review_required_frame_ids": [record["id"] for record in metadata
                                                       if record["source_crop_touches_opaque_content"]],
              "per_source_uniform_scale": {record["id"]: record["scale"]
                                            for record in source_info["sources"]},
              "first_last_track_frame_identical": spec["track"][0]["frame"] == spec["track"][-1]["frame"] == 0,
              "atlas_sha256": sha256(root / "atlas.png"), "previews": previews,
              "not_verified": ["visual_pose_quality", "ground_contact", "runtime_integration",
                               "gameplay_damage_timing", "owner_final_approval"]}
    write_json(root / "report.json", report)
    print(json.dumps({"frame_count": len(images), "shared_colors": len(colors),
                      "canvas": list(images[0].size), "previews":
                      {name: info["encoded_duration_ms"] for name, info in previews.items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
