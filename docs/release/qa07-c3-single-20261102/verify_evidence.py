from pathlib import Path
import json,hashlib,subprocess
import numpy as np
from PIL import Image
R=Path('/Users/leqiong/workSpace/tower-defense');T=Path('/tmp/qa07-c3-single-20261102');P=R/'c03-attack-showcase';A=P/'validation/20261102-single/render'
d=json.loads((T/'render/results.json').read_text());m=json.loads((P/'art/c03/manifest.json').read_text());f=json.loads((R/'godot-demo/art/candidates/c03_kingfisher_attack_v1/evidence/frozen-manifest.json').read_text());author=json.loads((A/'capture.json').read_text());checks=[];matches=[]
def ck(ok,label):checks.append({'pass':bool(ok),'check':label})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
ck(len(f['frames'])==98,'original frozen record count')
for x,y in zip(m['frames'],f['frames']):ck(all(x[k]==y[k] for k in ['index','sha256','pts_ticks','source_duration_ticks']) and x['source_frozen_file']==y['file'],'original frozen map '+str(x['index']))
for s in d['captures']:
 path=T/'render'/s['file'];ck(sha(path)==s['sha256'],'capture hash '+s['file'])
 if 'rect' not in s:continue
 x=m['frames'][s['index']];ck(s['source_sha256']==x['sha256'],'capture mapped asset '+s['file'])
 if s['state']=='playing':ck(x['pts_ticks']/90000<=s['elapsed']<(x['pts_ticks']+x['source_duration_ticks'])/90000,'normal PTS '+s['file'])
 target=next(a for a in author['samples'] if a['frame_index']==s['index'])
 eq=np.array_equal(np.array(Image.open(path)),np.array(Image.open(A/target['character_file'])));ck(eq,'normal vs author same index '+s['file']);matches.append({'qa':s['file'],'author':target['character_file'],'pixel_equal':eq})
full=Image.open(T/'render/viewport-normal-32.png');ck(np.array_equal(np.array(full.crop((608,269,834,495))),np.array(Image.open(T/'render/normal-32.png'))),'viewport crop pixel exact')
frozen=json.loads((T/'frozen.json').read_text());changed=[n for n,h in frozen.items() if sha(R/n)!=h];ck(not changed,'all 161 project files including first failures unchanged')
other=subprocess.check_output(['git','diff','--name-only','14c1bd6','--','godot-demo','bear-forehand-showcase'],cwd=R,text=True);ck(not other,'protected game candidates bear unchanged')
caches=[str(p.relative_to(T/'cold')) for p in (T/'cold').rglob('*') if p.name=='.godot' or p.suffix in ['.import','.uid']];ck(not caches,'no generated cache/import/uid after probes')
result={'checks':len(checks),'failures':[x for x in checks if not x['pass']],'author_pixel_matches':matches,'frozen_changed':changed,'protected_diff':other,'cache_paths':caches,'details':checks}
(T/'evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print({k:v for k,v in result.items() if k not in ['details','author_pixel_matches']});print('pixel matches',len(matches))
