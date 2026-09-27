"""Pack approved-design wolf key poses; no redraw or global color changes."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ART = Path(__file__).resolve().parents[2]
SOURCE = ART / 'concepts/mountain_wolf/mountain_wolf_action_keypose_sheet_v2.png'
OUT = ART / 'production/mountain_wolf/demo_v1'
OUT.mkdir(parents=True, exist_ok=True)
source = Image.open(SOURCE).convert('RGBA')
# Remove only sub-8/255 alpha noise; retain source alpha on visible fur.
alpha = source.getchannel('A').point(lambda x: 0 if x < 8 else x)
source.putalpha(alpha)
specs = [
    ('idle', (0,100,500,510), (245,487)),
    ('move', (500,100,1020,510), (750,486)),
    ('attack_impact', (1020,160,1536,510), (1270,487)),
    ('hit', (0,550,515,940), (245,914)),
    ('retreat', (515,680,1140,940), (795,905)),
]
scale = 0.30
atlas = Image.new('RGBA', (256*5,256))
review = Image.new('RGB', (256*5,512))
frames = []
for index, (name, box, anchor) in enumerate(specs):
    crop = source.crop(box)
    resized = crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
    offset = (128-round((anchor[0]-box[0])*scale),218-round((anchor[1]-box[1])*scale))
    frame = Image.new('RGBA',(256,256))
    frame.alpha_composite(resized,offset)
    # Normalize invisible RGB to zero to avoid misleading preview backgrounds.
    clean = Image.new('RGBA',frame.size)
    clean.alpha_composite(frame)
    filename = 'mountain_wolf_'+name+'_body_v1.png'
    clean.save(OUT/filename)
    atlas.paste(clean,(index*256,0))
    bbox = clean.getchannel('A').getbbox()
    assert bbox and bbox[0]>1 and bbox[1]>1 and bbox[2]<255 and bbox[3]<255
    frames.append(dict(index=index,name=name,body=True,file=filename,source_box=box,source_ground_anchor=anchor,target_bbox=bbox))
    for y, color in [(0,'#eee9dc'),(256,'#26313b')]:
        panel=Image.new('RGBA',(256,256),color)
        panel.alpha_composite(clean)
        draw=ImageDraw.Draw(panel)
        draw.text((8,8),name,fill='#777777')
        draw.line((124,218,132,218), fill='#34aaaa')
        review.paste(panel.convert('RGB'),(index*256,y))
atlas.save(OUT/'mountain_wolf_demo_body_atlas_v1.png')
review.save(OUT/'review-light-dark.png')
actions={
    'idle':dict(body_frames=[0],loop=True),
    'move':dict(body_frames=[1],loop=True),
    'basic_attack':dict(body_frames=[0,2],body_frame_seconds=[0.12,0.12],return_to='idle'),
    'hit':dict(body_frames=[3],hold_seconds=0.18,return_to='idle'),
    'retreat':dict(body_frames=[4],hold_seconds=0.45,fade_seconds=0.25),
}
manifest=dict(version=1,character='mountain_wolf',status='static_pose_pack_pending_engine_validation',
    source='art/concepts/mountain_wolf/'+SOURCE.name,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    frame=dict(width=256,height=256,foot_anchor=[128,218],display_scale=1),source_scale=scale,source_facing='left',
    anchor_method='Hand annotated ground projection; quadruped support line',
    atlases=dict(body='mountain_wolf_demo_body_atlas_v1.png',columns=5,rows=1),
    frames=frames,standalone_vfx={},actions=actions,
    known_limitations=['Single pose per state; idle reused as attack windup, not continuous animation.',
    'Source faces left: integration must account for renderer default facing before use.',
    'Anchor/attack contact and board occupancy require engine validation; no gameplay parameters confirmed.'])
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for f in frames:
    assert Image.open(OUT/f['file']).tobytes()==atlas.crop((f['index']*256,0,(f['index']+1)*256,256)).tobytes()
assert set(actions)=={'idle','move','basic_attack','hit','retreat'}
print('WOLF_STATIC_PACK_OK: 5 frames, atlas equality, margins, 5 actions; engine not tested')
