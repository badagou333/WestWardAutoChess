#!/usr/bin/env python3
"""Data-driven, standalone attack-art extraction and playback packaging.

Run with Pillow and NumPy: build_attack.py --spec /absolute/character/spec.json
All outputs stay beside that spec. Body art is extracted at one shared source
scale and palette-mapped as a group. Independent RGBA layers stay behind the
body; this initial schema intentionally does not support foreground overlays.
Structural results are never a substitute for pose/transition visual review.
"""

from __future__ import annotations

import argparse
from collections import deque
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw


SCHEMA = "pixel-attack-series-v1"
DEFAULT_BACKGROUND = (35, 40, 48)
TEXT_COLOR = (237, 230, 211)
HEADER = 30


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_hash(path: Path) -> str:
    return digest(path.read_bytes())


def pixel_hash(image: Image.Image) -> str:
    return digest(image.convert("RGBA").tobytes())


def identifier(value) -> str:
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise ValueError("IDs must be strings or integers")
    result = str(value)
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", result):
        raise ValueError(f"Unsafe ID for an output filename: {result!r}")
    return result


def integer(value, label: str, minimum: int = 0) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or int(value) != value:
        raise ValueError(f"{label} must be an integer")
    value = int(value)
    if value < minimum:
        raise ValueError(f"{label} must be at least {minimum}")
    return value


def rgb_codes(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.uint32)
    return (values[..., 0] << 16) | (values[..., 1] << 8) | values[..., 2]


def code(color) -> int:
    return (int(color[0]) << 16) | (int(color[1]) << 8) | int(color[2])


def ordered_colors(colors) -> list[tuple]:
    return list(dict.fromkeys(tuple(int(v) for v in color) for color in colors))


def output_path(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("Output escapes the character spec directory")
    return path


def write_json(path: Path, value: dict):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def webp_is_lossless(data: bytes) -> bool:
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return False
    offset, found = 12, False
    while offset + 8 <= len(data):
        kind = data[offset:offset + 4]
        size = int.from_bytes(data[offset + 4:offset + 8], "little")
        if offset + 8 + size > len(data):
            return False
        if kind == b"VP8 ":
            return False
        found |= kind == b"VP8L"
        offset += 8 + size + size % 2
    return found


def decode_source(data: bytes, label: str, expected_pixel_sha256=None) -> tuple:
    """Accept static PNG or lossless WebP and expose a decoded-pixel audit hash."""
    with Image.open(BytesIO(data)) as opened:
        kind = opened.format
        if kind not in {"PNG", "WEBP"} or getattr(opened, "n_frames", 1) != 1:
            raise ValueError(f"{label}: use a static PNG or lossless WebP")
        if kind == "WEBP" and not webp_is_lossless(data):
            raise ValueError(f"{label}: lossy WebP is not accepted")
        image = opened.convert("RGBA")
    actual = pixel_hash(image)
    if expected_pixel_sha256 is not None and actual != expected_pixel_sha256:
        raise ValueError(f"{label}: decoded RGBA pixels differ from the expected hash")
    return image, {"file": label, "format": kind, "size": list(image.size),
                   "sha256": digest(data), "rgba_pixel_sha256": actual,
                   "expected_pixel_hash_verified": expected_pixel_sha256 is not None,
                   "lossless_storage": True}


def read_image(root: Path, entry: dict) -> tuple:
    path = root / entry["file"]
    data = path.read_bytes()
    if entry.get("sha256") is not None and digest(data) != entry["sha256"]:
        raise ValueError(f"Source file hash changed: {entry['file']}")
    return decode_source(data, entry["file"], entry.get("expected_pixel_sha256"))


def source_box(value, size: tuple) -> tuple:
    if not isinstance(value, (list, tuple)) or len(value) != 4:
        raise ValueError("An explicit source_box/crop of four integers is required")
    left, top, right, bottom = (integer(v, "crop coordinate") for v in value)
    if not (left < right <= size[0] and top < bottom <= size[1]):
        raise ValueError("Explicit source crop is outside its image")
    return left, top, right, bottom


def component_union(mask: np.ndarray, seeds: list | None) -> tuple:
    """Select a union, never an automatic largest component or a single seed only."""
    if seeds is None:
        return mask.copy(), [], 0
    if not seeds:
        raise ValueError("component_seeds must be omitted or contain at least one seed")
    height, width = mask.shape
    selected = np.zeros(mask.shape, dtype=bool)
    components, duplicate_seeds = [], 0
    for point in seeds:
        if len(point) != 2:
            raise ValueError("Each component seed needs x/y coordinates")
        x, y = (integer(v, "component seed") for v in point)
        if not (x < width and y < height) or not mask[y, x]:
            raise ValueError("Component seed is outside the crop or below its alpha threshold")
        if selected[y, x]:
            duplicate_seeds += 1
            continue
        component = np.zeros(mask.shape, dtype=bool)
        component[y, x] = selected[y, x] = True
        queue = deque([(x, y)])
        while queue:
            px, py = queue.popleft()
            for ny in range(max(0, py - 1), min(height, py + 2)):
                for nx in range(max(0, px - 1), min(width, px + 2)):
                    if mask[ny, nx] and not selected[ny, nx]:
                        component[ny, nx] = selected[ny, nx] = True
                        queue.append((nx, ny))
        components.append(component)
    return selected, components, duplicate_seeds


def crop_cuts_component(full_mask: np.ndarray, selected: np.ndarray, box: tuple) -> bool:
    left, top, right, bottom = box
    height, width = selected.shape
    border = selected.copy()
    if height > 2 and width > 2:
        border[1:-1, 1:-1] = False
    for y, x in np.argwhere(border):
        gx, gy = left + int(x), top + int(y)
        if gx in (0, full_mask.shape[1] - 1) or gy in (0, full_mask.shape[0] - 1):
            return True
        for ny in range(gy - 1, gy + 2):
            for nx in range(gx - 1, gx + 2):
                if not (left <= nx < right and top <= ny < bottom) and full_mask[ny, nx]:
                    return True
    return False


def visible_bounds(image: Image.Image):
    return image.getchannel("A").getbbox()


def require_fits(bounds, offset: tuple, canvas: tuple, label: str):
    if bounds is None:
        return
    result = (bounds[0] + offset[0], bounds[1] + offset[1],
              bounds[2] + offset[0], bounds[3] + offset[1])
    if not (0 <= result[0] < result[2] <= canvas[0] and 0 <= result[1] < result[3] <= canvas[1]):
        raise ValueError(f"{label}: visible pixels would leave the canvas: {result}")


def extract(image: Image.Image, entry: dict, scale: float, canvas: tuple, anchor: tuple,
            binary_body: bool = True) -> tuple:
    """Apply one fixed source scale and source-anchor transform, never height fitting."""
    box = source_box(entry.get("source_box"), image.size)
    left, top, right, bottom = box
    point = entry.get("source_anchor")
    if point is None or len(point) != 2 or not all(math.isfinite(float(v)) for v in point):
        raise ValueError("source_anchor must explicitly provide two finite source coordinates")
    if binary_body and image.getchannel("A").getextrema()[0] == 255:
        raise ValueError("A body source needs genuine transparency; no background is inferred")
    full_alpha = np.asarray(image.getchannel("A"))
    full_mask = full_alpha >= (128 if binary_body else 1)
    mask = full_mask[top:bottom, left:right]
    global_seeds = entry.get("component_seeds")
    local_seeds = None if global_seeds is None else [[integer(p[0], "seed x") - left,
                                                    integer(p[1], "seed y") - top] for p in global_seeds]
    selected, components, repeated = component_union(mask, local_seeds)
    if not np.any(selected):
        raise ValueError("Selected source crop is empty")
    cut = crop_cuts_component(full_mask, selected, box)
    if binary_body and cut:
        raise ValueError("Explicit body crop cuts a selected component or source-edge artwork; expand the crop")
    crop = image.crop(box)
    alpha = np.where(selected, 255 if binary_body else full_alpha[top:bottom, left:right], 0).astype(np.uint8)
    crop.putalpha(Image.fromarray(alpha))
    tight_box = visible_bounds(crop)
    tight = crop.crop(tight_box)
    target = (max(1, round(tight.width * scale)), max(1, round(tight.height * scale)))
    resized = tight.resize(target, Image.Resampling.NEAREST)
    if visible_bounds(resized) is None:
        raise ValueError("Selected source artwork disappears at the fixed scale")
    # Every requested disconnected part must survive the chosen sampling scale.
    retained = []
    for component in components:
        part = Image.fromarray((component * 255).astype(np.uint8)).crop(tight_box).resize(target, Image.Resampling.NEAREST)
        count = int(np.count_nonzero(np.asarray(part)))
        if count == 0:
            raise ValueError("A selected component disappears at the fixed scale")
        retained.append(count)
    origin = (left + tight_box[0], top + tight_box[1])
    relative_anchor = ((float(point[0]) - origin[0]) * scale, (float(point[1]) - origin[1]) * scale)
    offset = (round(anchor[0] - relative_anchor[0]), round(anchor[1] - relative_anchor[1]))
    require_fits(visible_bounds(resized), offset, canvas, "Source extraction")
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))
    result.alpha_composite(resized, offset)
    array = np.asarray(result).copy()
    array[array[:, :, 3] == 0] = 0
    result = Image.fromarray(array)
    return result, {"source_box": list(box), "source_anchor": list(point), "scale": scale,
                    "component_seeds": global_seeds, "selection": "seed_union_8" if global_seeds is not None else "all_explicit_crop_alpha",
                    "selected_components": len(components) if global_seeds is not None else None,
                    "duplicate_seeds": repeated, "removed_unselected_opaque_pixels": int(mask.sum() - selected.sum()),
                    "selected_components_pixels_after_scale": retained,
                    "source_crop_cuts_component": cut, "raster_offset": list(offset),
                    "anchor_rounding_error_px": [offset[i] + relative_anchor[i] - anchor[i] for i in (0, 1)],
                    "visible_bbox": list(visible_bounds(result)), "body_alpha_binary": binary_body}


def train_body_palette(images: list, limit: int) -> tuple:
    if not 1 <= limit <= 128:
        raise ValueError("palette_colors must be between 1 and 128")
    samples = [np.asarray(image)[:, :, :3][np.asarray(image)[:, :, 3] == 255] for image in images]
    rgb = np.concatenate(samples, axis=0)
    if len(rgb) == 0:
        raise ValueError("The body group contains no visible pixels")
    unique_source = np.unique(rgb, axis=0)
    if len(unique_source) <= limit:
        palette_rgb = unique_source
    else:
        trained = Image.fromarray(rgb.reshape(1, -1, 3)).quantize(
            colors=limit, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        palette_rgb = np.unique(np.asarray(trained.convert("RGB")).reshape(-1, 3), axis=0)
    # Pillow's fixed-palette matching uses a coarse cache that can merge
    # distinct near-black colors even when those exact colors are in its
    # palette. Assign unique RGBs by exact nearest distance instead.
    centers = palette_rgb.astype(np.int32)
    output, actual_colors = [], set()
    for image in images:
        original = np.asarray(image)
        alpha = original[:, :, 3]
        visible = alpha == 255
        source_colors, inverse = np.unique(original[:, :, :3][visible], axis=0, return_inverse=True)
        nearest = []
        for start in range(0, len(source_colors), 4096):
            difference = source_colors[start:start + 4096].astype(np.int32)[:, None, :] - centers[None, :, :]
            nearest.extend(np.argmin(np.sum(difference * difference, axis=2), axis=1))
        array = np.zeros(original.shape, dtype=np.uint8)
        array[:, :, 3] = alpha
        array[:, :, :3][visible] = palette_rgb[np.asarray(nearest, dtype=int)][inverse]
        actual_colors.update(tuple(int(v) for v in color) for color in
                             np.unique(array[:, :, :3][alpha == 255], axis=0))
        output.append(Image.fromarray(array))
    return output, sorted(actual_colors)


def external_layer(image: Image.Image, item: dict, canvas: tuple) -> tuple:
    if item.get("order", "behind") != "behind":
        raise ValueError("This schema supports layers behind the body only")
    if "crop" not in item and "target_rect" not in item:
        if image.size != canvas:
            raise ValueError("An original-size RGBA layer must match canvas, or declare crop and target_rect")
        return image.copy(), {"copied_at_original_size": True, "resampled": False}
    box = source_box(item.get("crop"), image.size)
    target = source_box(item.get("target_rect"), canvas)
    cropped = image.crop(box)
    fitted = cropped.resize((target[2] - target[0], target[3] - target[1]), Image.Resampling.NEAREST)
    result = Image.new("RGBA", canvas, (0, 0, 0, 0))
    result.alpha_composite(fitted, (target[0], target[1]))
    return result, {"crop": list(box), "target_rect": list(target), "resampling": "nearest", "resampled": True}


def normalized_track(spec: dict, bodies: dict, layers: dict) -> tuple:
    duration = integer(spec["duration_ms"], "duration_ms", 1)
    idle = integer(spec.get("idle_ms", 0), "idle_ms")
    if not spec.get("track"):
        raise ValueError("A nonempty animation track is required")
    result, previous = [], -1
    for item in spec["track"]:
        at = integer(item["at_ms"], "at_ms")
        body = identifier(item["body"])
        if not previous < at < duration or body not in bodies:
            raise ValueError("Track times must increase inside duration_ms and reference known bodies")
        stage_layers = []
        for overlay in item.get("layers", []):
            layer = identifier(overlay["id"])
            opacity = float(overlay.get("opacity", 1))
            offset = overlay.get("offset", [0, 0])
            if layer not in layers or not math.isfinite(opacity) or not 0 <= opacity <= 1 or len(offset) != 2:
                raise ValueError("Track layer needs a known ID, opacity 0..1 and x/y offset")
            if any(isinstance(v, bool) or int(v) != v for v in offset):
                raise ValueError("Layer offsets must be integer pixels")
            stage_layers.append({"id": layer, "opacity": opacity, "offset": [int(v) for v in offset]})
        result.append({"at_ms": at, "body": body, "layers": stage_layers})
        previous = at
    if result[0]["at_ms"] != 0:
        raise ValueError("The first stage must start at zero")
    if {key: result[0][key] for key in ("body", "layers")} != {key: result[-1][key] for key in ("body", "layers")}:
        raise ValueError("Loop first/last body and ordered layer state must match exactly")
    events = []
    for event in spec.get("events", []):
        at = integer(event["at_ms"], "event at_ms")
        if at > duration or not isinstance(event.get("name"), str) or not event["name"]:
            raise ValueError("Events need a name and a time inside the action")
        events.append({"name": event["name"], "at_ms": at, "gameplay_binding": False})
    return result, events, duration, idle


def render_stage(body: Image.Image, layer_images: dict, state: dict) -> tuple:
    result = Image.new("RGBA", body.size, (0, 0, 0, 0))
    for item in state["layers"]:
        array = np.asarray(layer_images[item["id"]].convert("RGBA")).copy()
        array[:, :, 3] = np.floor(array[:, :, 3].astype(float) * item["opacity"] + .5).astype(np.uint8)
        array[array[:, :, 3] == 0] = 0
        layer = Image.fromarray(array)
        require_fits(visible_bounds(layer), tuple(item["offset"]), body.size, f"Layer {item['id']}")
        result.alpha_composite(layer, tuple(item["offset"]))
    result.alpha_composite(body)
    original, rendered = np.asarray(body), np.asarray(result)
    mask = original[:, :, 3] == 255
    if not np.array_equal(original[mask], rendered[mask]):
        raise ValueError("A behind-body layer changed opaque body RGBA")
    return result, {"opaque_body_rgba_exact": True,
                    "opaque_body_pixels_checked": int(mask.sum()),
                    "composite_has_partial_alpha": bool(np.any((rendered[:, :, 3] > 0) & (rendered[:, :, 3] < 255)))}


def rgb_stage(image: Image.Image, background: tuple) -> Image.Image:
    result = Image.new("RGBA", image.size, (*background, 255))
    result.alpha_composite(image)
    return result.convert("RGB")


class GifPalette:
    def __init__(self, body_colors: list, background: tuple, samples: list):
        self.reserved = ordered_colors([background] + body_colors + [TEXT_COLOR])
        if len(self.reserved) > 256:
            raise ValueError("Exact body/background colors exceed the GIF palette budget")
        self.codes = np.array([code(color) for color in self.reserved], dtype=np.uint32)
        self.lookup = {int(value): index for index, value in enumerate(self.codes)}
        budget = 256 - len(self.reserved)
        foreign = []
        for image in samples:
            rgb = np.asarray(image.convert("RGB")).reshape(-1, 3)
            keep = ~np.isin(rgb_codes(rgb), self.codes)
            if np.any(keep):
                foreign.append(rgb[keep])
        extras = []
        if foreign:
            if budget == 0:
                raise ValueError("No GIF slots remain for independently composited FX")
            rgb = np.concatenate(foreign, axis=0)
            unique = np.unique(rgb, axis=0)
            if len(unique) <= budget:
                extras = [tuple(int(v) for v in color) for color in unique]
            else:
                trained = Image.fromarray(rgb.reshape(1, -1, 3)).quantize(
                    colors=budget, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
                extras = [tuple(int(v) for v in color) for color in
                          np.unique(np.asarray(trained.convert("RGB")).reshape(-1, 3), axis=0)]
        self.extras = [color for color in ordered_colors(extras) if color not in self.reserved]
        self.colors = self.reserved + self.extras
        self.values = [v for color in self.colors for v in color] + list(self.colors[0]) * (256 - len(self.colors))
        self.palette = Image.new("P", (1, 1))
        self.palette.putpalette(self.values)

    def encode(self, image: Image.Image) -> Image.Image:
        image = image.convert("RGB")
        wanted = np.asarray(image)
        packed = rgb_codes(wanted)
        mapped = np.asarray(image.quantize(palette=self.palette, dither=Image.Dither.NONE)).copy()
        unique, inverse = np.unique(packed, return_inverse=True)
        indices = np.array([self.lookup.get(int(value), -1) for value in unique], dtype=np.int16)
        exact = indices[inverse].reshape(packed.shape)
        match = exact >= 0
        mapped[match] = exact[match].astype(np.uint8)
        output = Image.fromarray(mapped)
        output.putpalette(self.values)
        if not np.array_equal(np.asarray(output.convert("RGB"))[match], wanted[match]):
            raise ValueError("GIF indexing changed a reserved body RGB")
        return output


def tick(value: float) -> int:
    return int(math.floor(value / 10 + .5)) * 10


def gif_timing(track: list, duration: int, idle: int, events: list, factor: int = 1) -> dict:
    starts = [stage["at_ms"] * factor for stage in track]
    end = duration * factor + idle
    boundaries = [tick(value) for value in starts + [end]]
    intervals = [b - a for a, b in zip(boundaries, boundaries[1:])]
    if any(value <= 0 for value in intervals):
        raise ValueError("A visual stage vanishes at GIF 10 ms precision; adjust the explicit timing")
    return {"durations_ms": intervals, "total_ms": boundaries[-1], "slow_factor": factor,
            "stage_starts_ideal_ms": starts, "stage_starts_gif_ms": boundaries[:-1],
            "boundary_rounding_error_ms": [actual - ideal for actual, ideal in zip(boundaries, starts + [end])],
            "events": [{**event, "ideal_preview_ms": event["at_ms"] * factor,
                        "nearest_gif_tick_ms": tick(event["at_ms"] * factor)} for event in events],
            "idle_ms": idle}


def gif_bytes(images: list, timing: dict, palette: GifPalette) -> tuple:
    indexed = [palette.encode(image) for image in images]
    stream = BytesIO()
    indexed[0].save(stream, format="GIF", save_all=True, append_images=indexed[1:],
                    duration=timing["durations_ms"], loop=0, optimize=False, disposal=2)
    data = stream.getvalue()
    decoded, ends, elapsed = [], [], 0
    with Image.open(BytesIO(data)) as result:
        for index in range(result.n_frames):
            result.seek(index)
            elapsed += int(result.info.get("duration", 0))
            ends.append(elapsed)
            decoded.append(np.asarray(result.convert("RGB")).copy())
    if elapsed != timing["total_ms"]:
        raise ValueError("GIF encoding changed the total timeline")
    elapsed, checked, max_fx_error = 0, 0, 0
    for image, duration in zip(images, timing["durations_ms"]):
        index = next(i for i, end in enumerate(ends) if end > elapsed)
        wanted, actual = np.asarray(image.convert("RGB")), decoded[index]
        exact = np.isin(rgb_codes(wanted), palette.codes)
        if not np.array_equal(wanted[exact], actual[exact]):
            raise ValueError("Encoded GIF changed a reserved body RGB")
        checked += int(exact.sum())
        if np.any(~exact):
            max_fx_error = max(max_fx_error, int(np.abs(wanted[~exact].astype(int) - actual[~exact].astype(int)).max()))
        elapsed += duration
    return data, {**timing, "encoded_frames": len(decoded), "requested_samples": len(images),
                  "sha256": digest(data), "reserved_rgb_pixels_checked": checked,
                  "reserved_rgb_exact": True, "maximum_unreserved_fx_channel_error": max_fx_error}


def sample(track: list, at: int) -> int:
    result = 0
    for index, stage in enumerate(track):
        if stage["at_ms"] > at:
            break
        result = index
    return result


def comparison_timing(before: dict, after: dict, period: int | None = None) -> dict:
    minimum = max(before["duration_ms"] + before["idle_ms"], after["duration_ms"] + after["idle_ms"])
    period = minimum if period is None else integer(period, "comparison period_ms", 1)
    if period < minimum:
        raise ValueError("Comparison period would truncate one animation")
    times = {0, period, before["duration_ms"], after["duration_ms"],
             before["duration_ms"] + before["idle_ms"], after["duration_ms"] + after["idle_ms"]}
    for item in (before, after):
        times.update(stage["at_ms"] for stage in item["track"])
        times.update(event["at_ms"] for event in item.get("events", []))
    times = sorted(times)
    quantized = [tick(value) for value in times]
    intervals = [b - a for a, b in zip(quantized, quantized[1:])]
    if any(value <= 0 for value in intervals):
        raise ValueError("Distinct comparison events collide at GIF precision")
    return {"union_boundaries_ms": times, "durations_ms": intervals, "total_ms": quantized[-1],
            "before_indices": [sample(before["track"], at) for at in times[:-1]],
            "after_indices": [sample(after["track"], at) for at in times[:-1]],
            "absolute_time_alignment": True,
            "boundary_rounding_error_ms": [actual - ideal for actual, ideal in zip(quantized, times)]}


def make_sheet(images: list, track: list, background: tuple, anchor: tuple) -> Image.Image:
    width, height = images[0].size
    sheet = Image.new("RGB", (width * 4, (height + HEADER) * math.ceil(len(images) / 4)), background)
    draw = ImageDraw.Draw(sheet)
    for index, (image, stage) in enumerate(zip(images, track)):
        x, y = index % 4 * width, index // 4 * (height + HEADER)
        draw.text((x + 8, y + 9), f"{index:02} / {stage['body']} / {stage['at_ms']}ms", fill=TEXT_COLOR)
        panel = Image.new("RGBA", image.size, (*background, 255))
        guides = ImageDraw.Draw(panel)
        ax, ay = (round(v) for v in anchor)
        guides.line((ax - 3, ay, ax + 3, ay), fill=(81, 111, 120), width=1)
        guides.line((ax, ay - 3, ax, ay + 3), fill=(81, 111, 120), width=1)
        panel.alpha_composite(image)
        sheet.paste(panel.convert("RGB"), (x, y + HEADER))
    return sheet


def build_assets(spec: dict, root: Path) -> dict:
    canvas = tuple(integer(value, "canvas", 1) for value in spec["canvas"])
    anchor = tuple(float(value) for value in spec["anchor"])
    if len(canvas) != 2 or len(anchor) != 2 or not all(math.isfinite(v) for v in anchor):
        raise ValueError("canvas and anchor need two coordinates")
    if not (0 <= anchor[0] <= canvas[0] and 0 <= anchor[1] <= canvas[1]):
        raise ValueError("The shared anchor is outside the character canvas")
    sources, source_records, scales = {}, {}, []
    for source_id, item in spec["sources"].items():
        source_id = identifier(source_id)
        scale = float(item["scale"])
        if not math.isfinite(scale) or scale <= 0:
            raise ValueError("Every source scale must be positive and finite")
        image, record = read_image(root, item)
        sources[source_id], source_records[source_id] = image, {**record, "scale": scale}
        scales.append(scale)
    if not scales or any(not math.isclose(value, scales[0], abs_tol=1e-12) for value in scales):
        raise ValueError("A character's source group must use one shared scale")
    body_ids, raw_bodies, body_records = [], [], []
    for item in spec["bodies"]:
        body_id, source_id = identifier(item["id"]), identifier(item["source"])
        if body_id in body_ids or source_id not in sources:
            raise ValueError("Body IDs must be unique and reference a declared source")
        image, details = extract(sources[source_id], item, source_records[source_id]["scale"], canvas, anchor)
        body_ids.append(body_id)
        raw_bodies.append(image)
        body_records.append({"id": body_id, "name": item.get("name", body_id), "source": source_id, **details})
    if not raw_bodies:
        raise ValueError("At least one explicit body pose is required")
    bodies, body_palette = train_body_palette(raw_bodies, integer(spec.get("palette_colors", 96), "palette_colors", 1))
    body_images = dict(zip(body_ids, bodies))
    layer_images, layer_records = {}, {}
    for layer_id, item in spec.get("layers", {}).items():
        layer_id = identifier(layer_id)
        if item.get("order", "behind") != "behind":
            raise ValueError("Foreground layers are not part of this behind-body schema")
        if "source" in item:
            source_id = identifier(item["source"])
            if source_id not in sources:
                raise ValueError("Layer refers to an unknown source")
            image, details = extract(sources[source_id], item, source_records[source_id]["scale"], canvas, anchor, False)
            details["source"] = source_id
        else:
            original, file_record = read_image(root, item)
            image, details = external_layer(original, item, canvas)
            details["input"] = file_record
        # A full-size external RGBA layer is copied pixel-for-pixel, including
        # invisible RGB. Rendering may canonicalize zero-alpha pixels later.
        layer_images[layer_id], layer_records[layer_id] = image.copy(), details
    track, events, duration, idle = normalized_track(spec, body_images, layer_images)
    renders, render_records = [], []
    for state in track:
        image, details = render_stage(body_images[state["body"]], layer_images, state)
        renders.append(image)
        render_records.append({"at_ms": state["at_ms"], "body": state["body"], "layers": state["layers"], **details})
    if not np.array_equal(np.asarray(renders[0]), np.asarray(renders[-1])):
        raise ValueError("Full first/last RGBA render differs despite the declared loop state")
    return {"canvas": canvas, "anchor": anchor, "sources": source_records,
            "body_ids": body_ids, "bodies": bodies, "body_records": body_records,
            "body_palette": body_palette, "layers": layer_images, "layer_records": layer_records,
            "track": track, "events": events, "duration_ms": duration, "idle_ms": idle,
            "renders": renders, "render_records": render_records}


def read_comparison(root: Path, entry: dict, current: dict) -> dict:
    path = root / entry["before_manifest"]
    previous = json.loads(path.read_text(encoding="utf-8"))
    if previous.get("schema") != SCHEMA or tuple(previous["canvas"]) != current["canvas"]:
        raise ValueError("Comparison requires a compatible generic-engine manifest and canvas")
    images = []
    for record in previous["renders"]:
        file = path.parent / record["file"]
        if file_hash(file) != record["sha256"]:
            raise ValueError("A comparison source render changed")
        image, _ = decode_source(file.read_bytes(), record["file"])
        images.append(image)
    if len(images) != len(previous["track"]):
        raise ValueError("Comparison source renders do not match its track")
    timing = comparison_timing(previous, current, entry.get("period_ms"))
    return {"manifest": previous, "images": images, "timing": timing,
            "source": {"manifest": entry["before_manifest"], "sha256": file_hash(path)}}


def preflight_outputs(root: Path, spec_path: Path, spec: dict, assets: dict, before):
    names = [f"frames/{body_id}.png" for body_id in assets["body_ids"]]
    names += [f"layers/{layer_id}.png" for layer_id in assets["layers"]]
    names += ["atlas.png", "contact_sheet.png", "preview.gif", "preview_slow.gif", "manifest.json", "structural_report.json"]
    if any(state["layers"] for state in assets["track"]):
        names += [f"render_frames/{index:03}.png" for index in range(len(assets["track"]))]
    if before is not None:
        names.append("comparison.gif")
    inputs = {spec_path.resolve()}
    inputs.update((root / entry["file"]).resolve() for entry in spec["sources"].values())
    inputs.update((root / entry["file"]).resolve() for entry in spec.get("layers", {}).values() if "file" in entry)
    if before is not None:
        old_manifest = (root / spec["compare"]["before_manifest"]).resolve()
        inputs.add(old_manifest)
        inputs.update((old_manifest.parent / record["file"]).resolve() for record in before["manifest"]["renders"])
    for name in names:
        if output_path(root, name) in inputs:
            raise ValueError("An output would overwrite a source/spec/previous render; use a separate candidate directory")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    args = parser.parse_args()
    if not args.spec.is_absolute():
        raise ValueError("Pass an absolute --spec path; outputs are relative to that file")
    path = args.spec.resolve()
    root = path.parent
    spec = json.loads(path.read_text(encoding="utf-8"))
    assets = build_assets(spec, root)
    background = tuple(integer(v, "background RGB") for v in spec.get("background", DEFAULT_BACKGROUND))
    if len(background) != 3 or max(background) > 255:
        raise ValueError("Background must contain three RGB bytes")
    before = read_comparison(root, spec["compare"], assets) if spec.get("compare") else None
    preflight_outputs(root, path, spec, assets, before)
    # Validate timelines, palette budgets and actual GIF round trips before
    # writing any character output, so malformed specs leave no half-batch.
    rgb = [rgb_stage(image, background) for image in assets["renders"]]
    compare_frames, extra_body_colors = [], []
    if before is not None:
        width, height = assets["canvas"]
        for old, new in zip(before["timing"]["before_indices"], before["timing"]["after_indices"]):
            panel = Image.new("RGB", (width * 2, height + HEADER), background)
            draw = ImageDraw.Draw(panel)
            draw.text((8, 9), "BEFORE", fill=TEXT_COLOR)
            draw.text((width + 8, 9), "AFTER", fill=TEXT_COLOR)
            panel.paste(rgb_stage(before["images"][old], background), (0, HEADER))
            panel.paste(rgb[new], (width, HEADER))
            compare_frames.append(panel)
        extra_body_colors = before["manifest"]["body_palette_rgb"]
    palette = GifPalette(assets["body_palette"] + extra_body_colors, background, rgb + compare_frames)
    previews, encoded_outputs = {}, {}
    for filename, factor in (("preview.gif", 1), ("preview_slow.gif", 2)):
        timing = gif_timing(assets["track"], assets["duration_ms"], assets["idle_ms"], assets["events"], factor)
        data, record = gif_bytes(rgb, timing, palette)
        encoded_outputs[filename], previews[filename] = data, record
    if before is not None:
        data, record = gif_bytes(compare_frames, before["timing"], palette)
        encoded_outputs["comparison.gif"] = data
        previews["comparison.gif"] = {**record, "source": before["source"]}
    for body_id, image, record in zip(assets["body_ids"], assets["bodies"], assets["body_records"]):
        relative = f"frames/{body_id}.png"
        file = output_path(root, relative)
        file.parent.mkdir(exist_ok=True)
        image.save(file)
        array = np.asarray(image)
        record.update({"file": relative, "sha256": file_hash(file), "rgba_pixel_sha256": pixel_hash(image),
                       "opaque_colors": len(np.unique(array[:, :, :3][array[:, :, 3] == 255], axis=0)),
                       "alpha_values": [int(v) for v in np.unique(array[:, :, 3])]})
    for layer_id, image in assets["layers"].items():
        relative = f"layers/{layer_id}.png"
        file = output_path(root, relative)
        file.parent.mkdir(exist_ok=True)
        image.save(file)
        assets["layer_records"][layer_id].update({"file": relative, "sha256": file_hash(file),
                                                 "rgba_pixel_sha256": pixel_hash(image),
                                                 "partial_alpha_allowed": True})
    atlas = Image.new("RGBA", (assets["canvas"][0] * len(assets["bodies"]), assets["canvas"][1]), (0, 0, 0, 0))
    for index, image in enumerate(assets["bodies"]):
        atlas.alpha_composite(image, (index * assets["canvas"][0], 0))
    atlas.save(output_path(root, "atlas.png"))
    make_sheet(assets["renders"], assets["track"], background, assets["anchor"]).save(output_path(root, "contact_sheet.png"))
    has_layers = any(state["layers"] for state in assets["track"])
    for index, (image, record) in enumerate(zip(assets["renders"], assets["render_records"])):
        relative = f"render_frames/{index:03}.png" if has_layers else f"frames/{record['body']}.png"
        file = output_path(root, relative)
        if has_layers:
            file.parent.mkdir(exist_ok=True)
            image.save(file)
        record.update({"file": relative, "sha256": file_hash(file)})
    for filename, data in encoded_outputs.items():
        output_path(root, filename).write_bytes(data)
    manifest = {"schema": SCHEMA, "character": spec["character"], "display_name": spec.get("display_name", spec["character"]),
                "status": "structural_candidate_requires_visual_review", "canvas": list(assets["canvas"]),
                "anchor": list(assets["anchor"]), "sources": assets["sources"], "bodies": assets["body_records"],
                "layers": assets["layer_records"], "layer_order": "declared list behind opaque body",
                "body_palette_rgb": assets["body_palette"], "palette_limit": spec.get("palette_colors", 96),
                "body_palette_assignment": "group_median_cut_then_exact_nearest_rgb_without_dither",
                "track": assets["track"], "renders": assets["render_records"], "events": assets["events"],
                "duration_ms": assets["duration_ms"], "idle_ms": assets["idle_ms"], "previews": previews,
                "first_last_full_rgba_identical": True,
                "review_profile": spec.get("review_profile", []),
                "review_annotations": spec.get("review_annotations", {}),
                "events_are_preview_metadata_only": True}
    write_json(output_path(root, "manifest.json"), manifest)
    report = {"result": "structural_pass_not_visual_acceptance", "character": spec["character"],
              "body_count": len(assets["bodies"]), "stage_count": len(assets["track"]),
              "unique_body_rgba_pixel_hashes": len({pixel_hash(image) for image in assets["bodies"]}),
              "shared_source_scale": next(iter(assets["sources"].values()))["scale"],
              "body_palette_colors": len(assets["body_palette"]), "body_alpha_binary": True,
              "visible_pixels_within_canvas": True, "first_last_full_rgba_identical": True,
              "opaque_body_rgba_preserved_after_layers": True, "layer_partial_alpha_allowed": True,
              "gif_exact_reserved_colors": len(palette.reserved), "gif_additional_fx_colors": len(palette.extras),
              "gif_palette_total": len(palette.colors), "previews": previews,
              "unused_body_ids": [key for key in assets["body_ids"] if key not in {stage["body"] for stage in assets["track"]}],
              "not_verified": ["anatomy", "grip_and_weapon_continuity", "support_contacts", "visual_transitions",
                               "owner_approval", "runtime_integration", "gameplay_event_binding"]}
    write_json(output_path(root, "structural_report.json"), report)
    print(json.dumps({"character": spec["character"], "bodies": len(assets["bodies"]), "stages": len(assets["track"]),
                      "shared_colors": len(assets["body_palette"]), "preview_ms": previews["preview.gif"]["total_ms"]},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
