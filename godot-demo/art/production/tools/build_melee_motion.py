"""Pack generated limb poses; preserve demo_v1 and make the neutral checker matte reproducible."""
from pathlib import Path
from collections import deque
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ART = Path(__file__).resolve().parents[2]
NAMES = ['walk_contact', 'walk_pass', 'walk_opposite', 'walk_return',
         'attack_windup', 'attack_accelerate', 'attack_impact', 'attack_recover']
# Annotated body ground projections, deliberately independent of weapon bounding boxes.
ROLES = {
    'guard_monk': (140 / 370, [(206,493),(585,493),(958,494),(1308,497),
                              (186,932),(551,930),(937,932),(1360,933)]),
    'wild_hunter': (136 / 377, [(218,487),(595,487),(976,488),(1348,488),
                               (204,943),(581,943),(948,943),(1341,947)]),
    'bear_lord': (148 / 354, [(171,466),(566,466),(950,466),(1335,466),
                             (188,923),(570,923),(948,923),(1334,928)]),
}


def components(mask):
    pending = mask.copy()
    found = []
    height, width = pending.shape
    for y, x in zip(*np.where(mask)):
        if not pending[y, x]:
            continue
        queue = deque([(int(y), int(x))]); pending[y, x] = False
        pixels = []
        while queue:
            py, px = queue.popleft(); pixels.append((py, px))
            for ny, nx in [(py-1,px),(py+1,px),(py,px-1),(py,px+1)]:
                if 0 <= ny < height and 0 <= nx < width and pending[ny,nx]:
                    pending[ny,nx] = False; queue.append((ny,nx))
        if len(pixels) > 1500:
            found.append(pixels)
    assert len(found) == 8, f'Expected 8 separate silhouettes, got {len(found)}'
    return sorted(found, key=lambda p: (int(np.mean([v[0] for v in p]) > 512), min(v[1] for v in p)))


def run(roles=ROLES, names=NAMES, metadata=None):
    report = {}
    for role, (scale, pivots) in roles.items():
        dest = ART / 'production' / role / 'motion_v1'
        source = dest / 'generated-sheet.png'
        rgb = np.asarray(Image.open(source).convert('RGB'))
        values = rgb.astype(float)
        light = values.mean(2); chroma = values.max(2) - values.min(2)
        # Grey checker pixels are bright and neutral; cream fur/metal stay warm.
        alpha = np.where(chroma > 20, 1., np.clip((185-light)/45, 0, 1))
        silhouettes = components(alpha > 0.45)
        atlas = Image.new('RGBA', (2048,256))
        frames = []
        for i, points in enumerate(silhouettes):
            support = np.zeros(alpha.shape, dtype='uint8')
            yy, xx = np.array(points).T; support[yy,xx] = 255
            support = np.asarray(Image.fromarray(support).filter(ImageFilter.MaxFilter(5))) / 255
            opacity = np.rint(alpha * support * 255).astype('uint8')
            rgba = np.dstack([rgb.copy(), opacity]); rgba[opacity == 0,:3] = 0
            cutout = Image.fromarray(rgba)
            box = cutout.getbbox(); cutout = cutout.crop(box)
            resized = cutout.resize((round(cutout.width*scale), round(cutout.height*scale)), Image.Resampling.LANCZOS)
            pivot = pivots[i]
            offset = (round(128-(pivot[0]-box[0])*scale), round(218-(pivot[1]-box[1])*scale))
            assert offset[0] >= 2 and offset[1] >= 2
            assert offset[0]+resized.width < 254 and offset[1]+resized.height < 254
            frame = Image.new('RGBA',(256,256)); frame.alpha_composite(resized, offset)
            frame.save(dest / (names[i]+'.png')); atlas.alpha_composite(frame,(i*256,0))
            frames.append({'index':i,'name':names[i],'source_box':box,'ground_anchor':pivot,
                           'frame_bbox':frame.getbbox(),'file':names[i]+'.png'})
        atlas.save(dest/'body-atlas.png')
        manifest = {'version':1,'character':role,'status':'trial_motion_candidate',
                    'source':'generated-sheet.png','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                    'atlas':'body-atlas.png','frame_size':[256,256],'foot_anchor':[128,218],
                    'source_scale':scale,'frames':frames,
                    'move':[0,1,2,3], 'attack':{'windup':4,'accelerate':5,'impact':6,'recover':7},
                    'notes':['Generated limb poses, neutral checker removed locally; demo_v1 preserved.',
                             'Ground projections are manually annotated; not bounding-box centered.',
                             'Short trial sequences, not an accepted full directional walk cycle.']}
        if metadata:
            manifest.update(metadata)
        (dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        contact = Image.new('RGB',(2048,568)); draw = ImageDraw.Draw(contact)
        for row, color in enumerate(['#17232d','#eadfc8']):
            draw.rectangle((0,row*284,2048,(row+1)*284), fill=color)
            for i, name in enumerate(names):
                frame = atlas.crop((i*256,0,(i+1)*256,256))
                contact.paste(frame,(i*256,row*284+28),frame)
                draw.text((i*256+10,row*284+8),name,fill='#799fa5')
                x,y = i*256+128,row*284+246
                draw.line((x-5,y,x+5,y),fill='#35abb5'); draw.line((x,y-5,x,y+5),fill='#35abb5')
        contact.save(dest/'contact-dark-light.png')
        report[role] = {'frames':len(frames),'unique_pixel_hashes':len({hashlib.sha256(atlas.crop((i*256,0,(i+1)*256,256)).tobytes()).hexdigest() for i in range(8)})}
    print(json.dumps(report))


if __name__ == '__main__':
    run()
