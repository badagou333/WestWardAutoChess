"""Re-extract approved monk poses, removing enclosed neutral paper as well as exterior paper."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw
from build_four_role_demo import font, place, poly_mask
from pack_four_role_preview import pack

ART = Path(__file__).resolve().parents[2]
ROOT = ART / 'production/guard_monk/demo_v1'
# Ground contours exclude painted floor strokes between the actual feet.
POSES = [
    ('idle', [50,125,385,474], [202,464], [[50,125],[385,125],[385,455],[331,455],[331,468],[280,468],[279,445],[116,445],[113,464],[70,464],[70,443],[50,443]]),
    ('move', [410,146,740,489], [643,479], [[410,146],[740,146],[740,460],[677,460],[678,483],[611,483],[608,456],[500,456],[501,440],[458,451],[450,439],[410,439]]),
    ('attack_prepare', [744,164,1093,480], [885,472], [[744,164],[1093,164],[1093,265],[1040,285],[1020,435],[1008,450],[1010,475],[970,475],[967,450],[795,450],[794,462],[757,462],[754,445],[744,445]]),
    ('attack_impact', [1050,145,1528,485], [1231,474], [[1130,145],[1528,145],[1528,451],[1395,451],[1400,478],[1357,478],[1354,452],[1113,452],[1110,475],[1060,475],[1060,456],[1050,430],[1070,370],[1094,320],[1094,281],[1130,260]]),
    ('hit', [784,580,1133,920], [916,906], [[784,580],[1133,580],[1133,886],[981,886],[981,909],[929,909],[928,890],[856,886],[840,898],[790,898],[784,888]]),
    ('retreat', [1190,575,1527,921], [1331,910], [[1190,575],[1527,575],[1527,903],[1447,913],[1333,911],[1252,910],[1200,909],[1190,898]]),
]


def run():
    source_path = ART / 'concepts/guard_monk/guard_monk_action_keypose_sheet_v2.png'
    source = Image.open(source_path).convert('RGB')
    scale = 140 / (464 - 135)
    atlas = Image.new('RGBA', (1536,256))
    report = []
    for index, (name, box, pivot, polygon) in enumerate(POSES):
        rgb = np.asarray(source.crop(box)).copy()
        values = rgb.astype(float)
        light = values.mean(2)
        chroma = values.max(2) - values.min(2)
        # Warm white fur differs from the near-neutral paper. Never fill enclosed holes.
        alpha = np.where(chroma > 25, 1., np.clip((165-light)/40, 0, 1))
        alpha *= poly_mask((box[2]-box[0], box[3]-box[1]), polygon, box)
        pixels = np.dstack((rgb, np.rint(alpha*255).astype('uint8')))
        pixels[alpha==0,:3] = 0
        frame, offset = place(Image.fromarray(pixels), box, pivot, scale)
        frame.save(ROOT / f'guard_monk_{name}_v1.png')
        atlas.alpha_composite(frame, (index*256, 0))
        report.append({'name':name,'source_box':box,'source_ground_anchor':pivot,'frame_offset':offset,'frame_bbox':frame.getbbox()})
    atlas.save(ROOT / 'guard_monk_demo_pose_atlas_v1.png')
    contact = Image.new('RGB', (1536,568))
    draw = ImageDraw.Draw(contact)
    for row, color in enumerate(['#17232d','#eadfc8']):
        draw.rectangle((0,row*284,1536,(row+1)*284),fill=color)
        for i,(name,*_) in enumerate(POSES):
            frame=atlas.crop((i*256,0,(i+1)*256,256))
            contact.paste(frame,(i*256,row*284+28),frame)
            draw.text((i*256+12,row*284+4),name,font=font(16),fill='#d9e5ed' if row==0 else '#26313a')
            x,y=i*256+128,row*284+246
            draw.line((x-6,y,x+6,y),fill='#35abb5')
            draw.line((x,y-6,x,y+6),fill='#35abb5')
    contact.save(ROOT/'guard_monk_demo_action_board_contact_v1.png')
    manifest_path=ROOT/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['source_sha256']=hashlib.sha256(source_path.read_bytes()).hexdigest()
    manifest['processing_revision']='2026-09-08-neutral-paper-cleanup'
    manifest['source_scale']=scale
    manifest['anchor_method']='Hand-annotated body ground point, same scale for all poses; dynamic alignment pending review.'
    manifest['extraction']=report
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    pack()
    print('MONK_REEXTRACTED: 6 source poses, fixed-size atlas and dark/light contact')


if __name__=='__main__':
    run()
