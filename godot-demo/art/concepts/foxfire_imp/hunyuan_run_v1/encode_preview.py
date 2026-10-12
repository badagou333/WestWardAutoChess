"""Encode actual Blender frames, including a phase contact sheet for review."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

BASE = Path(__file__).resolve().parent
reports = []
for view in ('front', 'side'):
    paths = sorted((BASE/'preview_frames').glob(view+'-*.png'))
    assert len(paths) == 24
    frames = [Image.open(p).convert('RGB') for p in paths]
    out = BASE/f'run-{view}.gif'
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=[30,30,40]*8,
                   loop=0, disposal=2, optimize=False)
    with Image.open(out) as check:
        duration = 0
        for i in range(check.n_frames):
            check.seek(i)
            check.load()
            duration += check.info.get('duration',0)
        assert check.n_frames == 24 and duration == 800
    reports.append({'file':out.name,'frames':24,'duration_ms':duration,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    sheet = Image.new('RGB',(1280,680),(25,29,36))
    draw = ImageDraw.Draw(sheet)
    for cell, index in enumerate((0,3,6,9,12,15,18,21)):
        x,y = (cell%4)*320,(cell//4)*340
        sheet.paste(frames[index].resize((320,320)),(x,y+20))
        draw.text((x+12,y+4),f'FRAME {index+1:02} / 30 FPS',fill='white')
    sheet.save(BASE/f'run-{view}-poses.jpg',quality=92)
(BASE/'preview-report.json').write_text(json.dumps({'date':'2026-10-13','source':'Native Blender skinned model renders; no 2D warping',
    'glb_sha256':hashlib.sha256((BASE/'foxfire-run.glb').read_bytes()).hexdigest(),'previews':reports},indent=2)+'\n')
print(json.dumps(reports))
