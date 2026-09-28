"""Non-runtime style comparison: composite unchanged hero and candidate boar."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent
ART=ROOT.parents[1]
board=Image.open(ROOT/'battlefield-candidate.png').convert('RGBA').resize((1920,1080),Image.Resampling.LANCZOS)
hero_path=ART/'production/guard_monk/demo_v1/guard_monk_idle_v1.png'
hero=Image.open(hero_path).convert('RGBA')
boar=Image.open(ROOT/'boar-idle-candidate.png').convert('RGBA')
alpha=boar.getchannel('A')
box=alpha.point(lambda a:255 if a>=8 else 0).getbbox()
assert box and box[0]>0 and box[1]>0 and box[2]<boar.width and box[3]<boar.height
hero=hero.resize((282,282),Image.Resampling.LANCZOS)
# Preserve hero's authored anchor rather than centering visible mass.
board.alpha_composite(hero,(803-round(128*1.1),690-round(218*1.1)))
boar.putalpha(alpha.point(lambda a:0 if a<8 else a))
boar=boar.crop(box)
boar=boar.resize((round(boar.width*165/boar.height),165),Image.Resampling.LANCZOS)
board.alpha_composite(boar,(1127-boar.width//2,690-boar.height))
draw=ImageDraw.Draw(board)
draw.rectangle((20,20,530,59),fill=(25,27,25,225))
draw.text((32,32),'STYLE CANDIDATE / STATIC COMPOSITE / NOT IN-GAME',fill='#ddd5bf')
draw.ellipse((946,557,984,595),outline='#a89b74',width=2)
draw.text((937,602),'ESCORT',fill='#332f29')
board.convert('RGB').save(ROOT/'style-preview.png')
# Separate calibration diagnostic; lines show engine geometry, not painted seams.
for c in range(8):
    x=398+c*162
    draw.line((x,294,x,859),fill=(72,178,183,180),width=2)
for r in range(6):
    y=294+r*113
    draw.line((398,y,1532,y),fill=(72,178,183,180),width=2)
board.convert('RGB').save(ROOT/'grid-diagnostic.png')
validation=dict(status='candidate_pending_user_review',runtime_modified=False,
    boar_alpha_extrema=alpha.getextrema(),boar_subject_bbox=box,
    preview_size=[1920,1080],boar_preview_height=165,
    reference_hero=str(hero_path.relative_to(ART)),
    engine_grid=dict(origin=[398,294],cell=[162,113],rows=5,columns=7),
    limitations=['Painted grid has perspective and does not align with engine cells.',
        'Center ring only marks Tang Seng reservation; no new escort art.',
        'Static composition, not engine screenshot or animation validation.'],
    sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
        for name in ('battlefield-candidate.png','boar-idle-candidate.png')})
(ROOT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(validation,ensure_ascii=False))
