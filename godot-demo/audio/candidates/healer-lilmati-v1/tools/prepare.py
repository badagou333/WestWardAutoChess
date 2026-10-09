"""Prepare full-length comparison; no trimming, pitch changes or synthesis."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OLD=ROOT.parent/'v1/wav/herbal_spirit_child_attack.wav'
def read(p):
    with wave.open(str(p),'rb') as w:
        assert w.getsampwidth()==2 and w.getframerate()==44100
        return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels()).astype(float)/32768

def write(p,a):
    with wave.open(str(p),'wb') as w:
        w.setnchannels(a.shape[1]);w.setsampwidth(2);w.setframerate(44100)
        w.writeframes(np.round(a*32768).clip(-32768,32767).astype('<i2').tobytes())

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=read(OLD);new=read(ROOT/'source/decoded.wav')
# Match peak to the unchanged old sample. This is not perceptual loudness matching.
gain=float(np.max(np.abs(old))/np.max(np.abs(new)))
new*=gain
out=ROOT/'healer_new_full.wav'
write(out,new)
assert len(new)==39900 and np.max(np.abs(new))<1
manifest=dict(status='待负责人A/B试听选择；未接入',event_key='herbal_spirit_child_attack',source_title='Powerup 07.wav',author='LilMati',source_page='https://freesound.org/people/LilMati/sounds/523649/',license='CC0 1.0',license_url='https://creativecommons.org/publicdomain/zero/1.0/',checked_date='2026-10-09',source_kind='Public HQ MP3 preview, not original WAV download',download_url='https://cdn.freesound.org/previews/523/523649_6142149-hq.mp3',file=out.name,duration=len(new)/44100,format='44100Hz stereo 16bit PCM WAV',changes='Full duration retained. Gain only; peak matched to old sample (~-12dBFS). No trimming, pitch/time changes, synthesis, added layers or loudness matching.',gain_db=20*np.log10(gain),source_sha256=sha(ROOT/'source/523649_6142149-hq.mp3'),decoded_sha256=sha(ROOT/'source/decoded.wav'),sha256=sha(out),old_reference='../v1/wav/herbal_spirit_child_attack.wav',old_sha256=sha(OLD))
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'new_duration':len(new)/44100,'old_duration':len(old)/44100,'gain_db':manifest['gain_db'],'peak_dbfs':20*np.log10(np.max(np.abs(read(out))))},ensure_ascii=False))
