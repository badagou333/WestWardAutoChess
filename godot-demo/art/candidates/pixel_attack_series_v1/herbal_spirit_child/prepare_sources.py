#!/usr/bin/env python3
"""Register planted source pixels and prepare two small healing FX motifs."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
SUPPORT_ROIS=[
    [[160,440,210,515],[218,456,305,515],[334,455,426,515]],
    [[640,440,686,515],[695,455,784,515],[817,455,910,515]],
    [[1145,440,1195,515],[1195,455,1288,515],[1318,455,1414,515]],
    [[159,950,209,1023],[213,966,301,1023],[333,966,426,1023]],
    [[634,950,679,1023],[690,966,777,1023],[812,966,905,1023]],
    [[1145,950,1195,1023],[1194,966,1286,1023],[1318,966,1414,1023]],
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def low_point(image,box):
    l,t,r,b=box;a=np.asarray(image)[t:b,l:r,3]
    ys,xs=np.nonzero(a>=128);y=int(ys.max())
    return [int(np.median(xs[ys==y])+l),y+t]


def fx_crop(image,box,width):
    crop=image.crop(tuple(box));a=np.asarray(crop).copy()
    a[a[:,:,3]<8]=0;crop=Image.fromarray(a)
    tight=crop.getbbox();crop=crop.crop(tight)
    height=round(crop.height*width/crop.width)
    return crop.resize((width,height),Image.Resampling.NEAREST),{
        'source_box':box,'retained_alpha_min':8,'tight_box_within_crop':list(tight),
        'size':[width,height],'resampling':'nearest'}


def layer_file(root,name,image,position):
    canvas=Image.new('RGBA',(448,448));canvas.alpha_composite(image,tuple(position))
    canvas.save(root/'fx'/f'{name}.png')
    return {'file':f'fx/{name}.png','position':position,'size':list(image.size),
            'visible_bbox':list(canvas.getbbox()) if canvas.getbbox() else None,
            'projectile_view_edge_clip':position[0]+image.width>448}


def main():
    source=Image.open(ROOT/'source/body_sheet.webp').convert('RGBA')
    image=source.copy();a=np.asarray(source);changed=np.zeros(a.shape[:2],dtype=bool)
    points=[[low_point(source,box) for box in row] for row in SUPPORT_ROIS]
    reference_staff=points[0][0]
    foot_x=[points[0][i][0]-reference_staff[0] for i in (1,2)]
    reports=[]
    for index,row in enumerate(SUPPORT_ROIS):
        staff=points[index][0]
        feet=[]
        for which,roi in enumerate(row[1:]):
            point=points[index][which+1]
            dx=staff[0]+foot_x[which]-point[0];dy=staff[1]-point[1]
            l,t,r,b=roi
            crop=source.crop(tuple(roi));image.paste((0,0,0,0),tuple(roi));image.paste(crop,(l+dx,t+dy))
            changed[min(t,t+dy):max(b,b+dy),min(l,l+dx):max(r,r+dx)]=True
            feet.append({'roi':roi,'original_low_point':point,'registration':[dx,dy],
                         'registered_low_point':[point[0]+dx,point[1]+dy]})
        reports.append({'pose':index,'staff_anchor':staff,'feet':feet})
    # The ring is a rigid object. Use the already painted reference ring top
    # at a fixed offset from the planted staff tip, without changing a body.
    ring_box=[108,0,254,120]
    ring=source.crop(tuple(ring_box))
    ring_records=[]
    for index,row in enumerate(points):
        dx=row[0][0]-reference_staff[0];dy=row[0][1]-reference_staff[1]
        box=[ring_box[0]+dx,ring_box[1]+dy,ring_box[2]+dx,ring_box[3]+dy]
        image.paste(ring,(box[0],box[1]));changed[box[1]:box[3],box[0]:box[2]]=True
        ring_records.append({'pose':index,'source_ring_box':ring_box,'target_box':box,
                             'rigid_head_rgba_from_pose0':True})
    registered=np.asarray(image)
    assert np.array_equal(registered[~changed],a[~changed])
    target=ROOT/'source/body_registered.webp';image.save(target,lossless=True,exact=True)
    assert Image.open(target).convert('RGBA').tobytes()==image.tobytes()
    report={'source':'source/body_sheet.webp','body_alpha_threshold':128,
            'source_edges_opaque_at_threshold':[int((a[0,:,3]>=128).sum()),int((a[-1,:,3]>=128).sum()),
                                               int((a[:,0,3]>=128).sum()),int((a[:,-1,3]>=128).sum())],
            'common_source_foot_x_from_staff':foot_x,'all_three_contacts_share_source_y':True,
            'supports':reports,'ring_top_registration':ring_records,
            'outside_declared_rois_rgba_exact':True,'whole_character_transform':False,
            'registered_file_sha256':sha(target.read_bytes()),'registered_rgba_sha256':sha(image.tobytes())}
    (ROOT/'source/preparation_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    fx=Image.open(ROOT/'source/healing_fx.webp').convert('RGBA');(ROOT/'fx').mkdir(exist_ok=True)
    charge,charge_info=fx_crop(fx,[170,160,465,445],44)
    small=charge.resize((32,round(charge.height*32/44)),Image.Resampling.NEAREST)
    projectile,projectile_info=fx_crop(fx,[1020,200,1465,445],72)
    charge.save(ROOT/'fx/charge_motif.png');projectile.save(ROOT/'fx/projectile_motif.png')
    layers=[layer_file(ROOT,'gather',small,[223,197]),layer_file(ROOT,'charge',charge,[249,153])]
    for i,x in enumerate([316,346,376,406]):layers.append(layer_file(ROOT,f'heal_{i}',projectile,[x,179]))
    fx_report={'source':'source/healing_fx.webp','selected_cells':['top-left compact charge','top-right healing projectile'],
               'unused_cells_not_counted_as_animation_frames':4,'charge':charge_info,
               'projectile':projectile_info,'motifs':['fx/charge_motif.png','fx/projectile_motif.png'],
               'layers':layers,'order':'behind opaque body',
               'no_new_damage_or_ally_target':True,'event_is_preview_only':True}
    (ROOT/'source/fx_preparation.json').write_text(json.dumps(fx_report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'supports':len(reports),'rigid_ring_heads':len(ring_records),
                      'charge_size':list(charge.size),'projectile_size':list(projectile.size)},ensure_ascii=False))


if __name__=='__main__':main()
