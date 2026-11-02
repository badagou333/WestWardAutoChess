import json,subprocess,hashlib,shutil,wave
from pathlib import Path
R=Path('/Users/leqiong/workSpace/tower-defense');P=R/'c03-attack-showcase';T=Path('/tmp/qa07-c3-single-20261102')
def git(*a):return subprocess.check_output(['git',*a],cwd=R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def ck(ok,label):checks.append({'pass':bool(ok),'check':label})
listing=json.loads((P/'provenance/resource-list.json').read_text());m=json.loads((P/'art/c03/manifest.json').read_text());f=json.loads((R/'godot-demo/art/candidates/c03_kingfisher_attack_v1/evidence/frozen-manifest.json').read_text())
ck(sha(P/'art/c03/manifest.json')=='fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98','manifest pin')
for x in listing['files']:
 ck(sha(P/x['runtime_path'])==x['copied_sha256']==sha(R/x['source_repository_path']),'resource '+x['runtime_path'])
ck(len(m['frames'])==98,'98 records');ck(m['substituted_indices']==[30,31,32],'only frozen repaired indices')
nexttick=0
for i,x in enumerate(m['frames']):
 ck(x['index']==i and x['pts_ticks']==nexttick,'PTS continuous '+str(i));nexttick+=x['source_duration_ticks']
 ck(x['sha256']==sha(P/'art/c03'/x['file']),'mapped png '+str(i))
 ck(x['source_duration_ticks']>0 if i<97 else x['source_duration_ticks']==0,'duration '+str(i))
ck(nexttick==260250 and m['frames'][-1]['pts_ticks']==260250,'exact media end');ck(m['canvas']==[960,960] and m['foot_reference']==[475,760],'canvas reference')
with wave.open(str(P/'art/c03'/m['audio']['file'])) as w:ck((w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes())==(2,2,44100,44100),'original one second PCM')
paths=git('ls-files','c03-attack-showcase').decode().splitlines();frozen={n:sha(R/n) for n in paths};(T/'frozen.json').write_text(json.dumps(frozen,indent=2));(T/'initial-status.txt').write_bytes(git('status','--porcelain=v1','-uall'))
copied=[]
for n in paths:
 rel=Path(n).relative_to('c03-attack-showcase')
 if rel.parts[0] in ['validation','provenance'] or rel.suffix in ['.uid','.import']:continue
 target=T/'cold'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,target);copied.append(str(rel))
ck(not (T/'cold/.godot').exists(),'no cache before launch');ck(not (T/'cold/art/c03/source').exists(),'no source video needed')
result={'base':git('rev-parse','HEAD').decode().strip(),'checks':len(checks),'failures':[x for x in checks if not x['pass']],'copied_files':copied,'frozen_files':len(frozen),'details':checks,'protected_git_trees':{n:git('rev-parse','HEAD:'+n).decode().strip() for n in ['godot-demo','bear-forehand-showcase']}}
(T/'assets.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print({k:v for k,v in result.items() if k not in ['details','copied_files']})
