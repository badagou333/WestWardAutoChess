"""NONCOMMERCIAL REFERENCE ONLY: Robinhood76, CC BY-NC 4.0.
See ../ATTRIBUTION.md. Three launch excerpts; no synthesized audio.
Python 3 + NumPy. Archived input is decoded public HQ MP3 preview.
"""
from pathlib import Path
import wave,json,hashlib
import numpy as np
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with wave.open(str(P/'source/preview-decoded.wav')) as w:
 sr=w.getframerate();ch=w.getnchannels();assert (sr,ch,w.getsampwidth())==(44100,2,2)
 source=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,ch).astype(float)/32768
# Gaps after launch, before the later strong target-impact transients.
cuts=[(.270,.425,.49),(1.955,2.085,2.12),(3.465,3.615,4.25)]
entries=[]
for i,(start,end,impact_at) in enumerate(cuts,1):
 x=source[round(start*sr):round(end*sr)].copy()
 n=round(.002*sr);x[:n]*=np.sin(np.linspace(0,np.pi/2,n))[:,None]**2
 n=round(.012*sr);x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))[:,None]**2
 x*=10**(-11/20)/abs(x).max();pcm=np.round(x*32767).astype('<i2')
 f=P/f'hunter_launch_{i:02d}.wav'
 with wave.open(str(f),'wb') as w:w.setnchannels(ch);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
 entries.append({'file':f.name,'source_start':start,'source_end':end,'later_impact_transient_approx':impact_at,'duration':len(x)/sr,'peak_dbfs':float(20*np.log10(abs(pcm.astype(float)).max()/32768)),'sha256':sha(f)})
m={'status':'NONCOMMERCIAL REFERENCE ONLY; commercial permission unresolved; not approved for game integration','source_title':'02658 single arrows.wav','author':'Robinhood76','source_page':'https://freesound.org/people/Robinhood76/sounds/126464/','license':'CC BY-NC 4.0','license_url':'https://creativecommons.org/licenses/by-nc/4.0/','checked_date':'2026-10-09','source_kind':'Public HQ MP3 preview; not original authenticated WAV download','download_url':'https://cdn.freesound.org/previews/126/126464_321967-hq.mp3','source_sha256':sha(P/'source/126464_321967-hq.mp3'),'decoded_sha256':sha(P/'source/preview-decoded.wav'),'source_duration':len(source)/sr,'format':'44100Hz stereo 16bit PCM WAV','changes':'Extract first launch transient of each of three shots before later impact; 2ms fade in/12ms fade out; peak -11dBFS. No pitch/time change or synthesized layers.','entries':entries}
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
print('Created 3 launch references:',[round(e['duration'],3) for e in entries])
