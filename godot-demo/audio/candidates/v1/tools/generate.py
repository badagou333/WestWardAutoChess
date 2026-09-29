"""Original deterministic DSP sketches, not recordings or voice imitations.
Run with Python 3 + numpy. Writes only this candidate pack.
"""
from pathlib import Path
import hashlib, json, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
rng = np.random.default_rng(29092026)

def env(t, decay=.1, attack=.004):
    return (1-np.exp(-t/attack))*np.exp(-t/decay)

def noise(n, low=100, high=6000):
    x = rng.normal(size=n)
    f = np.fft.rfftfreq(n, 1/SR)
    # Smooth filters avoid sharp frequency-domain ringing.
    hp = 1-np.exp(-(f/max(low, 1))**4)
    lp = np.exp(-(f/high)**4)
    x = np.fft.irfft(np.fft.rfft(x)*hp*lp, n)
    return x/(np.sqrt(np.mean(x*x))+1e-9)

def tone(t, start, end, decay=.12):
    f = end+(start-end)*np.exp(-t/.045)
    return np.sin(2*np.pi*np.cumsum(f)/SR)*env(t, decay)

def modes(t, base, metal=False, decay=.13):
    ratios = [1, 1.47, 2.09, 2.71, 3.93] if metal else [1, 2.76, 5.40]
    return sum(np.sin(2*np.pi*base*r*t)*env(t, decay/(1+i*.5), .0015)/(1+i) for i,r in enumerate(ratios))

def beast(t, base, end, size=1):
    f = np.linspace(base,end,len(t))*(1+.035*np.sin(2*np.pi*23*t))
    phase = 2*np.pi*np.cumsum(f)/SR
    # Breathy harmonic gesture, deliberately stylized rather than a real animal recording.
    voice = sum(np.sin(k*phase)/(k**1.25) for k in range(1,10))
    return (voice*.48+noise(len(t),250,1800)*.16)*env(t,.15*size,.012)*(0.8+.2*np.sin(2*np.pi*31*t))

def sound(kind, duration):
    t=np.arange(round(duration*SR))/SR
    n=len(t)
    if kind=='wood': x=modes(t,370)*.55+noise(n,400,4500)*env(t,.035)*.15+tone(t,160,95,.08)*.4
    elif kind=='blade': x=noise(n,1800,9500)*env(t,.055,.002)*.27+modes(t,1150,True,.08)*.2+tone(t,150,90,.055)*.4
    elif kind=='wind': x=noise(n,500,8000)*env(t,.1,.012)*.4+tone(t,1300,720,.13)*.16
    elif kind=='herb':
        x=noise(n,2500,8500)*env(t,.08,.015)*.13
        for delay,f in [(0,540),(.045,810),(.09,1080)]:
            tt=np.maximum(0,t-delay); x+=np.sin(2*np.pi*f*tt)*env(tt,.14,.003)*.22
    elif kind=='fire':
        # Fireball revision: ignition -> turbulent air/flame -> soft ember tail.
        # Two noise draws preserve every subsequent cue's random sequence.
        body=noise(n,110,1900)
        air=noise(n,950,6200)
        launch=env(t,.075,.006)
        passing=env(t,.090,.016)
        turbulence=1+.14*np.sin(2*np.pi*37*t)+.09*np.sin(2*np.pi*61*t)
        ignition=np.exp(-((t-.012)/.005)**2)
        embers=sum(a*np.exp(-((t-at)/width)**2) for at,width,a in
                   [(.054,.0018,.08),(.093,.0024,.055),(.143,.0028,.035)])
        x=body*launch*.62+air*passing*turbulence*.24+air*(ignition*.085+embers)
    elif kind=='scratch': x=noise(n,1800,9000)*env(t,.035)*.35+modes(t,730,False,.035)*.18
    elif kind=='hammer': x=tone(t,145,52,.13)*.65+modes(t,430,True,.10)*.20+noise(n,100,3500)*env(t,.045)*.20
    elif kind=='bite': x=noise(n,500,6500)*env(t,.025)*.30+tone(t,220,95,.055)*.40+beast(t,125,85)*.18
    elif kind=='bear_slam': x=tone(t,110,43,.19)*.65+noise(n,100,2300)*env(t,.085)*.28+modes(t,210,False,.08)*.15
    elif kind=='monk_exit': x=beast(t,140,85,2)*.5+modes(t,300,False,.13)*.18+noise(n,500,4000)*env(t,.15)*.10
    elif kind=='hunter_exit': x=beast(t,190,100,1.6)*.45+modes(t,640,True,.14)*.1+noise(n,700,3500)*env(t,.13)*.12
    elif kind=='sparrow_exit': x=(tone(t,1700,800,.22)+tone(t,2300,1300,.17))*.17+noise(n,1200,7500)*env(t,.15,.015)*.15
    elif kind=='herb_exit': x=modes(t,650,False,.22)*.18+noise(n,1800,6500)*env(t,.24,.02)*.16+tone(t,740,300,.25)*.15
    elif kind=='fox_exit': x=beast(t,380,180,1.4)*.3+noise(n,350,5000)*env(t,.22,.012)*.16+tone(t,520,150,.24)*.18
    elif kind=='rat_exit': x=beast(t,850,470,1.2)*.36+noise(n,700,4000)*env(t,.08)*.13
    elif kind=='boar_exit': x=beast(t,100,62,2.4)*.65+noise(n,100,2000)*env(t,.2)*.15
    elif kind=='wolf_exit': x=beast(t,310,115,2.7)*.6+noise(n,250,2400)*env(t,.22)*.1
    elif kind=='bear_exit': x=beast(t,82,45,3.8)*.65+tone(t,110,40,.33)*.22+noise(n,80,2300)*env(t,.28)*.16
    elif kind=='flesh': x=noise(n,120,2200)*env(t,.025)*.3+tone(t,155,65,.045)*.45
    elif kind=='fur': x=noise(n,450,3800)*env(t,.038)*.32+tone(t,170,80,.045)*.32
    elif kind=='armor': x=modes(t,820,True,.065)*.38+noise(n,700,6500)*env(t,.021)*.13+tone(t,180,90,.04)*.2
    elif kind=='warning':
        x=np.zeros(n)
        for delay in [0,.17]:
            tt=np.maximum(0,t-delay); x+=modes(tt,690,True,.09)*.22+tone(tt,460,420,.09)*.18
    else: raise ValueError(kind)
    # Remove DC; equal-power onset/ending guards, no truncation clicks.
    x-=np.mean(x)
    k=min(int(.012*SR),n//4); x[:int(.002*SR)]*=np.linspace(0,1,int(.002*SR))
    x[-k:]*=np.linspace(1,0,k)**2
    return x

# key, role, event, texture, duration, target peak dBFS, trigger
SPECS=[
('guard_monk_attack','护寺棍僧','攻击','wood',.28,-9,'近战命中结算'),
('wild_hunter_attack','山野猎户','攻击','blade',.25,-10,'近战命中结算；刀刃质感为待审提案'),
('sparrow_spirit_attack','山雀精','攻击','wind',.36,-12,'投射物释放；风刃质感不代表新增技能'),
('herbal_spirit_child_attack','药灵童子','治疗','herb',.48,-12,'治疗实际生效'),
('foxfire_imp_attack','狐火小妖','攻击','fire',.40,-11,'狐火释放'),
('rat_attack','灰鼠喽啰','攻击','scratch',.20,-14,'近战命中结算；抓挠质感待审'),
('boar_attack','山猪喽啰','攻击','hammer',.38,-10,'锤击命中结算'),
('wolf_attack','山狼','攻击','bite',.27,-12,'扑咬命中结算'),
('bear_lord_attack','熊山君','攻击','bear_slam',.48,-8,'近战命中结算'),
('guard_monk_retreat','护寺棍僧','退场','monk_exit',.65,-10,'存活转退场，仅一次'),
('wild_hunter_retreat','山野猎户','退场','hunter_exit',.60,-10,'存活转退场，仅一次'),
('sparrow_spirit_retreat','山雀精','退场','sparrow_exit',.65,-11,'存活转退场，仅一次'),
('herbal_spirit_child_retreat','药灵童子','退场','herb_exit',.70,-11,'存活转退场，仅一次'),
('foxfire_imp_retreat','狐火小妖','退场','fox_exit',.70,-10,'存活转退场，仅一次'),
('rat_death','灰鼠喽啰','死亡','rat_exit',.46,-15,'死亡结算，仅一次'),
('boar_death','山猪喽啰','死亡','boar_exit',.75,-13,'死亡结算，仅一次'),
('wolf_death','山狼','死亡','wolf_exit',.85,-13,'死亡结算，仅一次'),
('bear_lord_death','熊山君','死亡','bear_exit',1.15,-7,'Boss死亡结算，仅一次'),
('shared_hit_flesh','共用','受击：肉身','flesh',.17,-18,'非致命受击'),
('shared_hit_fur','共用','受击：毛皮','fur',.20,-18,'非致命受击'),
('shared_hit_armor','共用','受击：护甲','armor',.23,-18,'非致命受击'),
('tangseng_hurt_warning','唐僧','遇险警示','warning',.52,-8,'唐僧实际受伤；冷却建议1秒'),
]

def write_wav(path,x):
    pcm=np.round(np.clip(x,-1,1)*32767).astype('<i2')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    return pcm

def main():
    out=ROOT/'wav'; out.mkdir(exist_ok=True)
    entries=[]; reel=[]; pos=0
    for key,role,event,kind,duration,peak,trigger in SPECS:
        x=sound(kind,duration); x*=10**(peak/20)/max(abs(x))
        path=out/(key+'.wav'); pcm=write_wav(path,x)
        rms=float(np.sqrt(np.mean((pcm.astype(float)/32768)**2)))
        entries.append(dict(key=key,role=role,event=event,file='wav/'+path.name,texture=kind,status='待试听审核',trigger_proposal=trigger,duration_seconds=len(x)/SR,peak_dbfs=round(20*np.log10(max(abs(pcm.astype(float)))/32768),2),rms_dbfs=round(20*np.log10(rms),2),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),reel_start_seconds=round(pos/SR,2)))
        gap=np.zeros(round(.60*SR)); reel.extend([x,gap]); pos+=len(x)+len(gap)
    write_wav(ROOT/'audition_all.wav',np.concatenate(reel))
    (ROOT/'manifest.json').write_text(json.dumps(dict(pack='v1',status='待审，未接入游戏',source='Original procedural synthesis; no external samples, no voice cloning.',format='PCM signed 16-bit mono 44100 Hz',entries=entries),ensure_ascii=False,indent=2)+'\n')
    rows=''.join(f'<tr><td>{i+1}</td><td>{e["role"]}</td><td>{e["event"]}</td><td><audio controls preload="none" src="{e["file"]}"></audio></td><td>{e["duration_seconds"]:.2f}s</td></tr>' for i,e in enumerate(entries))
    (ROOT/'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>西游塔防 · 音效候选 v1</title><style>body{max-width:1000px;margin:40px auto;padding:0 24px;background:#191e21;color:#eee6d3;font:16px/1.7 system-ui}h1{color:#dac296}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:12px;border-bottom:1px solid #414747}audio{max-width:100%}p{color:#bdc7c6}</style><h1>音效候选 v1 · 待试听审核</h1><p>5名英雄、4类怪物。原创程序合成小样，尚未接入游戏；兽声为风格化合成。建议从较低设备音量开始试听。按行顺序合辑，各条间隔0.6秒。</p><audio controls preload="none" src="audition_all.wav"></audio><p>审核关注：角色辨识、刺耳或疲劳感、攻击力度、退场提醒是否清楚。单听通过后仍需在实际混战中检查。</p><table><thead><tr><th>#</th><th>角色</th><th>事件</th><th>试听</th><th>时长</th></tr></thead><tbody>'''+rows+'</tbody></table></html>')
    print(f'Generated {len(entries)} cues; reel {pos/SR:.2f}s')

if __name__=='__main__': main()
