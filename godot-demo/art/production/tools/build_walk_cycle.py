"""Append reviewed eight-phase walk sprites without changing the prior motion atlas."""
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from build_melee_motion import ART, components

NAMES = ['walk_contact_a','walk_down_a','walk_pass_a','walk_up_a',
         'walk_contact_b','walk_down_b','walk_pass_b','walk_up_b']

def build_walk(role, scale, pivots, feet):
    root = ART/'production'/role
    out = root/'motion_v3'
    source = out/'generated-walk-sheet.png'
    previous = root/'motion_v2'
    manifest = json.loads((previous/'manifest.json').read_text(encoding='utf-8'))
    base = Image.open(previous/'body-atlas.png').convert('RGBA')
    base_count = len(manifest['frames'])
    assert base.size == (base_count*256,256)
    for item in manifest['frames']:
        for key in ('file','source'):
            if key in item and not item[key].startswith('../'):
                item[key] = '../motion_v2/'+item[key]
    image = Image.open(source)
    rgb = np.asarray(image.convert('RGB'))
    values = rgb.astype(float)
    light = values.mean(2); chroma = values.max(2)-values.min(2)
    alpha = (np.asarray(image.getchannel('A'))/255 if image.mode == 'RGBA'
             else np.where(chroma>20,1.,np.clip((185-light)/45,0,1)))
    atlas = Image.new('RGBA',((base_count+8)*256,256)); atlas.paste(base,(0,0))
    poses = components(alpha>.45)
    assert len(poses) == len(NAMES), 'Expected exactly eight separate walk poses'
    for i,points in enumerate(poses):
        support = np.zeros(alpha.shape,dtype='uint8')
        yy,xx = np.array(points).T; support[yy,xx] = 255
        support = np.asarray(Image.fromarray(support).filter(ImageFilter.MaxFilter(5)))/255
        opacity = np.rint(alpha*support*255).astype('uint8')
        rgba = np.dstack([rgb.copy(),opacity]); rgba[opacity==0,:3] = 0
        cutout = Image.fromarray(rgba); box = cutout.getbbox()
        assert 0<box[0]<box[2]<image.width and 0<box[1]<box[3]<image.height
        cutout = cutout.crop(box)
        small = cutout.resize((round(cutout.width*scale),round(cutout.height*scale)),Image.Resampling.LANCZOS)
        pivot = pivots[i]
        offset = (round(128-(pivot[0]-box[0])*scale),round(218-(pivot[1]-box[1])*scale))
        assert min(offset)>1 and offset[0]+small.width<254 and offset[1]+small.height<254
        frame = Image.new('RGBA',(256,256)); frame.alpha_composite(small,offset)
        frame.save(out/(NAMES[i]+'.png')); atlas.paste(frame,((base_count+i)*256,0))
        manifest['frames'].append({'index':base_count+i,'name':NAMES[i],'file':NAMES[i]+'.png',
                                  'source':source.name,'source_box':box,'ground_anchor':pivot,'frame_bbox':frame.getbbox()})
    atlas.save(out/'body-atlas.png')
    assert atlas.crop((0,0,base.width,256)).tobytes() == base.tobytes()
    ready = manifest['idle']
    manifest.update({'version':3,'source':source.name,
                     'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                     'base_atlas_sha256':hashlib.sha256((previous/'body-atlas.png').read_bytes()).hexdigest(),
                     'base_manifest':'../motion_v2/manifest.json','source_scale':scale,
                     'move':[ready]+list(range(base_count,base_count+8))+[ready],
                     'walk_source_feet':feet,
                     'notes':['Previous motion_v2 atlas pixels and attack track preserved.',
                              'Eight walk poses appended, alternating screen-left and screen-right swing feet.',
                              'Departure/arrival share ready pose; eight alternating-leg candidate poses play during each board move.',
                              'Foot sliding and uneven swing distance remain; this is not a physically complete gait.',
                              'New walk drawings are trial candidates; not a formal directional-animation acceptance.']})
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    contact = Image.new('RGB',(2048,568)); draw = ImageDraw.Draw(contact)
    for row,color in enumerate(['#17232d','#eadfc8']):
        draw.rectangle((0,row*284,2048,(row+1)*284),fill=color)
        for i,name in enumerate(NAMES):
            frame = atlas.crop(((base_count+i)*256,0,(base_count+i+1)*256,256))
            contact.paste(frame,(i*256,row*284+28),frame)
            draw.text((i*256+10,row*284+8),name,fill='#79a8ad')
            draw.line((i*256+123,row*284+246,i*256+133,row*284+246),fill='#35abb5')
    contact.save(out/'walk-contact.png')
    print(role.upper()+'_WALK_PACK_OK: 8 new, '+str(base_count+8)+' total, previous atlas unchanged')
