#!/usr/bin/env python3
"""Keep the original sprite outside an explicit imagegen edit region."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    spec = json.loads((ROOT / "patch_spec.json").read_text())
    base = Image.open(ROOT / spec["base_file"]).convert("RGBA")
    raw = Image.open(ROOT / spec["edit_file"]).convert("RGBA")
    edit = raw.resize(base.size, Image.Resampling.NEAREST)
    mask = Image.new("L", base.size)
    draw = ImageDraw.Draw(mask)
    for polygon in spec["edit_polygons"]:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    for rectangle in spec.get("protected_rectangles", []):
        draw.rectangle(rectangle, fill=0)

    source_manifest = json.loads((ROOT / spec["base_manifest"]).read_text())
    colors = source_manifest["shared_opaque_palette_rgb"]
    palette = Image.new("P", (1, 1))
    entries = [v for color in colors for v in color]
    palette.putpalette(entries + list(colors[0]) * (256 - len(colors)))
    quantized = edit.convert("RGB").quantize(palette=palette,
                                              dither=Image.Dither.NONE).convert("RGBA")
    pixels = np.array(quantized)
    pixels[:, :, 3] = np.where(np.asarray(edit.getchannel("A")) >= 128, 255, 0)
    pixels[pixels[:, :, 3] == 0] = 0
    original = np.array(base)
    selection = np.asarray(mask) == 255
    result = original.copy()
    result[selection] = pixels[selection]
    if not np.array_equal(result[~selection], original[~selection]):
        raise ValueError("Protected body pixels changed")
    out = ROOT / spec["output_file"]
    out.parent.mkdir(exist_ok=True)
    Image.fromarray(result).save(out)
    mask.save(ROOT / "source/edit_region.png")
    changed = np.any(result != original, axis=2)
    ys, xs = np.where(changed)
    report = {"source_sha256": sha(ROOT / spec["base_file"]),
              "edit_sha256": sha(ROOT / spec["edit_file"]),
              "output_sha256": sha(out), "generated_canvas": list(raw.size),
              "canvas": list(base.size), "changed_pixels": int(changed.sum()),
              "changed_bbox": [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)],
              "outside_edit_region_rgba_exact": True,
              "normalization": "nearest, original palette, binary alpha; no body warp"}
    (ROOT / "patch_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
