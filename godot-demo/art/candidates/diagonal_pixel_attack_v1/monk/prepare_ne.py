#!/usr/bin/env python3
"""Compose imagegen's isolated rigid staff behind locally repaired back-view art.

The tool removes the wrong rear exposure; its local pixels are adopted through
explicit masks. A separately generated horizontal staff is rigidly transformed
onto the visible front shaft's axis. Body/feet/hands are never warped.
"""
from pathlib import Path
import sys,json,hashlib,math
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent.parent/'pixel_attack_series_v1/tools'))
from build_attack import build_assets,extract
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
raw=json.loads((ROOT/'source/ne_extraction.json').read_text())
assets=build_assets(raw,ROOT/'ne');bodies=[x.copy() for x in assets['bodies']]
removal=Image.open(ROOT/'source/ne_no_rear.webp').convert('RGBA')
staff=Image.open(ROOT/'source/staff_component.webp').convert('RGBA');a=np.array(staff)
a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[:,1000:,3]=0;a[a[:,:,3]==0]=0;staff=Image.fromarray(a)
settings={
0:{'mask':[85,220,185,294],'front_axis':[[340,184.5],[355,177.5]],'rear_tip_x':100},
3:{'mask':[82,206,195,275],'front_axis':[[360,185],[390,174]],'rear_tip_x':100},
4:{'mask':[77,201,195,277],'front_axis':[[340,175.5],[360,167.5]],'rear_tip_x':95},
5:{'mask':[82,220,197,313],'front_axis':[[325,188],[350,176]],'rear_tip_x':103}}
report=[]
for index,setting in settings.items():
 edited,_=extract(removal,raw['bodies'][index],.6,(448,448),(224,344))
 mask=Image.new('L',(448,448));ImageDraw.Draw(mask).rectangle(setting['mask'],fill=255)
 repaired=Image.composite(edited,bodies[index],mask)
 (x1,y1),(x2,y2)=setting['front_axis'];slope=(y2-y1)/(x2-x1);intercept=y1-slope*x1
 px=setting['rear_tip_x'];py=slope*px+intercept
 theta=math.atan(slope);c=math.cos(theta);sn=math.sin(theta);scale=.165
 transform=(c/scale,sn/scale,74-(c*px+sn*py)/scale,-sn/scale,c/scale,359.5-(-sn*px+c*py)/scale)
 rear=staff.transform((448,448),Image.Transform.AFFINE,transform,resample=Image.Resampling.NEAREST)
 bodies[index]=Image.alpha_composite(rear,repaired)
 mask.save(ROOT/'source'/f'ne_rear_removal_mask_{index}.png')
 rear.save(ROOT/'source'/f'ne_rear_layer_{index}.png')
 report.append({'body':index,'visible_front_axis':setting['front_axis'],'slope':slope,'intercept':intercept,'rear_tip':[px,py],'shaft_uniform_scale':scale,'inverse_affine':list(transform),'removal_mask':setting['mask'],'body_geometry_warped':False})
sheet=Image.new('RGBA',(1344,896))
for i,im in enumerate(bodies):sheet.paste(im,((i%3)*448,(i//3)*448))
out=ROOT/'source/ne_prepared.webp';sheet.save(out,lossless=True,exact=True,method=6)
assert np.array_equal(np.array(sheet),np.array(Image.open(out)))
spec=dict(raw);spec['sources']={'prepared':{'file':'../source/ne_prepared.webp','sha256':sha(out),'expected_pixel_sha256':hashlib.sha256(sheet.tobytes()).hexdigest(),'scale':1.0}}
spec['bodies']=[]
for i in range(6):
 x=(i%3)*448;y=(i//3)*448
 spec['bodies'].append({'id':str(i),'name':raw['bodies'][i]['name'],'source':'prepared','source_box':[x,y,x+448,y+448],'source_anchor':[x+224,y+344]})
spec['review_annotations']['author_visual_review']='Local imagegen rear-removal repair and rigid imagegen staff layer aligned to the visible forward axis. Await final visual review.'
(ROOT/'ne/spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
(ROOT/'source/ne_preparation.json').write_text(json.dumps({'method':'imagegen local removal and generated equipment compositing','original_extraction':'ne_extraction.json','no_body_geometry_change':True,'repairs':report,'prepared_sha256':sha(out),'status':'awaiting_visual_review'},ensure_ascii=False,indent=2)+'\n')
print('NE four rear segments rebuilt on their front axes; visual review pending.')
