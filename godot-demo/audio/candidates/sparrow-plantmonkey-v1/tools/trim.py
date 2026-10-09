"""Trim the first event of plantmonkey's Arrow strike (CC0); no synthesis.
Python 3 + NumPy. Decoder input is archived HQ MP3 preview, not original download.
"""
from pathlib import Path
import wave,json,hashlib
import numpy as np
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with wave.open(str(P/'source/preview-decoded.wav')) as w:
 sr=w.getframerate();ch=w.getnchannels();assert (sr,ch,w.getsampwidth())==(44100,2,2)
 source=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,ch).astype(float)/32768
start,end=.17,.68
x=source[round(start*sr):round(end*sr)].copy()
n=round(.002*sr);x[:n]*=np.sin(np.linspace(0,np.pi/2,n))[:,None]**2
n=round(.025*sr);x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))[:,None]**2
x*=10**(-11/20)/abs(x).max();pcm=np.round(x*32767).astype('<i2')
f=P/'sparrow_attack_first.wav'
with wave.open(str(f),'wb') as w:w.setnchannels(ch);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
m={'status':'原素材前段获指定；精确切点待试听，未接入','event_key':'sparrow_spirit_attack','file':f.name,'source_title':'Arrow strike.mp3','author':'plantmonkey','source_page':'https://freesound.org/people/plantmonkey/sounds/410751/','license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','checked_date':'2026-10-09','source_kind':'public HQ MP3 preview, not authenticated original download','download_url':'https://cdn.freesound.org/previews/410/410751_182472-hq.mp3','source_sha256':sha(P/'source/410751_182472-hq.mp3'),'decoded_sha256':sha(P/'source/preview-decoded.wav'),'source_duration':len(source)/sr,'cut_start':start,'cut_end':end,'duration':len(x)/sr,'format':'44100Hz stereo 16bit PCM WAV','edits':'First complete event only; trim 0.170–0.680s; 2ms fade-in, 25ms fade-out; peak gain to -11dBFS. No pitch/time change, synthesis, EQ, extra layers or target-hit sound.','peak_dbfs':float(20*np.log10(abs(pcm.astype(float)).max()/32768)),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean((pcm.astype(float)/32768)**2)))),'sha256':sha(f)}
(P/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
print('Trimmed first event: 0.170–0.680s, output 0.510s')
