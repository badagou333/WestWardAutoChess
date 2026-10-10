"""First short call candidate from selected wolf sound; CC BY 3.0."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
P=Path(__file__).resolve().parents[1]
source=P.parent/'selected-20261009/wav/wolf_attack_full.wav'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with wave.open(str(source)) as w:
 sr=w.getframerate();ch=w.getnchannels();assert (sr,ch,w.getsampwidth())==(44100,2,2)
 x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,ch).astype(float)
start,end=.600,.890;y=x[round(start*sr):round(end*sr)].copy()
n=round(.002*sr);y[:n]*=np.sin(np.linspace(0,np.pi/2,n))[:,None]**2
n=round(.030*sr);y[-n:]*=np.cos(np.linspace(0,np.pi/2,n))[:,None]**2
pcm=np.round(y).astype('<i2');out=P/'wolf_first_call.wav'
with wave.open(str(out),'wb') as w:w.setnchannels(ch);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
m={'status':'第一声短版候选，待负责人试听；未替换运行完整声','source_page':'https://freesound.org/people/deleted_user_3424813/sounds/260776/','source_title':'ANGRY DOG BARK SNARL Flat.wav','author':'deleted_user_3424813','license':'CC BY 3.0','license_url':'https://creativecommons.org/licenses/by/3.0/','input':'../selected-20261009/wav/wolf_attack_full.wav','input_sha256':sha(source),'source_kind':'Previously delivered WAV derived from public HQ MP3 preview, not original WAV download','source_start':start,'source_end':end,'duration':len(pcm)/sr,'frames':len(pcm),'file':out.name,'sha256':sha(out),'peak_dbfs':float(20*np.log10(abs(pcm.astype(float)).max()/32768)),'changes':'Extract 0.600–0.890s first strong call; remove leading quiet preparation and second call; 2ms fade-in/30ms fade-out. No gain normalization, pitch/time changes, EQ or added layers.','cut_evidence':'Two strong amplitude groups near 0.65–0.85s and 0.92–1.10s; cut in intervening valley. Auditory identity and cut quality await user listening.'}
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
assert len(pcm)==12789 and not pcm[0].any() and not pcm[-1].any() and abs(pcm.astype(int)).max()<32767
print('First call candidate:',m['duration'],'seconds; peak',m['peak_dbfs'])
