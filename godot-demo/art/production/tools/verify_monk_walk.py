"""Validate preserved attacks, packaged walk frames, and both visible swing feet."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]/'production/guard_monk'
OUT = ROOT/'motion_v3'
data = json.loads((OUT/'manifest.json').read_text())
previous = json.loads((ROOT/'motion_v2/manifest.json').read_text())
atlas = Image.open(OUT/'body-atlas.png').convert('RGBA')
base = Image.open(ROOT/'motion_v2/body-atlas.png').convert('RGBA')
assert atlas.size == (5120,256)
assert atlas.crop((0,0,3072,256)).tobytes() == base.tobytes()
assert data['attack_track'] == previous['attack_track'] and data['idle'] == previous['idle']
assert data['move'][0] == data['move'][-1] == data['idle'] == 11
for item in data['frames']:
    frame = Image.open(OUT/item['file']).convert('RGBA')
    assert frame.size == (256,256)
    assert frame.tobytes() == atlas.crop((item['index']*256,0,(item['index']+1)*256,256)).tobytes()
    alpha = np.asarray(frame)[:,:,3]
    assert not any(np.any(edge) for edge in (alpha[:2],alpha[-2:],alpha[:,:2],alpha[:,-2:]))
    if item['index'] >= 12:
        x0,y0,x1,y1 = item['source_box']
        assert 0<x0<x1<1536 and 0<y0<y1<1024
        pivot = item['ground_anchor']
        for foot in data['walk_source_feet'][item['index']-12]:
            x = round(128+(foot[0]-pivot[0])*data['source_scale'])
            y = round(218+(foot[1]-pivot[1])*data['source_scale'])
            assert alpha[y-4:y+5,x-4:x+5].max()>200, item['name']+' foot annotation outside paw'
# Image-derived annotations: one side swings in phase A, the other in phase B.
feet_a = data['walk_source_feet'][2]
feet_b = data['walk_source_feet'][5]
assert feet_a[1][1]-feet_a[0][1] >= 20
assert feet_b[0][1]-feet_b[1][1] >= 30
print('MONK_WALK_ASSETS_OK: 20 frames; old 12 and attacks unchanged; margins/feet/alternating lift checked')
