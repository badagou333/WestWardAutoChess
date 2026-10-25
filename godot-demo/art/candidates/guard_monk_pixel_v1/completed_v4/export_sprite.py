#!/usr/bin/env python3
"""Export exact-grid static candidates from the preserved imagegen artwork.

The creative edit is produced by imagegen, not by this exporter. This step
only fits the canvas with nearest-neighbor sampling and an opaque palette.
Run from any directory; inputs and outputs are relative to this script.
"""

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source" / "generated_edit.png"
PALETTE_LIMIT = 24
SPECS = (("monk_idle_64.png", (64, 64)), ("monk_idle_48x56.png", (48, 56)))


def pixels(image):
    if hasattr(image, "get_flattened_data"):
        return image.get_flattened_data()
    return image.getdata()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(source, size):
    # Keep genuine generated transparency; do not infer a background color.
    alpha = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    body = source.copy()
    body.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("The generated source has no opaque subject")
    body = body.crop(bounds)
    margin = 3
    scale = min((size[0] - 2 * margin) / body.width,
                (size[1] - 2 * margin) / body.height)
    fitted_size = (round(body.width * scale), round(body.height * scale))
    fitted = body.resize(fitted_size, Image.Resampling.NEAREST)
    mask = fitted.getchannel("A")
    # Build a palette from visible samples only, so transparent RGB does not
    # consume colors. No antialiasing, interpolation, or dithering is added.
    visible = [pixel[:3] for pixel in pixels(fitted) if pixel[3] == 255]
    swatch = Image.new("RGB", (len(visible), 1))
    swatch.putdata(visible)
    palette = swatch.quantize(colors=PALETTE_LIMIT,
                             method=Image.Quantize.MEDIANCUT,
                             dither=Image.Dither.NONE)
    quantized = fitted.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    quantized.putalpha(mask)
    offset = ((size[0] - fitted.width) // 2, size[1] - margin - fitted.height)
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    result.alpha_composite(quantized, offset)
    # Canonical transparent RGB makes downstream hashes and previews stable.
    result.putdata([p if p[3] else (0, 0, 0, 0) for p in pixels(result)])
    return result


def preview(sprite, factor=8):
    enlarged = sprite.resize((sprite.width * factor, sprite.height * factor),
                             Image.Resampling.NEAREST)
    panel = Image.new("RGBA", (enlarged.width + 32, enlarged.height + 32),
                      (34, 38, 45, 255))
    draw = ImageDraw.Draw(panel)
    for y in range(16, panel.height - 16, factor):
        for x in range(16, panel.width - 16, factor):
            if ((x - 16) // factor + (y - 16) // factor) % 2 == 0:
                draw.rectangle((x, y, x + factor - 1, y + factor - 1),
                               fill=(44, 49, 56, 255))
    panel.alpha_composite(enlarged, (16, 16))
    return panel


def review_sheet(sprites):
    backgrounds = (("LIGHT", (226, 221, 205, 255)),
                   ("DARK", (35, 40, 48, 255)))
    panel_w, panel_h = 310, 330
    sheet = Image.new("RGB", (panel_w * 2, panel_h * 2), (20, 23, 29))
    draw = ImageDraw.Draw(sheet)
    for row, (filename, sprite) in enumerate(sprites):
        for col, (label, background) in enumerate(backgrounds):
            x, y = col * panel_w, row * panel_h
            panel = Image.new("RGBA", (panel_w, panel_h), background)
            ink = (238, 235, 223) if label == "DARK" else (44, 40, 34)
            pd = ImageDraw.Draw(panel)
            pd.text((12, 10), f"{sprite.width} x {sprite.height}  |  {label}", fill=ink)
            panel.alpha_composite(sprite, (20, 38))
            pd.text((94, 55), "1x", fill=ink)
            big = sprite.resize((sprite.width * 3, sprite.height * 3),
                                Image.Resampling.NEAREST)
            panel.alpha_composite(big, ((panel_w - big.width) // 2, 116))
            pd.text((12, panel_h - 19), "3x NEAREST / NO SMOOTHING", fill=ink)
            sheet.paste(panel.convert("RGB"), (x, y))
    return sheet


def main():
    source = Image.open(SOURCE).convert("RGBA")
    sprites = []
    records = []
    for filename, size in SPECS:
        sprite = export(source, size)
        path = ROOT / filename
        sprite.save(path)
        preview_name = path.stem + "_x8.png"
        preview(sprite).save(ROOT / preview_name)
        colors = sorted(set(p[:3] for p in pixels(sprite) if p[3]))
        records.append({"file": filename, "canvas": list(size),
                        "visible_bbox": list(sprite.getchannel("A").getbbox()),
                        "opaque_colors": len(colors), "palette_rgb": colors,
                        "alpha_values": sorted(set(pixels(sprite.getchannel("A")))),
                        "sha256": digest(path), "preview": preview_name})
        sprites.append((filename, sprite))
    review_sheet(sprites).save(ROOT / "review_light_dark.png")
    result = {"source": "source/generated_edit.png",
              "source_sha256": digest(SOURCE), "source_canvas": list(source.size),
              "sampling": "nearest", "palette_limit": PALETTE_LIMIT,
              "dither": False, "minimum_margin": 3, "sprites": records}
    (ROOT / "export_report.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sprites": [{k: r[k] for k in ("file", "canvas", "visible_bbox", "opaque_colors")}
                                for r in records]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
