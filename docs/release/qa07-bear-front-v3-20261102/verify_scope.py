import json,hashlib,subprocess,shutil
from pathlib import Path
import numpy as np
from PIL import Image
R=Path('/Users/leqiong/workSpace/tower-defense'); T=Path('/tmp/qa07-bear-front-v3-20261102'); S=R/'bear-forehand-showcase'; C=R/'godot-demo/art/candidates/bear_lord_front_attack_v3'; V=R/'godot-demo/art/candidates/bear_lord_front_attack_v2'
def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(ok,label):checks.append({'check':label,'pass':bool(ok)})
m=json.loads((C/'manifest.json').read_text()); old=json.loads((V/'manifest.json').read_text())
check(sha(C/'manifest.json')=='53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237','frozen manifest')
check((S/'art/attack/manifest.json').read_bytes()==(C/'manifest.json').read_bytes(),'actual runtime manifest')
check(len(m['frames'])==84 and m['canvas']==[400,320] and m['foot']==[177,213],'geometry and count')
changed=[]; opaque=[]
for i,(f,o) in enumerate(zip(m['frames'],old['frames']),1):
 p=C/'frames'/f['file']; q=V/'frames'/f['file']; a=np.array(Image.open(p).convert('RGBA')); b=np.array(Image.open(q).convert('RGBA'))
 check(sha(p)==f['sha256']==sha(S/'art/attack'/f['file']),f'candidate/runtime/hash {i}')
 check(all(f[k]==o[k] for k in ['source_pts','original_source_pts','duration_ticks','source_time_seconds','decoded_source_sha256']),f'unchanged source time {i}')
 check(f['original_source_frame']==i+9 and f['original_source_pts']-f['source_pts']==5888,f'source mapping {i}')
 check(a.shape==(320,400,4),f'canvas {i}')
 n=int(np.count_nonzero(np.any(a[b[:,:,3]==255]!=b[b[:,:,3]==255],axis=1))); opaque.append(n);check(n==0,f'opaque subject unchanged {i}')
 if sha(p)!=sha(q):changed.append(i)
check(changed==list(range(38,52)),'exact 14 changed frames')
check(sum(f['duration_ticks'] for f in m['frames'])==46080 and m['frames'][-1]['source_time_seconds']==2.95,'3sec / final50ms')
check(sha(S/'audio/source-track.wav')==sha(C/'audio/source-track.wav')==sha(V/'audio/source-track.wav')=='aaaf61ca9f75ebb4f8c9657108ac0a47245f0ef00efa38bd6a95066803b9caf9','unchanged WAV')
protected=[]
for n in git('ls-files','bear-forehand-showcase').decode().splitlines():
 rel=Path(n).relative_to('bear-forehand-showcase')
 if rel.parts[0]=='validation':continue
 if str(rel) in ['showcase.gd','showcase.tscn','project.godot','clips.json'] or str(rel).startswith(('art/back/','audio/')) or str(rel)=='art/forest-board.png':
  protected.append(n);check(git('show','4421292:'+n)==(R/n).read_bytes(),'protected '+str(rel))
files=[n for n in git('ls-files','bear-forehand-showcase').decode().splitlines() if '/validation/' not in n and not n.endswith(('.import','.uid'))]
frozen={n:sha(R/n) for n in files};(T/'frozen.json').write_text(json.dumps(frozen,indent=2));(T/'initial-status.txt').write_bytes(git('status','--porcelain=v1','-uall'))
for n in files:
 target=T/'cold'/Path(n).relative_to('bear-forehand-showcase');target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,target)
check(not (T/'cold/.godot').exists(),'no cache before launch')
result={'base':git('rev-parse','HEAD').decode().strip(),'checks':len(checks),'failures':[x for x in checks if not x['pass']],'changed_frames':changed,'unchanged_frames':84-len(changed),'protected_files':len(protected),'cold_files':len(files),'opaque_changed_pixels':sum(opaque),'cold_copy_contains_candidates':False,'details':checks}
(T/'scope.json').write_text(json.dumps(result,indent=2));print({k:v for k,v in result.items() if k!='details'})
