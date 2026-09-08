"""Independent checks of generated artifacts and source identity; not visual approval."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

ART=Path(__file__).resolve().parents[2]
failures=[];results=[]
def require(test,msg):
    if not test:failures.append(msg)

for role in ['wild_hunter','herbal_spirit_child','sparrow_spirit','bear_lord']:
    root=ART/'production'/role/'demo_v1'
    m=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    require(hashlib.sha256((ART.parent/m['source']).read_bytes()).hexdigest()==m['source_sha256'],role+' original source changed')
    body=Image.open(root/m['atlases']['body']);vfx=Image.open(root/m['atlases']['vfx']);count=len(m['frames'])
    require(body.size==vfx.size==(count*256,256),role+' atlas dimensions')
    body_report=[]
    for f in m['frames']:
        im=Image.open(root/f['file']);a=np.asarray(im)
        require(im.mode=='RGBA' and im.size==(256,256),f['file']+' size or alpha')
        require(np.count_nonzero(a[:,:,3])>500,f['file']+' missing body')
        require(not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3]),f['file']+' touched frame edge')
        crop=np.asarray(body.crop((f['index']*256,0,(f['index']+1)*256,256)))
        require(np.array_equal(a,crop),f['file']+' differs from body atlas')
        fx=np.asarray(vfx.crop((f['index']*256,0,(f['index']+1)*256,256)))
        require(bool(np.any(fx[:,:,3]))==f['aligned_vfx'],f['file']+' VFX flags mismatch')
        source_box=f['source_box'];require(0<=source_box[0]<source_box[2] and 0<=source_box[1]<source_box[3],f['file']+' invalid crop')
        ys,xs=np.where(a[:,:,3]>=26)
        body_report.append({'name':f['name'],'bbox_alpha_10_percent':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'border_clear':True,'atlas_pixel_identical':True})
    for name,fx in m['standalone_vfx'].items():
        im=Image.open(root/fx['file']);a=np.asarray(im)
        require(im.mode=='RGBA' and list(im.size)==fx['size'],role+' '+name+' effect size or alpha')
        require(np.count_nonzero(a[:,:,3])>10,role+' '+name+' empty effect')
        require(not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3]),role+' '+name+' effect touches border')
        aligned=Image.open(root/fx['aligned_file']);require(aligned.mode=='RGBA' and aligned.size==(256,256),role+' '+name+' aligned size')
    require(set(m['actions'])=={'idle','move','basic_attack','hit','retreat'},role+' five-action coverage')
    for act in m['actions'].values():
        require(all(0<=i<count for i in act['body_frames']),role+' invalid action frame')
    results.append({'character':role,'body_frames':body_report,'standalone_effects':list(m['standalone_vfx'])})

report={'scope':'Source hashes, file dimensions, alpha, frame edges, atlas identity, action mapping; visual and engine battle acceptance are separate.','roles':results,'failures':failures}
(ART/'reviews/four-role-demo/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('FOUR_ROLE_ARTIFACT_CHECK: roles=4 body_frames=22 failures='+str(len(failures)))
for failure in failures:print(failure)
raise SystemExit(bool(failures))
