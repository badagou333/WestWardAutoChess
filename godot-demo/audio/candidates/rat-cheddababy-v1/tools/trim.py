"""Second impact from Cheddababy Rockburst5, CC BY 3.0; see ATTRIBUTION.md.
Python 3 + numpy. Public HQ MP3 preview decoded to WAV, not original download.
"""
from pathlib import Path
import json,hashlib,wave
import numpy as np
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with wave.open(str(P/'source/preview-decoded.wav')) as w:
 sr=w.getframerate();ch=w.getnchannels();assert (sr,ch,w.getsampwidth())==(44100,2,2)
 source=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,ch).astype(float)/32768
start,end=.655,.855
x=source[round(start*sr):round(end*sr)].copy()
n=round(.002*sr);x[:n]*=np.sin(np.linspace(0,np.pi/2,n))[:,None]**2
n=round(.025*sr);x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))[:,None]**2
x*=10**(-11/20)/abs(x).max();pcm=np.round(x*32767).astype('<i2')
f=P/'rat_attack_second.wav'
with wave.open(str(f),'wb') as w:w.setnchannels(ch);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
m={'status':'原素材第二段获负责人指定；精确切点待试听，未接入','event_key':'rat_attack','file':f.name,'source_title':'Rockburst5.wav','author':'Cheddababy','source_page':'https://freesound.org/people/Cheddababy/sounds/325913/','license':'CC BY 3.0','license_url':'https://creativecommons.org/licenses/by/3.0/','checked_date':'2026-10-09','source_kind':'Public HQ MP3 preview, not authenticated original WAV download','download_url':'https://cdn.freesound.org/previews/325/325913_5588237-hq.mp3','source_sha256':sha(P/'source/325913_5588237-hq.mp3'),'decoded_sha256':sha(P/'source/preview-decoded.wav'),'source_duration':len(source)/sr,'source_start':start,'source_end':end,'duration':len(x)/sr,'format':'44100Hz stereo 16bit PCM WAV','changes':'Extract second impact at 0.655–0.855s; 2ms fade-in/25ms fade-out; peak -11dBFS. No pitch/time changes, synthesis or added layers.','peak_dbfs':float(20*np.log10(abs(pcm.astype(float)).max()/32768)),'sha256':sha(f)}
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print('Second impact extracted: 0.200s')
