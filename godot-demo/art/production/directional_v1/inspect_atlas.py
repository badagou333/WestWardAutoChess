#!/usr/bin/env python3
"""Read-only atlas/manifest geometry inspection. Never modifies image pixels.

Use --source FILE to inspect a candidate, or --role DIR to inspect a package.
Alpha >= 8 locates visible subject components; lower-alpha residue is counted
separately. Pixel geometry cannot validate artistic anatomy or contact points.
"""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def convex_outline(labels, component, margin=2):
    """Return a source-space convex UV outline; calculations never edit an image."""
    rows = np.unique(np.nonzero(labels == component)[0])
    points = []
    for y in rows:
        xs = np.nonzero(labels[y] == component)[0]
        left, right = int(xs[0])-margin, int(xs[-1])+1+margin
        points.extend([(left, int(y)-margin), (right, int(y)-margin),
                       (left, int(y)+1+margin), (right, int(y)+1+margin)])
    points = sorted(set(points))
    def cross(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower, upper = [], []
    for point in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1]+upper[:-1]


def points_in_polygon(xs, ys, polygon):
    """Vectorized ray crossing at pixel centers for arbitrary simple polygons."""
    inside = np.zeros_like(xs, dtype=bool)
    x1, y1 = polygon[-1]
    for x2, y2 in polygon:
        if y1 != y2:
            crossing = ((y1 > ys) != (y2 > ys)) & (xs < (x2-x1)*(ys-y1)/(y2-y1)+x1)
            inside ^= crossing
        x1, y1 = x2, y2
    return inside


def inspect_image(path):
    image = Image.open(path).convert("RGBA")
    pixels = np.asarray(image)
    alpha = pixels[:, :, 3]
    mask = alpha >= 8
    height, width = mask.shape
    labels = np.zeros_like(alpha, dtype=np.int32)
    components = []
    number = 0
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or labels[y, x]:
                continue
            number += 1
            queue = deque([(x, y)])
            labels[y, x] = number
            count = 0
            x0 = x1 = x
            y0 = y1 = y
            while queue:
                px, py = queue.popleft()
                count += 1
                x0, x1 = min(x0, px), max(x1, px)
                y0, y1 = min(y0, py), max(y1, py)
                for nx, ny in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                    if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = number
                        queue.append((nx, ny))
            components.append({"id": number, "pixels": count, "bounds": [x0, y0, x1+1, y1+1]})
    red = (pixels[:, :, 0] > 180) & (pixels[:, :, 1] < 70) & (pixels[:, :, 2] < 70)
    report = {
        "file": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size": [width, height],
        "alpha_range": [int(alpha.min()), int(alpha.max())],
        "low_alpha_nonzero_pixels": int(np.count_nonzero((alpha > 0) & (alpha < 8))),
        "red_pixels_by_min_alpha": {str(v): int(np.count_nonzero(red & (alpha >= v))) for v in [1, 8, 32, 128, 250]},
        "canvas_edge_visible_pixels": {
            "top": int(mask[0].sum()), "bottom": int(mask[-1].sum()),
            "left": int(mask[:, 0].sum()), "right": int(mask[:, -1].sum()),
        },
        "components": sorted([c for c in components if c["pixels"] >= 20], key=lambda c: c["pixels"], reverse=True),
    }
    return report, labels, mask, {c["id"]: c for c in components}


def inspect_role(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    images = {}
    used = {}
    failures = []
    frames = []
    for index, frame in enumerate(manifest["frames"]):
        filename = frame.get("atlas", manifest["atlas"])
        if filename not in images:
            images[filename] = inspect_image(directory / filename)
            used[filename] = np.zeros_like(images[filename][2])
        image_report, labels, mask, components = images[filename]
        width, height = image_report["size"]
        x, y, w, h = frame["region"]
        if not (0 <= x < x+w <= width and 0 <= y < y+h <= height):
            failures.append({"frame": index, "problem": "rectangle outside image"})
            continue
        ys, xs = np.mgrid[0:h, 0:w]
        selected = points_in_polygon(xs+.5, ys+.5, frame["clip_polygon"]) if "clip_polygon" in frame else np.ones((h, w), dtype=bool)
        used[filename][y:y+h, x:x+w] |= selected
        ids, counts = np.unique(labels[y:y+h, x:x+w][selected], return_counts=True)
        subjects = {int(i): int(n) for i, n in zip(ids, counts) if i and components[int(i)]["pixels"] > 500}
        if len(subjects) != 1:
            failures.append({"frame": index, "problem": "rectangle does not contain exactly one major subject", "subjects": subjects})
        elif next(iter(subjects.values())) != components[next(iter(subjects))]["pixels"]:
            failures.append({"frame": index, "problem": "subject clipped by rectangle", "subjects": subjects})
        for field in ["foot", "emission_socket"]:
            px, py = frame[field]
            if not (0 <= px < w and 0 <= py < h):
                failures.append({"frame": index, "problem": field+" outside region"})
        for point in frame["feet"]:
            if not (0 <= point[0] < w and 0 <= point[1] < h):
                failures.append({"frame": index, "problem": "contact foot outside region"})
        frames.append({"index": index, "atlas": filename, "region": frame["region"], "clip_polygon": frame.get("clip_polygon"), "subjects": subjects})
    summaries = []
    for filename, (image_report, labels, mask, components) in images.items():
        image_report["visible_pixels_outside_regions"] = int(np.count_nonzero(mask & ~used[filename]))
        excluded = np.zeros_like(mask)
        for replacement in manifest.get("excluded_original_frames", []):
            if replacement.get("atlas", manifest["atlas"]) != filename:
                continue
            x, y, w, h = replacement["region"]
            excluded[y:y+h, x:x+w] = True
        image_report["explicitly_replaced_original_pixels"] = int(np.count_nonzero(mask & ~used[filename] & excluded))
        image_report["unexplained_visible_pixels_outside_regions"] = int(np.count_nonzero(mask & ~used[filename] & ~excluded))
        summaries.append(image_report)
    return {"character": manifest["character"], "scale": manifest["scale"], "frames": frames, "images": summaries, "failures": failures,
            "scope": "Pixel containment only; foot/emission landmarks are manual, not an anatomy or animation acceptance test."}


def summarize_role(directory):
    report = inspect_role(directory)
    image_lookup = {Path(image["file"]).name: image for image in report["images"]}
    frame_counts = []
    for frame in report["frames"]:
        components = {c["id"]: c for c in image_lookup[frame["atlas"]]["components"]}
        subjects = frame["subjects"]
        frame_counts.append({"index": frame["index"], "atlas": frame["atlas"],
                             "polygon_vertices": len(frame["clip_polygon"] or []),
                             "subject_count": len(subjects),
                             "captured_subject_pixels": sum(subjects.values()),
                             "complete_subject_pixels": sum(components[i]["pixels"] for i in subjects)})
    return {"character": report["character"], "scale": report["scale"],
            "manifest_sha256": hashlib.sha256((directory / "manifest.json").read_bytes()).hexdigest(),
            "frame_count": len(report["frames"]), "frames": frame_counts,
            "images": [{key: image[key] for key in ["file", "sha256", "size", "alpha_range", "canvas_edge_visible_pixels", "visible_pixels_outside_regions", "explicitly_replaced_original_pixels", "unexplained_visible_pixels_outside_regions"]} for image in report["images"]],
            "failures": report["failures"], "scope": report["scope"]}


def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--source", type=Path)
    group.add_argument("--role", type=Path)
    group.add_argument("--all", type=Path, help="Inspect each immediate child directory containing manifest.json")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    if args.all:
        operation = summarize_role if args.summary else inspect_role
        roles = [operation(path.parent) for path in sorted(args.all.glob("*/manifest.json"))]
        result = {"role_count": len(roles), "frame_count": sum(len(r["frames"]) for r in roles),
                  "roles": roles, "failures": [failure for role in roles for failure in role["failures"]]}
    elif args.source:
        result = inspect_image(args.source)[0]
    else:
        result = summarize_role(args.role) if args.summary else inspect_role(args.role)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return int(bool(result.get("failures")))


if __name__ == "__main__":
    raise SystemExit(main())
