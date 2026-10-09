"""Offline D006 delivery rebuild: existing versions copied exactly, three full sources processed.
Python3 + numpy; decoded source files retained to avoid platform decoder differences.
"""
from pathlib import Path
import hashlib,json,wave,shutil
import numpy as np
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):
    with wave.open(str(p)) as w:
        assert w.getframerate()==44100 and w.getsampwidth()==2
        return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels())
def stats(p):
    a=read(p);f=a.astype(float)/32768
    return dict(sha256=sha(p),frames=len(a),duration_seconds=len(a)/44100,sample_rate=44100,bits=16,channels=a.shape[1],peak_dbfs=float(20*np.log10(np.abs(f).max())),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(f*f)))),first_frame=a[0].tolist(),last_frame=a[-1].tolist(),clipped_samples=int(np.count_nonzero((a==-32768)|(a==32767))))
r=json.loads((P/'recipe.json').read_text());assets=[]
for e in r['entries']:
    src=P/e['input'];out=P/e['file'];assert sha(src)==e['input_sha256'],src
    if 'raw_source' in e:assert sha(P/e['raw_source'])==e['source_sha256']
    if e['mode']=='copy_exact':shutil.copyfile(src,out);gain=None
    else:
        x=read(src).astype(float)/32768
        for side,ms in [('in',2),('out',8)]:
            n=round(44100*ms/1000)
            if side=='in':x[:n]*=np.sin(np.linspace(0,np.pi/2,n))[:,None]**2
            else:x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))[:,None]**2
        gain=10**(-11/20)/np.abs(x).max();x*=gain
        with wave.open(str(out),'wb') as w:
            w.setnchannels(x.shape[1]);w.setsampwidth(2);w.setframerate(44100)
            w.writeframes(np.round(x*32768).astype('<i2').tobytes())
        assert len(read(out))==len(read(src))
    item={**e,**stats(out)}
    if gain is not None:item['gain_db']=float(20*np.log10(gain))
    assert item['clipped_samples']==0
    assets.append(item)
for b in r['backups']:assert sha(P/b['path'])==b['sha256']
m={k:v for k,v in r.items() if k!='entries'};m['assets']=assets
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
for a in assets:print(a['id'],a['duration_seconds'],a['peak_dbfs'],a['first_frame'],a['last_frame'])
