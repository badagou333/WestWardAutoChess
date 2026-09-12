"""Append four annotated recovery frames; preserve the previous eight images byte-for-byte."""
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from build_melee_motion import ART, components

ROOT = ART/'production/guard_monk'
OUT = ROOT/'motion_v2'
SCALE = 140 / 425
PIVOTS = [(424,481),(1108,486),(428,972),(1086,972)]
NAMES = ['return_lower','return_rotate','return_settle','ready_settled']
# Forward end of the staff, used to review the continuous return arc.
TIPS = [(753,339),(1320,400),(626,883),(1296,883)]


def build_recovery(root, scale, pivots, names, tips, unfold_scale=.86):
    out = root/'motion_v2'
    source = out/'generated-recovery-sheet.png'
    rgb = np.asarray(Image.open(source).convert('RGB')); values = rgb.astype(float)
    light = values.mean(2); chroma = values.max(2)-values.min(2)
    alpha = np.where(chroma > 20,1.,np.clip((185-light)/45,0,1))
    atlas = Image.new('RGBA',(3072,256))
    base = Image.open(root/'motion_v1/body-atlas.png').convert('RGBA')
    atlas.paste(base,(0,0))
    manifest = json.loads((root/'motion_v1/manifest.json').read_text(encoding='utf-8'))
    for frame in manifest['frames']:
        frame['file'] = '../motion_v1/'+frame['file']
        frame['source'] = '../motion_v1/generated-sheet.png'
    for i, points in enumerate(components(alpha > .45,expected=4)):
        support = np.zeros(alpha.shape,dtype='uint8'); yy,xx = np.array(points).T; support[yy,xx] = 255
        support = np.asarray(Image.fromarray(support).filter(ImageFilter.MaxFilter(5))) / 255
        opacity = np.rint(alpha*support*255).astype('uint8')
        rgba = np.dstack([rgb.copy(),opacity]); rgba[opacity==0,:3] = 0
        cutout = Image.fromarray(rgba); box = cutout.getbbox(); cutout = cutout.crop(box)
        small = cutout.resize((round(cutout.width*scale),round(cutout.height*scale)),Image.Resampling.LANCZOS)
        pivot = pivots[i]; offset = (round(128-(pivot[0]-box[0])*scale),round(218-(pivot[1]-box[1])*scale))
        assert min(offset)>1 and offset[0]+small.width<254 and offset[1]+small.height<254
        frame = Image.new('RGBA',(256,256)); frame.alpha_composite(small,offset)
        frame.save(out/(names[i]+'.png')); atlas.paste(frame,((8+i)*256,0))
        manifest['frames'].append({'index':8+i,'name':names[i],'file':names[i]+'.png','source':source.name,
                                   'source_box':box,'ground_anchor':pivot,'frame_bbox':frame.getbbox()})
    assert atlas.crop((0,0,2048,256)).tobytes() == base.tobytes()
    atlas.save(out/'body-atlas.png')
    manifest.update({'version':2,'source':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                     'base_atlas_sha256':hashlib.sha256((root/'motion_v1/body-atlas.png').read_bytes()).hexdigest(),
                     'source_scale':scale,'idle':11,
                     'attack_track':[{'phase':p,'fraction':f,'frame':i} for p,f,i in
                        [('windup',0,11),('windup',.2,4),('windup',.78,5),('release',0,6),
                         ('recover',0,8),('recover',.32,9),('recover',.58,10),('recover',.8,11)]],
                     'recovery_unfold':{'end_fraction':.58,'start_scale_y':unfold_scale},
                     'notes':['Eight motion_v1 frames unchanged; four recovery/ready frames appended.',
                              'Last recovery and idle use the same image, avoiding a final atlas swap.',
                              'Full walk/directional/hit/retreat continuity still pending.']})
    tip_key = {'guard_monk':'recovery_staff_tips', 'wild_hunter':'recovery_knife_tips',
               'bear_lord':'recovery_club_tips'}[root.name]
    manifest[tip_key] = [[round(128+(t[0]-p[0])*scale,2),round(218+(t[1]-p[1])*scale,2)] for t,p in zip(tips,pivots)]
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    contact = Image.new('RGB',(1536,568)); draw = ImageDraw.Draw(contact)
    for row,color in enumerate(['#17232d','#eadfc8']):
        draw.rectangle((0,row*284,1536,(row+1)*284),fill=color)
        for col,i in enumerate([5,6,8,9,10,11]):
            frame = atlas.crop((i*256,0,(i+1)*256,256)); contact.paste(frame,(col*256,row*284+28),frame)
            draw.text((col*256+12,row*284+8),manifest['frames'][i]['name'],fill='#79a8ad')
            draw.line((col*256+123,row*284+246,col*256+133,row*284+246),fill='#35abb5')
    contact.save(out/'recovery-contact.png')
    print(root.name.upper()+'_RECOVERY_PACK_OK: 4 new / 12 total; previous atlas pixels preserved')


def run():
    build_recovery(ROOT, SCALE, PIVOTS, NAMES, TIPS)


if __name__ == '__main__':
    run()
