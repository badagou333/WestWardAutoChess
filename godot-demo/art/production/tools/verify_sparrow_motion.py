"""Check wing-cast files, full source boundaries and the release feather-tip annotation."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / 'production/sparrow_spirit/motion_v1'
manifest = json.loads((ROOT/'manifest.json').read_text())
atlas = Image.open(ROOT/manifest['atlas']).convert('RGBA')
assert atlas.size == (2048,256)
for frame in manifest['frames']:
    image = Image.open(ROOT/frame['file']).convert('RGBA')
    assert image.size == (256,256)
    assert image.tobytes() == atlas.crop((frame['index']*256,0,(frame['index']+1)*256,256)).tobytes()
    alpha = np.array(image)[:,:,3]
    assert not any(np.any(edge) for edge in (alpha[:2],alpha[-2:],alpha[:,:2],alpha[:,-2:]))
    x0,y0,x1,y1 = frame['source_box']
    assert 0 < x0 < x1 < 1536 and 0 < y0 < y1 < 1024
    # All annotated feather tips must be near retained wing pixels, not empty former VFX.
    px,py = (round(v) for v in manifest['emission_sockets'][frame['index']])
    assert alpha[py-3:py+4,px-3:px+4].max() > 200, f'Tip outside wing: {frame["name"]}'
assert manifest['idle'] == manifest['attack_track'][0]['frame'] == manifest['attack_track'][-1]['frame']
assert 'hand_sockets' not in manifest and 'charge_effect' not in manifest
print('SPARROW_MOTION_ASSETS_OK: 8 frames, atlas equality, source/frame margins, feather-tip sockets, closed ready loop')
