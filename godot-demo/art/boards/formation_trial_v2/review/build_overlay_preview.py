"""Offline geometry QA, not gameplay; never alters the generated source PNG."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
ART_ROOT = ROOT.parents[2]
metadata = json.loads((ROOT.parent / "integration.json").read_text())
mapping = metadata["background_mapping"]["draw_rect"]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--height", type=int, default=mapping[3])
parser.add_argument("--top", type=int, default=mapping[1])
parser.add_argument("--sprites", action="store_true", help="Overlay existing idle frames; not runtime evidence")
parser.add_argument("--output", type=Path, default=ROOT / "geometry-overlay-720p.png")
args = parser.parse_args()

source_path = ROOT.parent / "board-courtyard.png"
assert hashlib.sha256(source_path.read_bytes()).hexdigest() == metadata["asset"]["sha256"]
source = Image.open(source_path).convert("RGBA")
assert source.size == (1672, 941)
assert metadata["geometry"]["board_rect"] == [220, 190, 1320, 714]
canvas = Image.new("RGBA", (1920, 1080), "#101f23")
canvas.alpha_composite(source.resize((1920, args.height), Image.Resampling.LANCZOS), (0, args.top))
overlay = Image.new("RGBA", canvas.size)
d = ImageDraw.Draw(overlay)
for col in range(13):
    x = 220 + col * 110
    d.line((x, 190, x, 904), fill=(35, 54, 57, 150), width=2)
for row in range(8):
    y = 190 + row * 102
    d.line((220, y, 1540, y), fill=(35, 54, 57, 150), width=2)
d.rectangle((220, 190, 1540, 904), outline="#efd28c", width=3)
for y in range(190, 904, 18):
    d.line((880, y, 880, min(y + 9, 904)), fill=(237, 213, 144, 215), width=2)
# The cyan outline tests the larger art safety margin, not another play field.
d.rectangle((200, 170, 1560, 924), outline=(81, 218, 223, 240), width=2)
canvas = Image.alpha_composite(canvas, overlay)
if args.sprites:
    # Existing formation A snapshot for readability only, not an alternative config.
    samples = [
        ("tangseng", 3, 4, "right"), ("guard_monk", 6, 4, "right"),
        ("wild_hunter", 5, 3, "right"), ("sparrow_spirit", 5, 4, "right"),
        ("herbal_spirit_child", 4, 4, "right"), ("foxfire_imp", 5, 5, "right"),
        ("mountain_wolf", 8, 2, "left"), ("mountain_wolf", 8, 6, "left"),
        ("boar", 9, 3, "left"), ("boar", 9, 5, "left"),
        ("gray_rat", 11, 2, "left"), ("gray_rat", 11, 6, "left"),
    ]
    for key, col, row, facing in sorted(samples, key=lambda value: value[2]):
        folder = ART_ROOT / "production" / key / "nine_sols_v1"
        manifest = json.loads((folder / "manifest.json").read_text())
        assert manifest["source_facing"] == metadata["source_facing"][key]
        sprite = Image.open(folder / "idle.png").convert("RGBA")
        anchor_x, anchor_y = manifest["frame"]["foot_anchor"]
        if manifest["source_facing"] != facing:
            sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            anchor_x = sprite.width - anchor_x
        x = 220 + (col - .5) * 110
        y = 190 + (row - .5) * 102
        canvas.alpha_composite(sprite, (round(x - anchor_x), round(y - anchor_y)))
d = ImageDraw.Draw(canvas)
for box in ((18, 170, 196, 904), (1572, 160, 1886, 1052), (0, 0, 1920, 115), (220, 958, 1540, 1052)):
    d.rounded_rectangle(box, radius=8, fill="#172a30", outline="#6e8080", width=1)
d.text((25, 30), "OFFLINE GEOMETRY QA / NOT GAMEPLAY", fill="#e9e2cf")
d.text((25, 50), f"Background Rect(0,{args.top},1920,{args.height}); grid unchanged", fill="#e9e2cf")
d.text((1585, 176), "UI SAFE AREA", fill="#e9e2cf")
d.text((235, 977), "84 CELLS / 6 PORTRAIT CARDS / NO NEW GAME RULES", fill="#e9e2cf")
canvas.resize((1280, 720), Image.Resampling.LANCZOS).convert("RGB").save(args.output)
print(args.output)
