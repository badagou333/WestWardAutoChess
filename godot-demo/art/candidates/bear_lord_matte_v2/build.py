#!/usr/bin/env python3
"""Deterministic pale-background decontamination; no image synthesis or retiming.

Requires Python 3, Pillow and NumPy. Inputs are the immutable v1 candidate PNGs.
All motion, dimensions and source-frame references are preserved.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
SOURCE = HERE.parent / "bear_lord_forehand_trial_v1"
BACKGROUND = np.array([237.0, 237.0, 237.0], dtype=np.float32)
# Local smooth optical-veil estimates for the source video's grey arc over feet.
# Each tuple is centre x/y, radius x/y, maximum pale veil fraction in source pixels.
# These do not paint new texture or alter alpha. Armour and upper body are excluded.
FOOT_VEILS = {
    10: [(145, 210, 19, 17, 0.09)],
    11: [(145, 209, 20, 19, 0.16), (188, 190, 23, 11, 0.10)],
    12: [(145, 210, 20, 18, 0.13), (188, 189, 22, 12, 0.07)],
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def erode(mask: np.ndarray, size: int) -> np.ndarray:
    return np.array(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(size))) > 0


def white_edge_proxy(rgba: np.ndarray) -> int:
    visible = rgba[:, :, 3] > 25
    edge = visible & ~erode(visible, 5)
    rgb = rgba[:, :, :3].astype(np.float32)
    return int((edge & (rgb.min(2) > 170) & ((rgb.max(2) - rgb.min(2)) < 40)).sum())


def repair(before: Image.Image, index: int) -> tuple[Image.Image, dict]:
    original = np.array(before.convert("RGBA"))
    rgba = original.astype(np.float32)
    rgb, alpha = rgba[:, :, :3], rgba[:, :, 3] / 255.0
    height, width = alpha.shape
    solid = alpha > 0.9
    deep = erode(solid, 15)
    # Avoid using an opaque-but-pale halo itself as the reference foreground.
    # Genuine bright armour further than seven pixels from the silhouette remains a seed.
    core = erode(solid, 7) & ((rgb.min(2) < 145) | deep)
    reference = rgb.copy()
    distance = np.full((height, width), 99, dtype=np.int16)
    queue = deque()
    for y, x in zip(*np.where(core)):
        distance[y, x] = 0
        queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        d = distance[y, x]
        if d >= 12:
            continue
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < height and 0 <= xx < width and distance[yy, xx] > d + 1:
                distance[yy, xx] = d + 1
                reference[yy, xx] = reference[y, x]
                queue.append((yy, xx))

    # Fit C = coverage * foreground + (1-coverage) * pale background.
    direction = BACKGROUND - reference
    observed = BACKGROUND - rgb
    coverage = np.clip((observed * direction).sum(2) / ((direction * direction).sum(2) + 1e-5), 0.05, 1.0)
    fitted = reference * coverage[:, :, None] + BACKGROUND * (1 - coverage[:, :, None])
    residual = np.abs(fitted - rgb).max(2)
    band = (distance > 0) & (distance <= 12) & (alpha > 0)
    brightened = rgb.mean(2) - reference.mean(2) > 5
    consistent = (residual < 35) | ((rgb.min(2) > 150) & ((rgb.max(2) - rgb.min(2)) < 60))
    corrected = band & brightened & consistent
    coverage = np.where(corrected, coverage, 1.0)
    colour = (rgb - BACKGROUND * (1 - coverage[:, :, None])) / coverage[:, :, None]
    colour = np.where(corrected[:, :, None], colour, rgb)
    # Use fitted soft coverage instead of multiplying alpha a second time.
    new_alpha = np.where(corrected, np.minimum(alpha, coverage), alpha)

    yy, xx = np.mgrid[:height, :width]
    veil = np.zeros((height, width), dtype=np.float32)
    for cx, cy, rx, ry, strength in FOOT_VEILS.get(index, []):
        radius2 = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        veil = np.maximum(veil, strength * np.maximum(0, 1 - radius2) ** 0.6)
    colour = (colour - BACKGROUND * veil[:, :, None]) / (1 - veil[:, :, None])
    result = np.rint(np.dstack([np.clip(colour, 0, 255), new_alpha * 255])).astype(np.uint8)
    result[result[:, :, 3] == 0, :3] = 0

    untouched_core = deep & (veil == 0)
    assert np.array_equal(original[untouched_core], result[untouched_core])
    assert np.all(result[:, :, 3] <= original[:, :, 3])
    assert np.all(result[:4, :, 3] == 0) and np.all(result[-4:, :, 3] == 0)
    assert np.all(result[:, :4, 3] == 0) and np.all(result[:, -4:, 3] == 0)
    stats = {
        "edge_corrected_pixels": int(corrected.sum()),
        "foot_veil_pixels": int(((veil > 0) & (alpha > 0)).sum()),
        "unchanged_deep_core_pixels": int(untouched_core.sum()),
        "alpha_coverage_before": round(float(alpha.sum()), 3),
        "alpha_coverage_after": round(float(result[:, :, 3].sum() / 255), 3),
        "white_edge_proxy_before": white_edge_proxy(original),
        "white_edge_proxy_after": white_edge_proxy(result),
        "new_nontransparent_pixels": 0,
        "dimensions": list(before.size),
        "outer_4px_alpha_max": 0,
    }
    return Image.fromarray(result), stats


def composite(sprite: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    base = Image.new("RGBA", sprite.size, bg + (255,))
    base.alpha_composite(sprite)
    return base.convert("RGB")


def make_review(before: list[Image.Image], after: list[Image.Image], manifest: dict, output: Path):
    crop = (28, 9, 340, 245)
    cell_width, cell_height = 312, 260
    for name, bg in (("dark", (25, 42, 36)), ("light", (235, 235, 235))):
        sheet = Image.new("RGB", (cell_width * 5, cell_height * 8), bg)
        draw = ImageDraw.Draw(sheet)
        for i in range(20):
            for variant, images in enumerate((before, after)):
                x, y = i % 5 * cell_width, (i // 5 * 2 + variant) * cell_height
                sheet.paste(composite(images[i], bg).crop(crop), (x, y + 22))
                draw.text((x + 5, y + 5), f"{i:02} {'BEFORE' if variant == 0 else 'AFTER'}", fill="white" if name == "dark" else "black")
        sheet.save(output / f"contact-{name}-before-after.jpg", quality=94)

    board_path = REPO / "bear-forehand-showcase/art/forest-board.png"
    board = Image.open(board_path).convert("RGBA").resize((1440, 810))
    draw = ImageDraw.Draw(board)
    draw.line([(648, 441), (720, 405), (792, 441), (720, 477), (648, 441)], fill=(170, 220, 180), width=2)
    board_crop = (510, 250, 930, 530)
    views = []
    for i in range(20):
        row = Image.new("RGB", (840, 300))
        for variant, images in enumerate((before, after)):
            base = board.copy()
            sprite = images[i].resize((288, 240), Image.Resampling.BICUBIC)
            base.alpha_composite(sprite, (587, 281))
            row.paste(base.convert("RGB").crop(board_crop), (variant * 420, 20))
        ImageDraw.Draw(row).text((8, 4), f"{i:02} BEFORE - offline board composite", fill="white")
        ImageDraw.Draw(row).text((428, 4), f"{i:02} AFTER - offline board composite", fill="white")
        views.append(row)
    panel = Image.new("RGB", (840, 300 * 5))
    for j, i in enumerate((0, 9, 10, 11, 12)):
        panel.paste(views[i], (0, j * 300))
    panel.save(output / "board-before-after.jpg", quality=94)
    boundaries = [round(float(f["source_time_seconds"]) * 100) * 10 for f in manifest["frames"]] + [3850]
    durations = [boundaries[i + 1] - boundaries[i] for i in range(20)]
    views[0].save(output / "board-before-after.gif", save_all=True, append_images=views[1:], duration=durations, loop=0, disposal=2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=HERE)
    args = parser.parse_args()
    source, output = args.source.resolve(), args.output.resolve()
    if output == source:
        raise SystemExit("Output must differ from the immutable input candidate.")
    output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((source / "manifest.json").read_text())
    expected = {item["file"]: item["sha256"] for item in json.loads((source / "frame-verification.json").read_text())["frames"]}
    before, after, reports = [], [], []
    for i, item in enumerate(manifest["frames"]):
        src = source / item["file"]
        assert sha(src) == expected[item["file"]], f"Source changed: {src}"
        old = Image.open(src).convert("RGBA")
        new, stats = repair(old, i)
        dst = output / item["file"]
        new.save(dst)
        reports.append({"file": item["file"], "source_sha256": sha(src), "output_sha256": sha(dst), **stats})
        before.append(old)
        after.append(new)
    # Preserve the interface byte-for-byte; display timing reads source_time_seconds.
    (output / "manifest.json").write_bytes((source / "manifest.json").read_bytes())
    (output / ".gdignore").write_text("")
    report = {
        "status": "needs_visual_review",
        "art_source": "user_supplied_video_existing_selected_pngs",
        "method": "local pale-background optical unmix + explicit soft lower-limb veil correction; no drawing or generation",
        "background_rgb": BACKGROUND.tolist(),
        "foot_veil_ellipses": FOOT_VEILS,
        "unchanged": ["20 frame identities", "384x320 canvas", "manifest", "foot anchor", "source frame times"],
        "limitations": ["approximate foreground colour estimated at contaminated edges", "some source arc haze and motion blur remain", "no extra frames or reconstruction of clipped weapon", "offline composite is not runtime verification"],
        "frames": reports,
    }
    (output / "matte-report.json").write_text(json.dumps(report, indent=2) + "\n")
    make_review(before, after, manifest, output)
    print(json.dumps({"output": str(output), "frames": len(after), "white_edge_proxy_before": sum(r["white_edge_proxy_before"] for r in reports), "white_edge_proxy_after": sum(r["white_edge_proxy_after"] for r in reports)}))


if __name__ == "__main__":
    main()
