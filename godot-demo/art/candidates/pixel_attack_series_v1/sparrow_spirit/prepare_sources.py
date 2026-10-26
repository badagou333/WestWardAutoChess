#!/usr/bin/env python3
"""Prepare source-pixel foot registration and one separately painted wind blade."""
from collections import deque
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
FOOT_ROIS = [
    [[160,460,256,533],[283,460,384,533]],
    [[647,460,745,533],[799,460,902,533]],
    [[1150,460,1250,533],[1250,460,1350,533]],
    [[157,913,255,990],[278,913,380,990]],
    [[686,913,785,990],[800,913,899,990]],
    [[1210,913,1308,990],[1323,913,1424,990]],
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def toe_point(image, box):
    left,top,right,bottom = box
    a=np.asarray(image)[top:bottom,left:right,3]
    ys,xs=np.nonzero(a>=128)
    low=int(ys.max())
    return [int(np.median(xs[ys==low])+left),low+top]


def main_component(alpha, seed):
    mask=alpha>=8
    x,y=seed
    assert mask[y,x]
    chosen=np.zeros(mask.shape,dtype=bool);chosen[y,x]=True
    queue=deque([(x,y)])
    h,w=mask.shape
    while queue:
        x,y=queue.popleft()
        for ny in range(max(0,y-1),min(h,y+2)):
            for nx in range(max(0,x-1),min(w,x+2)):
                if mask[ny,nx] and not chosen[ny,nx]:
                    chosen[ny,nx]=True;queue.append((nx,ny))
    return chosen


def main():
    source=Image.open(ROOT/'source/body_sheet.webp').convert('RGBA')
    image=source.copy()
    original=np.asarray(source)
    changed_mask=np.zeros(original.shape[:2],dtype=bool)
    reference=[toe_point(source,box) for box in FOOT_ROIS[0]]
    span=reference[1][0]-reference[0][0]
    reports=[]
    for index,pair in enumerate(FOOT_ROIS):
        rear,front=[toe_point(source,box) for box in pair]
        dx=rear[0]+span-front[0]
        left,top,right,bottom=pair[1]
        if dx:
            crop=source.crop((left,top,right,bottom))
            image.paste((0,0,0,0),(left,top,right,bottom))
            image.paste(crop,(left+dx,top))
            changed_mask[top:bottom,min(left,left+dx):max(right,right+dx)]=True
        reports.append({'pose':index,'rear_toe':rear,'original_front_toe':front,
                        'foot_roi':pair[1],'front_foot_registration':[dx,0],
                        'registered_front_toe':[front[0]+dx,front[1]],
                        'source_ground_gap_y':front[1]-rear[1],
                        'same_horizontal_toe_span':span,
                        'scope':'Original painted ankle/claw pixels registered for planted contact; upper body and wings untouched.'})
    actual=np.asarray(image)
    assert np.array_equal(actual[~changed_mask],original[~changed_mask])
    image.save(ROOT/'source/body_registered.webp',lossless=True,exact=True)
    restored=Image.open(ROOT/'source/body_registered.webp').convert('RGBA')
    assert restored.tobytes()==image.tobytes()
    foot_report={'reference_pose':0,'horizontal_source_span':span,
                 'poses':reports,'outside_union_of_foot_rois_rgba_exact':True,
                 'body_source_scale_after_registration':.65,
                 'whole_character_rescale_or_transform':False,
                 'registered_source_rgba_sha256':sha(restored.tobytes()),
                 'registered_source_file_sha256':sha((ROOT/'source/body_registered.webp').read_bytes())}
    (ROOT/'source/foot_registration.json').write_text(json.dumps(foot_report,ensure_ascii=False,indent=2)+'\n')
    fx=Image.open(ROOT/'source/wind_blade.webp').convert('RGBA')
    a=np.asarray(fx).copy();selected=main_component(a[:,:,3],(900,610))
    a[~selected]=0
    clean=Image.fromarray(a)
    box=clean.getbbox();tight=clean.crop(box)
    height=70;width=round(tight.width*height/tight.height)
    blade=tight.resize((width,height),Image.Resampling.NEAREST)
    out=ROOT/'fx';out.mkdir(exist_ok=True)
    blade.save(out/'blade.png')
    records=[]
    for index,x in enumerate([347,373,399,425]):
        panel=Image.new('RGBA',(448,448))
        panel.alpha_composite(blade,(x,194))
        name=f'wind_{index}.png';panel.save(out/name)
        records.append({'file':f'fx/{name}','position':[x,194],
                        'visible_bbox':list(panel.getbbox()) if panel.getbbox() else None,
                        'view_edge_clipping':x+width>448})
    fx_report={'source':'source/wind_blade.webp','source_component_seed':[900,610],
               'selection':'one connected crescent at alpha>=8; no secondary particle sprites',
               'source_box':list(box),'target_size':[width,height],
               'body_scale_not_changed':True,'resampling':'nearest',
               'layers':records,'layer_order':'behind opaque body',
               'edge_clipping_is_projectile_exit_not_body_crop':True}
    (ROOT/'source/wind_preparation.json').write_text(json.dumps(fx_report,indent=2)+'\n')
    print(json.dumps({'foot_span_source_px':span,'poses':len(reports),'blade_size':[width,height]},ensure_ascii=False))


if __name__=='__main__':
    main()
