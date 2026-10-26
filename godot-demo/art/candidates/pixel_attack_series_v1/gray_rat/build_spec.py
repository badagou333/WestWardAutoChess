#!/usr/bin/env python3
"""Package the prepared eight bodies through the shared attack exporter."""
from pathlib import Path
from PIL import Image
import hashlib,json,numpy as np

ROOT=Path(__file__).resolve().parent
IDS=['00_ready','01_load_stone','02_wind_back','03_overhead','04_release','05_catch_end','06_take_stone','07_lift_stone']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=ROOT/'source/registered_poses.webp'
im=Image.open(source).convert('RGBA')
spec={'character':'gray_rat','display_name':'灰鼠 / single-stone sling attack','canvas':[448,448],'anchor':[130,400],'palette_colors':96,
      'sources':{'registered':{'file':'source/registered_poses.webp','sha256':sha(source),'expected_pixel_sha256':hashlib.sha256(im.tobytes()).hexdigest(),'scale':1.0}},
      'bodies':[],'layers':{},'track':[],'duration_ms':1500,'idle_ms':350,
      'events':[{'name':'sling_stone_release','at_ms':580}],
      'review_profile':['real sling, two cords, one retained finger loop, release only one end','single loaded/projectile stone, separate from belt reserve stones','same screen-right bare tail root','both planted foot soles registered'],
      'review_annotations':{'actual_pose_count':8,'preparation_report':'source/preparation_report.json','common_upstream_body_scale':.84,'normalized_packaging_scale':1.0,'body_height_fitting':False,'catch_body':'clean original ready torso plus generated empty catching paw; no copied extra waist rope','weapon_parts':'only generated existing cord/cradle/stone pixels; mask and local registration recorded','runtime_integrated':False,'author_visual_gate':'author_pass_pending_independent'}}
for i,name in enumerate(IDS):
 x=(i%4)*448;y=(i//4)*448
 spec['bodies'].append({'id':name,'name':name,'source':'registered','source_box':[x,y,x+448,y+448],'source_anchor':[x+130,y+400]})
sheet=Image.open(ROOT/'source/mechanics_sheet.webp').convert('RGBA')
stone=sheet.crop((1259,822,1337,888)).resize((18,16),Image.Resampling.NEAREST)
a=np.asarray(stone).copy();a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[a[:,:,3]==0]=0;stone=Image.fromarray(a)
folder=ROOT/'source/stone_layers';folder.mkdir(exist_ok=True)
for i,(x,y) in enumerate([(279,114),(337,106),(396,100),(448,94)]):
 c=Image.new('RGBA',(448,448));c.alpha_composite(stone,(x-9,y-8));p=folder/f'flight_{i}.png';c.save(p)
 spec['layers'][f'flight_{i}']={'file':'source/stone_layers/'+p.name,'sha256':sha(p),'expected_pixel_sha256':hashlib.sha256(c.tobytes()).hexdigest(),'order':'behind'}
for at,body,layer in [(0,0,None),(120,1,None),(340,2,None),(490,3,None),(580,4,0),(620,4,1),(660,4,2),(700,4,3),(740,4,None),(820,5,None),(1040,6,None),(1220,7,None),(1380,0,None)]:
 stage={'at_ms':at,'body':IDS[body]}
 if layer is not None:stage['layers']=[{'id':f'flight_{layer}','opacity':1}]
 spec['track'].append(stage)
(ROOT/'spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'bodies':len(spec['bodies']),'stages':len(spec['track']),'normal_ms':1850,'slow_ms':3350}))
