# -*- coding: utf-8 -*-
"""Build audition inventory from the current D001 runtime manifest; no audio generation."""
from pathlib import Path
import hashlib,html,json,re,wave
P=Path(__file__).resolve().parents[1];A=P.parents[1]
runtime=A/'runtime/board-selected-20261010'
manifest=json.loads((runtime/'manifest.json').read_text());assets={a['id']:a for a in manifest['assets']}
assert manifest['profile']=='board-selected-noncommercial-20261010'
rules=manifest['roles']+manifest['secondary_cues']
assert len(assets)==9 and len(rules)==10
assert set(r['event_key'] for r in rules)==set(manifest['preserve_cues'])
assert not set(manifest['disable_cues']) & set(manifest['preserve_cues'])
def duration(p):
 with wave.open(str(p)) as w:return w.getnframes()/w.getframerate()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(p):
 import os
 return os.path.relpath(p,P)
info={
'monk_bear_whack':('护寺棍僧 · 熊山君','棍棒打击','两名角色共用；近战有效命中时播放。'),
'hunter_launch_02_noncommercial':('山野猎户','弓箭发射 · 第2段','箭射出时播放，不包含后续命中声。'),
'sparrow_attack':('山雀精','投射攻击 · 前段','投射物发出时播放。'),
'foxfire_A':('狐火小妖','火球发射 · A版','火球发出时播放。'),
'rat_attack':('灰鼠喽啰','投石打击 · 第2段','投石有效命中时播放。'),
'boar_attack_full':('山猪喽啰','锤击','近战有效命中时播放。'),
'wolf_first_call':('山狼','撕咬攻击 · 第一声短版','近战有效命中时播放，已换成确认的0.29秒短版。'),
'healer_new':('药灵童子','治疗 · 新版','实际恢复生命时播放；旧版已保留备用。'),
'tangseng_hurt_warning':('唐僧','受伤警示','唐僧实际受伤时播放，有冷却限制。')}
# Presentation order only; all paths, licenses and events come from runtime.
assert set(info)==set(assets)
items=[]
for id,(name,title,note) in info.items():
 a=assets[id];p=runtime/a['file'];events=[r['event_key'] for r in rules if r['asset']==id]
 assert events and sha(p)==a['sha256'] and duration(p)==a['duration_seconds']
 items.append(dict(id=id,name=name,title=title,note=note,group='other' if id=='tangseng_hurt_warning' else 'attack',src=relative(p),duration=duration(p),sha256=sha(p),origin='current runtime WAV',license=a['license'],event_keys=events))
assert len({x['src'] for x in items})==9 and sum(len(x['event_keys']) for x in items)==10
inventory={'date':'2026-10-10','profile':manifest['profile'],'runtime_manifest':relative(runtime/'manifest.json'),'scope':'当前棋盘Demo，9种声音/10事件；死亡与战斗结果声已停用，旧源仅保备用','sound_count':len(items),'event_count':len(rules),'implementation_commit':'6052f18','verification_status':'程序已接入，作者技术验证完成；本批独立验收与设备/混战听感尚未完成','items':items}
(P/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n')
cards=[]
for i,x in enumerate(items):
 tag='已接入' if x['group']=='attack' else '保留警示'
 cards.append(f'''<article data-group="{x['group']}" aria-label="{x['name']} {x['title']}"><div class="cardtop"><span class="number">{i+1:02d}</span><span class="tag">{tag}</span><span class="duration">{x['duration']:.2f} 秒</span></div><h2>{x['name']}</h2><h3>{x['title']}</h3><p>{x['note']}</p><audio controls preload="none" aria-label="试听{x['name']}的{x['title']}" src="{x['src']}"></audio><footer>{html.escape(x['license'])}</footer></article>''')
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>西游塔防 · 当前音效试听</title><style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,"PingFang SC",sans-serif;background:#111b1c;color:#f0ecdf}*{box-sizing:border-box}body{margin:0}main{max-width:1100px;margin:auto;padding:44px 26px 60px}.eyebrow{color:#bea775;font-size:12px;letter-spacing:3px}h1{font-size:clamp(28px,5vw,42px);font-weight:650;letter-spacing:-1px;margin:10px 0 14px}.intro{color:#aabdb7;line-height:1.8;max-width:720px}.stats{display:flex;gap:24px;margin:26px 0;color:#b6c4be}.stats b{font-size:28px;color:#e6d5ac;margin-right:6px}.toolbar{position:sticky;top:0;z-index:2;background:#111b1cf5;border-block:1px solid #344440;display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:16px 0;margin-bottom:24px}button{font:inherit;color:#c6d0ca;background:#243632;border:1px solid #4b5b51;border-radius:24px;padding:9px 17px;cursor:pointer}button[aria-pressed=true]{background:#d8c290;color:#17211e;border-color:#d8c290}button:focus-visible,a:focus-visible{outline:3px solid #e5bd63;outline-offset:3px}.stop{margin-left:auto}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}article{padding:23px;background:#1b2a27;border:1px solid #37453b;border-radius:16px}article[hidden]{display:none}.cardtop{display:flex;align-items:center;gap:12px}.number{font-size:13px;color:#9daa94}.tag{font-size:11px;padding:3px 9px;border-radius:20px;background:#334237;color:#e0d2ad}.duration{margin-left:auto;color:#a2b5a6;font-size:13px}h2{font-size:21px;margin:20px 0 6px}h3{font-size:15px;font-weight:400;color:#d7c597;margin:0}article p{font-size:14px;color:#acbdb4;line-height:1.7;min-height:48px;margin:12px 0}audio{width:100%;height:42px}footer{font-size:11px;color:#99a99c;margin-top:14px}.notes{font-size:13px;line-height:1.9;color:#a7b8ae;margin-top:28px;border-top:1px solid #344440;padding-top:18px}a{color:#dfc997}#status{font-size:12px;color:#d4bd8b;min-height:20px;margin-bottom:12px}@media(max-width:620px){main{padding:28px 16px}.grid{grid-template-columns:1fr}.toolbar{gap:6px}button{font-size:13px;padding:9px 12px}.stats{gap:14px;font-size:13px}.stats b{font-size:24px}}
</style></head><body><main><div class="eyebrow">西游塔防 / SOUND LIBRARY</div><h1>当前游戏音效</h1><p class="intro">点击每条声音的播放按钮即可试听。这里列出当前已接入的攻击、治疗和唐僧受伤警示声。死亡与战斗结果声已停用。播放另一条时，上一条会自动停止。</p><div class="stats"><span><b>9</b>种声音</span><span><b>10</b>个游戏事件</span><span><b>8</b>种攻击与治疗声</span></div><nav class="toolbar" aria-label="音效分类"><button data-filter="all" aria-pressed="true">全部 · 9</button><button data-filter="attack" aria-pressed="false">攻击与治疗 · 8</button><button data-filter="other" aria-pressed="false">受伤警示 · 1</button><button class="stop" id="stop">停止播放</button></nav><div id="status" role="status" aria-live="polite">选择一条声音开始试听</div><section class="grid">'''+''.join(cards)+'''</section><div class="notes">棍僧与熊山君共用一条打击声。山狼短版已接入，四种怪物死亡声与战斗结果声已停用，旧素材保留备用。英雄退场声未启用，当前攻击不叠加材质受击声；未接线的 UI 点击声不在本页。<br>程序已完成接入及作者技术验证；本批独立验收、设备输出与混战听感尚未完成，短狼的单声试听确认不代表混战验收。本页音量与游戏内混音可能不同，不会修改游戏设置。猎户音效为 CC BY-NC 4.0，当前整版仅供非商业试玩。<br><a href="../../runtime/board-selected-20261010/ATTRIBUTION.md">素材来源与授权</a> · <a href="../../candidates/healer-lilmati-v1/index.html">药灵童子新旧版对比</a> · <a href="../../candidates/wolf-first-call-v1/index.html">山狼短版与完整备用对比</a> · 核对日期：2026-10-10</div></main><script>
const audios=[...document.querySelectorAll('audio')],status=document.querySelector('#status');
function stopAll(except){audios.forEach(a=>{if(a!==except){a.pause();if(a.readyState)a.currentTime=0;}});}
audios.forEach(a=>{a.volume=.5;a.addEventListener('play',()=>{stopAll(a);status.textContent='正在播放：'+a.closest('article').getAttribute('aria-label');});a.addEventListener('ended',()=>status.textContent='播放完成，可以选择下一条');a.addEventListener('error',()=>status.textContent='这条声音暂时无法加载，请确认音频文件仍在原目录。');});
document.querySelector('#stop').addEventListener('click',()=>{stopAll();status.textContent='已停止播放';});
document.querySelectorAll('[data-filter]').forEach(b=>b.addEventListener('click',()=>{stopAll();document.querySelectorAll('[data-filter]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));document.querySelectorAll('article').forEach(c=>c.hidden=b.dataset.filter!=='all'&&c.dataset.group!==b.dataset.filter);status.textContent='当前显示：'+b.textContent;}));
</script></body></html>'''
(P/'index.html').write_text(page)
assert len(items)==9
for src in re.findall(r'(?:src|href)="([^"]+)"',page):assert (P/src).is_file(),src
print('9 runtime sounds / 10 events verified; all local links resolve; no audio generated or changed')
