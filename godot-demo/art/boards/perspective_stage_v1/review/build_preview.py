"""Offline calibration illustrations only; never edits the scene image or game."""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'review'
SPEC = json.loads((ROOT / 'integration.json').read_text())
P = SPEC['projection_proposal']
R = P['far_to_near_width_ratio']
SOURCE = ROOT / SPEC['source_image']
original = Image.open(SOURCE).convert('RGB')
assert original.size == tuple(SPEC['image_size'])
font = ImageFont.load_default(size=20)
small = ImageFont.load_default(size=15)

def point(x, y):
    u, v = x / 12, y / 7
    d = 1 + (R - 1) * v
    return (P['center_x'] + P['top_width'] * (u - .5) / d,
            P['top_y'] + (P['bottom_y'] - P['top_y']) * R * v / d)

def inverse(x, y):
    t = (y - P['top_y']) / (P['bottom_y'] - P['top_y'])
    v = t / (R - (R - 1) * t)
    u = (x - P['center_x']) * (1 + (R - 1) * v) / P['top_width'] + .5
    return (12 * u, 7 * v)

def grid(draw, transform=lambda p: p):
    for x in range(13):
        color = (224, 204, 126) if x == 6 else (56, 79, 69)
        draw.line([transform(point(x, 0)), transform(point(x, 7))], fill=color, width=2)
    for y in range(8):
        draw.line([transform(point(0, y)), transform(point(12, y))], fill=(56, 79, 69), width=2)
    for y in range(7):
        for x in range(12):
            px, py = transform(point(x + .5, y + .5))
            color = (146, 224, 208) if x < 6 else (237, 166, 139)
            draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill=color)

calibration = original.copy()
d = ImageDraw.Draw(calibration)
grid(d)
d.rectangle((24, 22, 900, 58), fill=(14, 32, 32))
d.text((36, 29), 'OFFLINE CALIBRATION | 12 x 7 / 84 centers | not a game screenshot', font=font, fill='white')
for label, xy in zip(('TL', 'TR', 'BR', 'BL'), SPEC['surface']['recommended_playable_corners']):
    x, y = xy
    d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 220, 100))
    text = f'{label} ({x}, {y})'
    box = d.textbbox((0, 0), text, font=small)
    tx = x + 9 if label in ('TL', 'BL') else x - (box[2] - box[0]) - 9
    ty = y - 26 if label in ('TL', 'TR') else y + 10
    d.rectangle((tx - 3, ty - 2, tx + box[2] + 3, ty + 21), fill=(14, 32, 32))
    d.text((tx, ty), text, font=small, fill='white')
calibration.save(OUT / 'calibration-12x7.png')

D = SPEC['display_proposal']
s = D['uniform_image_scale']
ox, oy = D['image_origin']
def screen(p):
    return ox + s * p[0], oy + s * p[1]
preview = Image.new('RGB', tuple(D['canvas']), D['outside_fill'])
preview.paste(original.resize((round(original.width * s), round(original.height * s)), Image.Resampling.LANCZOS), (ox, oy))
d = ImageDraw.Draw(preview)
grid(d, screen)
for region in SPEC['hud_reserved_rectangles']:
    x, y, w, h = region['rect']
    d.rounded_rectangle((x, y, x + w, y + h), radius=6, fill=(15, 36, 37), outline=(94, 130, 130), width=2)
    d.text((x + 10, y + 10), region['id'], font=small, fill=(219, 228, 215))
d.text((320, 1060), 'OFFLINE HUD FIT / reserved areas only / no runtime or character verification', font=small, fill='white')
preview.save(OUT / 'hud-fit-1920x1080.png')

samples = [(x, y) for y in range(8) for x in range(13)] + [(x + .5, y + .5) for y in range(7) for x in range(12)]
errors = [math.dist(q, inverse(*point(*q))) for q in samples]
corners = [point(x, y) for x, y in [(0, 0), (12, 0), (12, 7), (0, 7)]]
assert all(math.dist(a, b) < 1e-9 for a, b in zip(corners, SPEC['surface']['recommended_playable_corners']))
assert max(errors) < 1e-10
rect = D['interactive_safe_rect']
assert all(rect[0] <= x <= rect[0] + rect[2] and rect[1] <= y <= rect[1] + rect[3] for x, y in map(screen, corners))
def inside(p, rect):
    x, y, w, h = rect
    return x <= p[0] <= x + w and y <= p[1] <= y + h
centers = [screen(point(x + .5, y + .5)) for y in range(7) for x in range(12)]
assert not any(inside(p, h['rect']) for p in centers for h in SPEC['hud_reserved_rectangles'])
report = {
    'scope': 'offline proposed artwork mapping only; not runtime input/PCK/character/battle acceptance',
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'source_size': list(original.size),
    'grid': [12, 7], 'center_count': len(centers),
    'boundary_vertex_count': 104, 'offline_forward_inverse_samples': len(samples),
    'maximum_grid_coordinate_roundtrip_error': max(errors),
    'image_corners': corners, 'proposed_screen_corners': [screen(c) for c in corners],
    'row_boundaries_image_y': [point(0, y)[1] for y in range(8)],
    'all_centers_clear_of_reserved_hud': True,
    'top_bottom_actor_relative_scale': [R, 1],
    'runtime_tested': False,
    'preview_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'calibration-12x7.png', OUT/'hud-fit-1920x1080.png']},
}
(OUT / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
