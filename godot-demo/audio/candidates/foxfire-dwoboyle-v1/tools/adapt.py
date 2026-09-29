"""Adapt DWOBoyle's Fire Ball (CC BY 4.0); see ../ATTRIBUTION.md.
Requires Python 3 + NumPy. No synthesis, pitch shifting or time stretching.
Input is the archived decoded public HQ MP3 preview, NOT the original WAV.
"""
from pathlib import Path
import hashlib, json, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
SR=44100

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def write(name,x):
    x=x-np.mean(x)
    fade_in=min(round(.002*SR),len(x))
    x[:fade_in]*=np.sin(np.linspace(0,np.pi/2,fade_in))**2
    x[-fade_in:]*=np.cos(np.linspace(0,np.pi/2,fade_in))**2
    x*=10**(-11/20)/np.max(np.abs(x))
    pcm=np.round(x*32767).astype('<i2')
    with wave.open(str(ROOT/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR);w.writeframes(pcm.tobytes())
    return {'file':name,'duration_seconds':len(x)/SR,'peak_dbfs':float(20*np.log10(max(abs(pcm.astype(float)))/32768)),
            'rms_dbfs':float(20*np.log10(np.sqrt(np.mean((pcm.astype(float)/32768)**2)))), 'sha256':sha(ROOT/name)}

def fade_end(x,seconds):
    k=round(seconds*SR);x[-k:]*=np.cos(np.linspace(0,np.pi/2,k))**2;return x

with wave.open(str(ROOT/'source/preview-decoded.wav')) as w:
    assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(2,2,SR)
    source=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,2)/32768.
mono=source.mean(axis=1)
# A retains all meaningful source audio; discarded tail is effectively silent.
a=fade_end(mono[:round(.57*SR)].copy(),.035)
# B keeps the original attack and fiery tail, with a slightly earlier onset.
# Smooth FFT filters with padding: remove rumble and gently soften presence only.
size=1
while size<len(mono)*4: size*=2
pad=np.zeros(size); offset=size//4;pad[offset:offset+len(mono)]=mono
f=np.fft.rfftfreq(size,1/SR)
hp=1/np.sqrt(1+(55/np.maximum(f,.001))**4)
soft_presence=10**((-1.5*np.exp(-.5*(np.log2(np.maximum(f,1)/3300)/.7)**2))/20)
lp=1/np.sqrt(1+(f/10500)**4)
filtered=np.fft.irfft(np.fft.rfft(pad)*hp*soft_presence*lp,size)[offset:offset+len(mono)]
b=fade_end(filtered[round(.035*SR):round(.49*SR)].copy(),.065)
entries=[write('foxfire_A_faithful.wav',a),write('foxfire_B_short.wav',b)]
manifest={'status':'待试听；独立候选，未替换运行时声音','title':'Fire Ball','author':'DWOBoyle',
'source_page':'https://freesound.org/people/DWOBoyle/sounds/136696/','license':'CC BY 4.0',
'license_url':'https://creativecommons.org/licenses/by/4.0/','source_kind':'Public HQ MP3 preview; not original WAV',
'download_url':'https://cdn.freesound.org/previews/136/136696_2289019-hq.mp3',
'source_sha256':sha(ROOT/'source/136696_2289019-hq.mp3'),'decoded_sha256':sha(ROOT/'source/preview-decoded.wav'),
'format':'44100 Hz, mono, PCM 16-bit','edits':{'A':'Stereo averaged to mono; nearly silent tail removed; short endpoint fades; peak -11dBFS.',
'B':'Mono; 55Hz high-pass; broad -1.5dB at 3.3kHz; gentle 10.5kHz low-pass; source 0.035–0.490s; 65ms tail fade; peak -11dBFS. No new sound layers or pitch/time change.'},'entries':entries}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(entries,indent=2))
