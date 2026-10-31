from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[4]
out = Path(__file__).resolve().parent
b = Image.open(out / 'board.png').convert('RGBA').resize((1440, 810), Image.Resampling.LANCZOS)
over = Image.new('RGBA', b.size)
d = ImageDraw.Draw(over)
for u in range(-12, 13):
    for v in range(-12, 13):
        x, y = 720 + (u - v) * 72, 441 + (u + v) * 36
        if x - 72 < 216 or x + 72 > 1224 or y - 36 < 225 or y + 36 > 657:
            continue
        d.line([(x,y-36),(x+72,y),(x,y+36),(x-72,y),(x,y-36)], fill=(15,38,30,80), width=1)
d.line([(720,405),(792,441),(720,477),(648,441),(720,405)], fill=(80,150,94,200), width=2)
b = Image.alpha_composite(b, over)
c = Image.open(root / 'bear-forehand-showcase/art/attack/attack_00.png').convert('RGBA').resize((288,240), Image.Resampling.LANCZOS)
b.alpha_composite(c, (round(720-177*.75), round(441-213*.75)))
b.convert('RGB').save(out / 'offline-grid-bear-preview.png')
