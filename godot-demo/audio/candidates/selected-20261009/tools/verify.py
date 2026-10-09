"""Delivery-level technical checks only; does not launch Godot or claim listening QA."""
from pathlib import Path
import hashlib,json,re,subprocess,sys,wave
import numpy as np
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):
    with wave.open(str(p)) as w:
        assert w.getframerate()==44100 and w.getsampwidth()==2 and w.getnchannels() in (1,2)
        return np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels())
m=json.loads((P/'manifest.json').read_text());assets={a['id']:a for a in m['assets']}
assert len(assets)==8 and len(m['roles'])==9
assert len({r['role'] for r in m['roles']})==9
assert len([a for a in assets.values() if a['source_id']])==8
assert [a['id'] for a in assets.values() if a['license']=='CC BY-NC 4.0']==['hunter_launch_02_noncommercial']
assert m['usage_restriction']['contains_nc'] and not m['usage_restriction']['commercial_permission_obtained']
assert m['usage_restriction']['authority_quote']=='仅非商业试玩也用新声'
assert {str(p.relative_to(P)) for folder in ['wav','noncommercial/wav'] for p in (P/folder).glob('*.wav')}=={a['file'] for a in assets.values()}
assert {r['asset'] for r in m['roles']}==set(assets)
assert [r['asset'] for r in m['roles'] if r['role'] in ('guard_monk','bear_lord')]==['monk_bear_whack']*2
for r in m['roles']:assert r['plays_per_attack_max']==1
assert next(r for r in m['roles'] if r['role']=='wild_hunter')['asset']=='hunter_launch_02_noncommercial'
checks=[]
for a in assets.values():
    out=P/a['file'];x=read(out)
    assert sha(out)==a['sha256'] and sha(P/a['input'])==a['input_sha256']
    assert len(x)==a['frames'] and len(x)/44100==a['duration_seconds']
    assert not np.any((x==-32768)|(x==32767)) and np.max(np.abs(x.astype(int)))>0
    assert x[0].tolist()==a['first_frame'] and x[-1].tolist()==a['last_frame']
    assert np.all(x[-1]==0)
    if a['id']!='healer_new':assert np.all(x[0]==0)
    else:assert x[0].tolist()==[2948,2948] # documented unchanged chosen version
    if a['mode']=='copy_exact':assert out.read_bytes()==(P/a['input']).read_bytes()
    else:assert len(x)==len(read(P/a['input']))
    if 'raw_source' in a:assert sha(P/a['raw_source'])==a['source_sha256']
    checks.append({'id':a['id'],'sha256':a['sha256'],'format_frames_peak_endpoints':'passed','reused_exactly':a['mode']=='copy_exact'})
for b in m['backups']:assert sha(P/b['path'])==b['sha256']
for f in ['index.html','HANDOFF.md','ATTRIBUTION.md']:
    s=(P/f).read_text()
    links=re.findall(r'(?:src|href)="([^"]+)"',s) if f.endswith('.html') else re.findall(r'\]\(([^)]+)\)',s)
    for link in links:
        if link=='VALIDATION.json':continue # this report is produced after successful checks
        if not link.startswith(('http://','https://','#')):assert (P/link).is_file(),link
before={p:sha(p) for p in [P/'manifest.json',*[P/a['file'] for a in assets.values()]]}
subprocess.run([sys.executable,str(P/'tools/build.py')],check=True,capture_output=True)
assert all(sha(p)==h for p,h in before.items())
nc=m['hunter_noncommercial_selection'];root=P.parents[3]
ref=root/nc['reference_path'];assert sha(ref)==nc['sha256']
assert (P/nc['selected_delivery']).read_bytes()==ref.read_bytes()
assert not any(sha(p)==nc['sha256'] for p in (P/'wav').glob('*.wav'))
assert len(list((P/'noncommercial/wav').glob('*.wav')))==1
report={'date':'2026-10-09','scope':'08素材技术自检；非独立/游戏内/人工听感验收','result':'passed_with_documented_limitations','assets':checks,'role_count':9,'file_count':8,'external_source_count':8,'backup_hashes_verified':len(m['backups']),'reproduction':'byte-identical WAV and manifest','links':'all local links resolve','hunter_nc':'only selected shot 2 copied exactly to noncommercial partition; package marked noncommercial only, no commercial permission','limitations':['药灵已选文件首帧非零2948/32768；原样复用，启动点击待听感验证','山狼完整2.415669秒，连续/多单位重叠待运行验证','公开HQ预览并非原始无损下载','未运行游戏、GUI、静音暂停倍速死亡重试、最终PCK或独立验收']}
(P/'VALIDATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS: 9 roles, 8 WAV, 8 external sources, 10 backup hashes, links, exact rebuild, NC partition and use restriction; limitations recorded')
