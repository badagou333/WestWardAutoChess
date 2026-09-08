"""Rebuild fox body/VFX from approved art, preserving warm fur and flame cores."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw
from build_four_role_demo import font, place, poly_mask
from pack_four_role_preview import pack

ART = Path(__file__).resolve().parents[2]
ROOT = ART / 'production/foxfire_imp/demo_v1'
SCALE = 124 / 360
POSES = [
    ('idle',[102,35,411,410],[225,399],[[164,35],[411,35],[411,408],[102,408],[102,215],[159,215],[164,190]]),
    ('move',[427,86,801,410],[602,395],None),
    ('attack_prepare',[883,113,1211,404],[1020,396],None),
    ('attack_impact',[1240,77,1583,409],[1410,400],None),
    ('hit',[916,490,1277,830],[1026,820],[[976,490],[1277,490],[1277,786],[1121,786],[1081,801],[1047,801],[1036,822],[1005,822],[1005,798],[970,779],[958,796],[916,791],[916,770],[937,749],[942,722],[948,670],[970,642],[976,610]]),
    ('retreat',[1304,564,1596,834],[1430,821],[[1304,564],[1596,564],[1596,665],[1543,665],[1543,807],[1479,831],[1304,831]]),
]
EFFECTS = [
    ('idle_flame',0,[80,83,151,217],None),
    ('basic_projectile',3,[1586,186,1695,252],None),
    ('retreat_flame',5,[1545,673,1608,798],[[1545,673],[1608,673],[1608,779],[1591,779],[1583,789],[1564,789],[1550,780],[1545,755]]),
]


def cut(source,box,polygon=None):
    rgb=np.asarray(source.crop(box)).copy()
    value=rgb.astype(float)
    chroma=value.max(2)-value.min(2)
    light=value.mean(2)
    # Paper is near-neutral; white fur and flame cores are warm. Do not fill holes.
    # The few near-white core pixels exceed the paper's brightness; retain them.
    alpha=np.where((chroma>25)|(light>225),1.,np.clip((165-light)/40,0,1))
    if polygon:
        alpha*=poly_mask((box[2]-box[0],box[3]-box[1]),polygon,box)
    pixels=np.dstack((rgb,np.rint(alpha*255).astype('uint8')))
    pixels[alpha==0,:3]=0
    return Image.fromarray(pixels)


def run():
    source_path=ART/'concepts/foxfire_imp/foxfire_imp_action_keypose_sheet_v1.png'
    source=Image.open(source_path).convert('RGB')
    manifest_path=ROOT/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    body_atlas=Image.new('RGBA',(1536,256));fx_atlas=Image.new('RGBA',(1536,256))
    frames=[];extraction=[]
    for i,(name,box,pivot,polygon) in enumerate(POSES):
        frame,offset=place(cut(source,box,polygon),box,pivot,SCALE)
        frame.save(ROOT/f'foxfire_imp_{name}_body_v1.png')
        body_atlas.alpha_composite(frame,(i*256,0));frames.append(frame)
        extraction.append({'name':name,'source_box':box,'source_ground_anchor':pivot,'frame_offset':offset})
    for effect,index,box,polygon in EFFECTS:
        image=cut(source,box,polygon)
        aligned,_=place(image,box,POSES[index][2],SCALE)
        aligned.save(ROOT/f'foxfire_imp_{POSES[index][0]}_vfx_v1.png')
        fx_atlas.alpha_composite(aligned,(index*256,0))
        bbox=aligned.getbbox();crop=aligned.crop(bbox)
        assert crop.width<=60 and crop.height<=60
        compact=Image.new('RGBA',(64,64))
        offset=(32-crop.width//2,32-crop.height//2)
        compact.alpha_composite(crop,offset)
        compact.save(ROOT/manifest['standalone_vfx'][effect]['file'])
        manifest['standalone_vfx'][effect]['aligned_center_trial']=[bbox[0]+32-offset[0],bbox[1]+32-offset[1]]
        manifest['standalone_vfx'][effect]['source_box']=box
    body_atlas.save(ROOT/'foxfire_imp_demo_body_atlas_v1.png')
    fx_atlas.save(ROOT/'foxfire_imp_demo_vfx_atlas_v1.png')
    contact=Image.new('RGB',(1536,568));draw=ImageDraw.Draw(contact)
    for row,bg in enumerate(['#17232d','#eadfc8']):
        draw.rectangle((0,row*284,1536,(row+1)*284),fill=bg)
        for i,(name,*_) in enumerate(POSES):
            combined=frames[i].copy();combined.alpha_composite(fx_atlas.crop((i*256,0,(i+1)*256,256)))
            contact.paste(combined,(i*256,row*284+28),combined)
            draw.text((i*256+12,row*284+4),name,font=font(16),fill='#e8edf2' if row==0 else '#26313a')
            x,y=i*256+128,row*284+246
            draw.line((x-6,y,x+6,y),fill='#35abb5');draw.line((x,y-6,x,y+6),fill='#35abb5')
    contact.save(ROOT/'foxfire_imp_demo_action_board_contact_v1.png')
    layers=Image.new('RGB',(768,852),'#17232d');draw=ImageDraw.Draw(layers)
    for col,index in enumerate([0,3,5]):
        fx=fx_atlas.crop((index*256,0,(index+1)*256,256))
        combined=frames[index].copy();combined.alpha_composite(fx)
        for row,layer in enumerate([frames[index],fx,combined]):
            layers.paste(layer,(col*256,row*284+28),layer)
            draw.text((col*256+12,row*284+4),POSES[index][0]+' / '+['body','vfx','combined'][row],font=font(16),fill='#e8edf2')
    layers.save(ROOT/'foxfire_imp_demo_layer_contact_v1.png')
    manifest['source_sha256']=hashlib.sha256(source_path.read_bytes()).hexdigest()
    manifest['processing_revision']='2026-09-08-neutral-paper-cleanup'
    manifest['source_scale']=SCALE
    manifest['anchor_method']='Hand-annotated body ground projection; airborne move uses torso projection. Dynamic review pending.'
    manifest['extraction']=extraction
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    pack()
    print('FOX_REEXTRACTED: 6 bodies, 3 aligned VFX, 3 compact effects, 2 atlases')


if __name__=='__main__':
    run()
