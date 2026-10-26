#!/usr/bin/env python3
"""Rebuild registered local arrow repairs and standalone arrow viewport layers.

Creative pixels come only from the saved imagegen sources. The body group
keeps its one .66 source scale; this registers only a small arrow mask.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
ENGINE = ROOT.parent / "tools" / "build_attack.py"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_exact(image, path):
    image.save(path, format="WEBP", lossless=True, exact=True, quality=100, method=6)
    assert np.array_equal(np.asarray(image), np.asarray(Image.open(path).convert("RGBA")))


def main():
    module_spec = importlib.util.spec_from_file_location("series_engine", ENGINE)
    engine = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(engine)
    source = Image.open(ROOT / "source/archer_attack_sheet.webp").convert("RGBA")
    original = np.asarray(source)
    selected, _, _ = engine.component_union(original[:, :, 3] >= 128, [[640, 260]])
    # Keep the original source pixel plane/anchor. Clear the unused neighboring
    # half-draw pose so the longer arrow cannot join that discarded character.
    isolated = original[:500, :1000].copy()
    isolated[~selected[:500, :1000]] = 0
    before = isolated.copy()
    donor = Image.open(ROOT / "source/nock_length_repair.webp").convert("RGBA")
    donor = np.asarray(donor.resize((448, 448), Image.Resampling.NEAREST))
    mask_image = Image.new("L", (448, 448), 0)
    draw = ImageDraw.Draw(mask_image)
    draw.polygon([(270, 273), (369, 286), (369, 310), (270, 292)], fill=255)
    mask = np.asarray(mask_image) > 0
    yy, xx = np.indices(isolated.shape[:2])
    tx = np.rint((xx - 527.5) * .66 + 104).astype(int)
    ty = np.rint((yy - 418) * .66 + 399).astype(int)
    inside = (tx >= 0) & (tx < 448) & (ty >= 0) & (ty < 448)
    take = np.zeros(inside.shape, dtype=bool)
    take[inside] = mask[ty[inside], tx[inside]]
    isolated[take] = donor[ty[take], tx[take]]
    isolated[isolated[:, :, 3] == 0] = 0
    assert np.array_equal(isolated[~take], before[~take])
    registered = Image.fromarray(isolated)
    registered_path = ROOT / "source/nock_registered.webp"
    save_exact(registered, registered_path)
    mask_image.save(ROOT / "source/nock_target_mask.png")
    patch_report = {"target_canvas": [448, 448], "source_scale": .66,
                    "source_anchor": [527.5, 418], "target_anchor": [104, 399],
                    "mask_polygon_target": [[270, 273], [369, 286], [369, 310], [270, 292]],
                    "source_mask_pixels": int(take.sum()),
                    "changed_source_pixels": int(np.any(isolated != before, axis=2).sum()),
                    "outside_mask_source_rgba_exact": True,
                    "donor_used_only_for_arrow_mask": True,
                    "registered_sha256": digest(registered_path)}
    (ROOT / "source/nock_patch_report.json").write_text(json.dumps(patch_report, indent=2) + "\n")
    spec_path = ROOT / "spec.json"
    spec = json.loads(spec_path.read_text())
    spec["sources"]["nock_patch"] = {"file": "source/nock_registered.webp",
        "sha256": digest(registered_path),
        "expected_pixel_sha256": hashlib.sha256(registered.tobytes()).hexdigest(), "scale": .66}
    nock = next(body for body in spec["bodies"] if body["id"] == "01_nock")
    nock.update({"source": "nock_patch", "source_box": [468, 7, 930, 425]})
    projectile_source = Image.open(ROOT / "source/arrow_repair.webp").convert("RGBA")
    array = np.asarray(projectile_source).copy()
    array[:, :, 3] = np.where(array[:, :, 3] >= 128, 255, 0)
    array[array[:, :, 3] == 0] = 0
    projectile_source = Image.fromarray(array)
    bounds = projectile_source.getchannel("A").getbbox()
    arrow = projectile_source.crop(bounds)
    size = (200, max(1, round(200 * arrow.height / arrow.width)))
    arrow = arrow.resize(size, Image.Resampling.NEAREST)
    top = 231 - size[1] // 2
    for index, dx in enumerate((0, 80, 160, 240)):
        canvas = Image.new("RGBA", (448, 448), (0, 0, 0, 0))
        canvas.alpha_composite(arrow, (132 + dx, top))
        path = ROOT / "source/arrow_layers" / f"flight_{index}.png"
        canvas.save(path)
        spec["layers"][f"flight_{index}"] = {"file": "source/arrow_layers/" + path.name,
            "order": "behind", "sha256": digest(path),
            "expected_pixel_sha256": hashlib.sha256(canvas.tobytes()).hexdigest()}
    spec["review_annotations"]["projectile"] = {
        "source": "source/arrow_repair.webp", "source_bbox": list(bounds),
        "normalized_size": list(size), "axis_y": 231,
        "x_offsets": [0, 80, 160, 240],
        "viewport_exit_clipping_intentional_for_projectile_only": True}
    spec["review_annotations"]["nock_arrow_repair"] = "source/nock_patch_report.json"
    spec_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"arrow_size": size, "nock_patch": patch_report}))


if __name__ == "__main__":
    main()
