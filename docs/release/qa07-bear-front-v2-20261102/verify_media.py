import pathlib,subprocess,re,json,hashlib,wave,collections,sys
from PIL import Image
import numpy as np
r=pathlib.Path('/Users/leqiong/workSpace/tower-defense');b=pathlib.Path('/tmp/qa07-bear-front-v2-20261102');ff='/Users/leqiong/.codex/agent-sprite-forge-venv/lib/python3.12/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
master=r/'godot-demo/art/candidates/bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov';original=r/'godot-demo/art/candidates/bear_lord_video_attack_v1/forehand-7499-short-windup-v2.mp4';cand=r/'godot-demo/art/candidates/bear_lord_front_attack_v2';runtime=r/'bear-forehand-showcase';built=b/'rebuilt'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();checks=[]
def ck(c,label):
 checks.append({'ok':bool(c),'label':label})
 if not c:print('FAIL',label,flush=True)
def decode(path,name):
 p=subprocess.run([ff,'-hide_banner','-i',str(path),'-map','0:v:0','-vf','showinfo','-fps_mode','passthrough','-f','null','-'],capture_output=True,check=True)
 log=p.stderr.decode();(b/(name+'-showinfo.log')).write_text(log)
 return [dict(index=int(a),pts=int(t),duration=int(d),checksum=h) for a,t,d,h in re.findall(r'n:\s*(\d+) pts:\s*(-?\d+) pts_time:[\d.-]+\s+duration:\s*(\d+).*?checksum:([0-9A-F]+)',log)]
m=decode(master,'qa-master');o=decode(original,'qa-original');ck(len(m)==84 and len(o)==96,'decoded 84 master and 96 original timestamps')
ck(sha(master)=='d37dffe785d83306c0f41f54b12348d0043f189bcf91251659816e291be548c0','approved master SHA')
for i,x in enumerate(m):
 z=o[i+9];ck(x['pts']==z['pts']-5888 and x['checksum']==z['checksum'],'original frame %d -> new %d unchanged decoded YUV and shifted PTS'%(i+10,i+1))
 ck(x['pts']+(x['duration'])==(m[i+1]['pts'] if i<83 else 46080),'continuous real duration '+str(i+1))
ck(collections.Counter(x['duration'] for x in m).keys()=={128,192,512,768},'four actual VFR durations')
manifest=json.loads((runtime/'art/attack/manifest.json').read_text());boundaries=[]
for i,(x,f) in enumerate(zip(m,manifest['frames'])):
 ck((f['source_frame'],f['original_source_frame'],f['source_pts'],f['duration_ticks'])==(i+1,i+10,x['pts'],x['duration']),'manifest exact source timing '+str(i+1))
 p=cand/'frames'/f['file'];q=built/'frames'/f['file'];s=runtime/'art/attack'/f['file'];ck(q.is_file() and sha(p)==sha(q)==sha(s)==f['sha256'],'cold rebuilt PNG bytes '+str(i+1))
 a=np.array(Image.open(q));ck(a.shape==(320,400,4) and not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3]),'400x320 intact transparent outer border '+str(i+1))
 boundaries.append(dict(frame=i+1,original=i+10,pts=x['pts'],duration=x['duration'],rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest()))
for rel in ['manifest.json','audio/source-track.wav']:ck(sha(built/rel)==sha(cand/rel),'cold rebuild byte-equal '+rel)
raw=subprocess.run([ff,'-v','error','-i',str(master),'-map','0:a:0','-f','s16le','-'],capture_output=True,check=True).stdout
with wave.open(str(runtime/'audio/source-track.wav')) as w:params=[w.getframerate(),w.getnchannels(),w.getsampwidth(),w.getnframes()];pcm=w.readframes(w.getnframes())
ck(params==[44100,2,2,132280] and raw==pcm,'fresh master raw PCM equals actual runtime exact 132280 samples')
ck(sha(runtime/'audio/source-track.wav')=='aaaf61ca9f75ebb4f8c9657108ac0a47245f0ef00efa38bd6a95066803b9caf9','approved runtime WAV SHA')
# Exact runtime parent comparison includes full back/art/audio/player/controls.
changed=subprocess.check_output(['git','diff-tree','--no-commit-id','--name-only','-r','4421292'],cwd=r,text=True).splitlines()
protected=['bear-forehand-showcase/showcase.gd','bear-forehand-showcase/showcase.tscn','bear-forehand-showcase/project.godot','bear-forehand-showcase/launch.command','bear-forehand-showcase/art/forest-board.png','bear-forehand-showcase/audio/back-source-track.wav']
ck(not any(x.startswith(('godot-demo/','bear-forehand-showcase/art/back/')) or x in protected for x in changed),'production commit leaves player/back/board/main game unchanged')
# Verify all archived actual captures and exact same-image crops; no recoloring or offline compositing.
capdir=runtime/'validation/20261102-front-v2/render';cap=json.loads((capdir/'capture.json').read_text());fronts=collections.defaultdict(list)
ck(cap['success'] and len(cap['samples'])==30 and cap['saved_png_count']==60,'author capture completed 30 actual viewport + crop pairs')
for s in cap['samples']:
 full=capdir/s['file'];crop=capdir/s['character_file'];ck(sha(full)==s['sha256'] and sha(crop)==s['character_sha256'],'capture hashes '+s['file'])
 x,y,w,h=s['character_viewport_rect'];a=Image.open(full).convert('RGBA');c=Image.open(crop).convert('RGBA');ck(a.size==(1440,810) and np.array_equal(np.array(a.crop((x,y,x+w,y+h))),np.array(c)),'exact source viewport crop '+s['file'])
 if s['clip']=='front':
  f=manifest['frames'][s['frame']];fronts[s['direction']].append(s['source_frame'])
  ck(s['source_frame']==f['source_frame'] and s['original_source_frame']==f['original_source_frame'] and s['source_pts']==f['source_pts'] and s['runtime_source_sha256']==f['sha256'] and abs(s['render_time_seconds']-f['source_time_seconds']-1e-6)<1e-12,'front source-to-runtime numbered mapping '+s['file'])
for direction,frames in fronts.items():ck(frames==[1,7,41,42,43,44,45,46,48,83,84],'required numbered capture coverage '+direction)
result={'checks':len(checks),'failures':[c['label'] for c in checks if not c['ok']],'master_sha256':sha(master),'original_sha256':sha(original),'source_frame_count':len(m),'duration_ticks_histogram':dict(collections.Counter(x['duration'] for x in m)),'time_base':[1,15360],'total_ticks':46080,'boundaries':boundaries,'cold_byte_equal_files':86,'audio_params':params,'WAV_SHA':sha(runtime/'audio/source-track.wav'),'PCM_SHA':hashlib.sha256(pcm).hexdigest(),'audio_tail_gap_seconds':3-params[3]/params[0],'capture_pairs_verified':len(cap['samples']),'front_capture_number_coverage':fronts,'checks_detail':checks}
(b/'media-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');(b/'oracle.json').write_text(json.dumps({'frames':m,'period_ticks':46080,'ticks_per_second':15360}))
print('MEDIA_CHECK',len(checks),'checks',len(result['failures']),'failures',flush=True)
sys.exit(bool(result['failures']))
