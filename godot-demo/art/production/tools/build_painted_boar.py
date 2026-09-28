"""Crop and pack existing-Demo boar key poses without redrawing or recoloring."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops

ART = Path(__file__).resolve().parents[2]
ROOT = ART / 'reviews/style-unification-v1'
OUT = ART / 'production/boar/painted_v1'
OUT.mkdir(parents=True, exist_ok=True)
sheet = Image.open(ROOT/'boar-four-actions.png').convert('RGBA')
idle = Image.open(ROOT/'boar-idle-candidate.png').convert('RGBA')
for source in (sheet, idle):
    source.putalpha(source.getchannel('A').point(lambda a: 0 if a < 8 else a))
# Manual bounds through transparent gaps; preserve approved idle unchanged.
polygons = [
    [(0,0),(idle.width,0),(idle.width,idle.height),(0,idle.height)],
    [(0,0),(710,0),(710,535),(0,535)],
    [(711,0),(1536,0),(1536,535),(711,535)],
    [(0,536),(768,536),(768,1024),(0,1024)],
    [(769,536),(1536,536),(1536,1024),(769,1024)],
]
specs = [
    ('idle',idle,(740,1101),.1125),
    ('move',sheet,(490,528),.225),
    ('attack_impact',sheet,(1260,528),.225),
    ('hit',sheet,(480,983),.225),
    ('retreat',sheet,(1200,979),.225),
]
atlas = Image.new('RGBA',(1280,256))
review = Image.new('RGB',(1280,512))
frames=[]
for i, (name,source,anchor,scale) in enumerate(specs):
    mask = Image.new('L',source.size)
    ImageDraw.Draw(mask).polygon(polygons[i],fill=255)
    selected = source.copy()
    selected.putalpha(ImageChops.multiply(source.getchannel('A'),mask))
    box=selected.getbbox()
    assert box
    crop=selected.crop(box)
    small=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
    offset=(128-round((anchor[0]-box[0])*scale),218-round((anchor[1]-box[1])*scale))
    frame=Image.new('RGBA',(256,256))
    frame.alpha_composite(small,offset)
    bbox=frame.getbbox()
    assert bbox and bbox[0]>1 and bbox[1]>1 and bbox[2]<255 and bbox[3]<255,(name,bbox)
    filename=f'boar_{name}_body_v1.png'
    frame.save(OUT/filename)
    atlas.paste(frame,(i*256,0))
    frames.append(dict(index=i,name=name,body=True,file=filename,source_box=box,
        source_polygon=polygons[i],source_ground_anchor=anchor,source_scale=scale,target_bbox=bbox,
        source='boar-idle-candidate.png' if name=='idle' else 'boar-four-actions.png'))
    for y,color in [(0,'#eee9dc'),(256,'#26313b')]:
        panel=Image.new('RGBA',(256,256),color)
        panel.alpha_composite(frame)
        draw=ImageDraw.Draw(panel)
        draw.text((8,8),name,fill='#777777')
        draw.line((124,218,132,218),fill='#34aaaa')
        review.paste(panel.convert('RGB'),(i*256,y))
atlas.save(OUT/'boar_demo_body_atlas_v1.png')
review.save(OUT/'review-light-dark.png')
actions={
    'idle':dict(body_frames=[0],loop=True),
    'move':dict(body_frames=[1],loop=True),
    'basic_attack':dict(body_frames=[0,2],body_frame_seconds=[.12,.12],return_to='idle'),
    'hit':dict(body_frames=[3],hold_seconds=.18,return_to='idle'),
    'retreat':dict(body_frames=[4],hold_seconds=.45,fade_seconds=.25),
}
sources=[dict(path='art/reviews/style-unification-v1/'+name,sha256=hashlib.sha256((ROOT/name).read_bytes()).hexdigest())
    for name in ('boar-idle-candidate.png','boar-four-actions.png')]
manifest=dict(version=1,character='boar',status='static_pose_pack_pending_engine_validation',
    sources=sources,frame=dict(width=256,height=256,foot_anchor=[128,218],display_scale=1),
    source_facing='left',anchor_method='Hand annotated biped ground projection; not per-frame bbox centering',
    atlases=dict(body='boar_demo_body_atlas_v1.png',columns=5,rows=1),frames=frames,standalone_vfx={},actions=actions,
    known_limitations=['Static key poses, not continuous animation or a complete walking cycle.',
        'Mace ornament and face details drift slightly between generated poses.',
        'Engine facing, scale, attack contact and transition timing require integration validation.',
        'Approved painted idle retained; original demo_v1 pack is untouched; engine switch is pending.'])
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for f in frames:
    assert Image.open(OUT/f['file']).tobytes()==atlas.crop((f['index']*256,0,(f['index']+1)*256,256)).tobytes()
assert len(actions)==5
print('BOAR_STATIC_PACK_OK: five 256px RGBA frames; margins, atlas equality, action mapping passed')
