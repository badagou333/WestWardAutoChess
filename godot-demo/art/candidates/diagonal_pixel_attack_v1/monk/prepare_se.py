#!/usr/bin/env python3
"""Apply the imagegen upper-body edit, protecting the original ready lower body.

No limb is translated, rotated or warped. Explicit masks retain ready pixels;
all new attack artwork comes from the saved built-in imagegen edit.
"""
from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'tools'))
from build_attack import build_assets
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
raw=json.loads((ROOT/'source/se_extraction.json').read_text())
assets=build_assets(raw,ROOT/'se')
bodies=[assets['bodies'][i].copy() for i in range(6)]
base=bodies[0]
generated=Image.open(ROOT/'source/se_fixed_legs.webp').convert('RGBA')
edit=generated.resize((448,448),Image.Resampling.NEAREST)
a=np.array(edit);a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[a[:,:,3]==0]=0
edit=Image.fromarray(a)
protect=Image.new('L',(448,448));p=ImageDraw.Draw(protect)
p.polygon([(112,273),(205,273),(205,344),(112,344)],fill=255)
p.polygon([(244,286),(334,286),(334,373),(244,373)],fill=255)
result=Image.composite(base,edit,protect)
# Keep the newly drawn leading hand and staff in front of the protected legs.
foreground=Image.new('L',(448,448));f=ImageDraw.Draw(foreground)
f.polygon([(288,266),(313,264),(325,289),(398,337),(393,365),(309,306),(288,293)],fill=255)
foreground_array=np.array(foreground);foreground_array[a[:,:,3]==0]=0
foreground=Image.fromarray(foreground_array)
result=Image.composite(edit,result,foreground)
bodies[3]=result
sheet=Image.new('RGBA',(448*3,448*2))
for i,body in enumerate(bodies):sheet.paste(body,((i%3)*448,(i//3)*448))
out=ROOT/'source/se_prepared.webp';sheet.save(out,lossless=True,exact=True,method=6)
assert np.array_equal(np.array(sheet),np.array(Image.open(out)))
protect.save(ROOT/'source/se_protected_lower_body.png');foreground.save(ROOT/'source/se_edited_foreground.png')
result.save(ROOT/'source/se_impact_prepared.png')
check=(np.array(protect)>0)&(np.array(foreground)==0)
assert np.array_equal(np.array(result)[check],np.array(base)[check])
spec=dict(raw)
spec['sources']={'prepared':{'file':'../source/se_prepared.webp','sha256':sha(out),'expected_pixel_sha256':hashlib.sha256(sheet.tobytes()).hexdigest(),'scale':1.0}}
spec['bodies']=[]
for i in range(6):
 x=(i%3)*448;y=(i//3)*448
 spec['bodies'].append({'id':str(i),'name':raw['bodies'][i]['name'],'source':'prepared','source_box':[x,y,x+448,y+448],'source_anchor':[x+224,y+344]})
spec['review_annotations']['author_visual_review']='Imagegen upper-body impact edit; original ready trousers/ankles/feet protected by explicit masks. Await seam and full-pose review.'
(ROOT/'se/spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
record={'method':'imagegen upper-body edit with original target lower body protected','tool_source':'se_fixed_legs.webp','source_canvas':list(generated.size),'canvas_registration':'whole output canvas nearest to 448; no silhouette fit','original_extraction':'se_extraction.json','protected_pixels':int(check.sum()),'protected_rgba_exact':True,'no_limb_translation_rotation_or_warp':True,'prepared_sha256':sha(out),'prepared_rgba_sha256':hashlib.sha256(sheet.tobytes()).hexdigest(),'status':'awaiting_visual_review'}
(ROOT/'source/se_preparation.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False))
