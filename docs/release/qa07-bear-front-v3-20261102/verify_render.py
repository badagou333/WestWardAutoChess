import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
R=Path('/Users/leqiong/workSpace/tower-defense');T=Path('/tmp/qa07-bear-front-v3-20261102'); A=R/'bear-forehand-showcase/validation/20261102-front-v3/render';D=json.loads((T/'render/results.json').read_text());M=json.loads((R/'bear-forehand-showcase/art/attack/manifest.json').read_text())
checks=[]
def check(ok,s):checks.append({'check':s,'pass':bool(ok)})
comparisons=[]
for row in D['captures']:
 p=T/'render'/row['file'];check(hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],'capture hash '+p.name)
 if 'source_sha256' not in row:continue
 f=M['frames'][row['frame']-1];check(f['sha256']==row['source_sha256'],'captured asset '+p.name)
 phase=row['elapsed']%3;check(f['source_time_seconds']<=phase+1e-8<f['source_time_seconds']+f['duration_seconds']+1e-8,'actual normal PTS '+p.name)
 side='right' if row['direction']==0 else 'left'
 matches=list(A.glob(f'front_{side}-*-frame-{row["frame"]:04d}-character.png'))
 if matches:
  equal=np.array_equal(np.array(Image.open(p)),np.array(Image.open(matches[0])));check(equal,'independent normal matches author paused '+p.name);comparisons.append({'file':p.name,'author':str(matches[0].relative_to(R)),'pixel_equal':equal})
 if row['direction']==0 and row['frame']==44:
  whole=Image.open(T/'render/viewport-front-right-44.png');x,y,w,h=row['crop_rect'];check(np.array_equal(np.array(whole.crop((x,y,x+w,y+h))),np.array(Image.open(p))),'actual viewport/crop identical')
frozen=json.loads((T/'frozen.json').read_text());changed=[n for n,h in frozen.items() if hashlib.sha256((R/n).read_bytes()).hexdigest()!=h];check(not changed,'production frozen after QA')
results={'checks':len(checks),'failures':[x for x in checks if not x['pass']],'author_comparisons':comparisons,'frozen_runtime_files':len(frozen),'changed_runtime_files':changed,'normal_trace_summary':[{'direction':t['direction'],'elapsed':t['elapsed'],'observed_unique_frames':len(set(x['frame'] for x in t['frame_changes'])),'max_render_delta':t['max_render_delta'],'frame_changes':len(t['frame_changes'])} for t in D['traces']],'details':checks}
(T/'render-check.json').write_text(json.dumps(results,indent=2));print({k:v for k,v in results.items() if k not in ['details','author_comparisons']});print('author comparisons',len(comparisons))
