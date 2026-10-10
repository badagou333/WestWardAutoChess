"""Build a local audition page from current runtime mappings; never edits runtime sounds."""
from pathlib import Path
import hashlib,html,json,math,re,struct,wave
P=Path(__file__).resolve().parents[1];A=P.parents[1];G=A.parent
runtime=A/'runtime/board-selected-20261009';v1=A/'candidates/v1'
manifest=json.loads((runtime/'manifest.json').read_text());assets={a['id']:a for a in manifest['assets']}
# Reproduce the unchanged runtime-generated victory cue, not a new design.
code=(G/'scripts/presentation/audio_feedback.gd').read_text()
assert '"victory":[1046,0.18]' in code and 'exp(-t*18)' in code and '*0.45*32767' in code
rate=22050;count=int(.18*rate)
pcm=b''.join(struct.pack('<h',int(math.sin(math.tau*1046*i/rate)*math.sin(math.pi*i/count)*math.exp(-i/rate*18)*.45*32767)) for i in range(count))
with wave.open(str(P/'victory_runtime_preview.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(pcm)
def duration(p):
 with wave.open(str(p)) as w:return w.getnframes()/w.getframerate()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def relative(p):
 import os
 return os.path.relpath(p,P)
items=[]
info={
'monk_bear_whack':('护寺棍僧 · 熊山君','棍棒打击','两名角色共用；近战有效命中时播放。'),
'hunter_launch_02_noncommercial':('山野猎户','弓箭发射 · 第2段','箭射出时播放，不包含后续命中声。'),
'sparrow_attack':('山雀精','投射攻击 · 前段','投射物发出时播放。'),
'foxfire_A':('狐火小妖','火球发射 · A版','火球发出时播放。'),
'rat_attack':('灰鼠喽啰','投石打击 · 第2段','投石有效命中时播放。'),
'boar_attack_full':('山猪喽啰','锤击','近战有效命中时播放。'),
'wolf_attack_full':('山狼','撕咬攻击 · 完整版','近战有效命中时播放，完整保留长尾。'),
'healer_new':('药灵童子','治疗 · 新版','实际恢复生命时播放；旧版已保留备用。')}
for id,(name,title,note) in info.items():
 a=assets[id];p=runtime/a['file'];assert sha(p)==a['sha256']
 items.append(dict(id=id,name=name,title=title,note=note,group='attack',src=relative(p),duration=duration(p),sha256=sha(p),origin='current runtime WAV',license=a['license']))
for key,name,title,note in [('rat_death','灰鼠喽啰','死亡','灰鼠死亡时播放。'),('boar_death','山猪喽啰','死亡','山猪死亡时播放。'),('wolf_death','山狼','死亡','山狼死亡时播放。'),('bear_lord_death','熊山君','死亡','熊山君死亡时播放。'),('tangseng_hurt_warning','唐僧','受伤警示','唐僧实际受伤时播放，有冷却限制。')]:
 p=v1/'wav'/(key+'.wav');items.append(dict(id=key,name=name,title=title,note=note,group='other',src=relative(p),duration=duration(p),sha256=sha(p),origin='existing v1 runtime WAV',license='项目旧合成音效'))
p=P/'victory_runtime_preview.wav';items.append(dict(id='victory',name='战斗结果',title='胜利提示',note='获胜时播放。此试听按游戏内相同生成公式导出。',group='other',src=p.name,duration=duration(p),sha256=sha(p),origin='runtime formula reproduction; not game-recorded output',license='项目程序生成提示音'))
(P/'inventory.json').write_text(json.dumps({'date':'2026-10-10','scope':'当前棋盘Demo，14种声音/15事件；不含未触发UI/共用受击/退场','items':items},ensure_ascii=False,indent=2)+'\n')
cards=[]
for i,x in enumerate(items):
 tag='已选新版' if x['group']=='attack' else ('程序提示' if x['id']=='victory' else '旧版仍在用')
 cards.append(f'''<article data-group="{x['group']}" aria-label="{x['name']} {x['title']}"><div class="cardtop"><span class="number">{i+1:02d}</span><span class="tag">{tag}</span><span class="duration">{x['duration']:.2f} 秒</span></div><h2>{x['name']}</h2><h3>{x['title']}</h3><p>{x['note']}</p><audio controls preload="none" aria-label="试听{x['name']}的{x['title']}" src="{x['src']}"></audio><footer>{html.escape(x['license'])}</footer></article>''')
page='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>西游塔防 · 当前音效试听</title><style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,"PingFang SC",sans-serif;background:#111b1c;color:#f0ecdf}*{box-sizing:border-box}body{margin:0}main{max-width:1100px;margin:auto;padding:44px 26px 60px}.eyebrow{color:#bea775;font-size:12px;letter-spacing:3px}h1{font-size:clamp(28px,5vw,42px);font-weight:650;letter-spacing:-1px;margin:10px 0 14px}.intro{color:#aabdb7;line-height:1.8;max-width:720px}.stats{display:flex;gap:24px;margin:26px 0;color:#b6c4be}.stats b{font-size:28px;color:#e6d5ac;margin-right:6px}.toolbar{position:sticky;top:0;z-index:2;background:#111b1cf5;border-block:1px solid #344440;display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:16px 0;margin-bottom:24px}button{font:inherit;color:#c6d0ca;background:#243632;border:1px solid #4b5b51;border-radius:24px;padding:9px 17px;cursor:pointer}button[aria-pressed=true]{background:#d8c290;color:#17211e;border-color:#d8c290}button:focus-visible,a:focus-visible{outline:3px solid #e5bd63;outline-offset:3px}.stop{margin-left:auto}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}article{padding:23px;background:#1b2a27;border:1px solid #37453b;border-radius:16px}article[hidden]{display:none}.cardtop{display:flex;align-items:center;gap:12px}.number{font-size:13px;color:#9daa94}.tag{font-size:11px;padding:3px 9px;border-radius:20px;background:#334237;color:#e0d2ad}.duration{margin-left:auto;color:#a2b5a6;font-size:13px}h2{font-size:21px;margin:20px 0 6px}h3{font-size:15px;font-weight:400;color:#d7c597;margin:0}article p{font-size:14px;color:#acbdb4;line-height:1.7;min-height:48px;margin:12px 0}audio{width:100%;height:42px}footer{font-size:11px;color:#99a99c;margin-top:14px}.notes{font-size:13px;line-height:1.9;color:#a7b8ae;margin-top:28px;border-top:1px solid #344440;padding-top:18px}a{color:#dfc997}#status{font-size:12px;color:#d4bd8b;min-height:20px;margin-bottom:12px}@media(max-width:620px){main{padding:28px 16px}.grid{grid-template-columns:1fr}.toolbar{gap:6px}button{font-size:13px;padding:9px 12px}.stats{gap:14px;font-size:13px}.stats b{font-size:24px}}
</style></head><body><main><div class="eyebrow">西游塔防 / SOUND LIBRARY</div><h1>当前游戏音效</h1><p class="intro">点击每条声音的播放按钮即可试听。攻击、治疗，以及仍在使用的死亡和提示声，都放在这里了。播放另一条时，上一条会自动停止。</p><div class="stats"><span><b>14</b>种声音</span><span><b>15</b>个游戏事件</span><span><b>8</b>种攻击与治疗声</span></div><nav class="toolbar" aria-label="音效分类"><button data-filter="all" aria-pressed="true">全部 · 14</button><button data-filter="attack" aria-pressed="false">攻击与治疗 · 8</button><button data-filter="other" aria-pressed="false">死亡与提示 · 6</button><button class="stop" id="stop">停止播放</button></nav><div id="status" role="status" aria-live="polite">选择一条声音开始试听</div><section class="grid">'''+''.join(cards)+'''</section><div class="notes">棍僧与熊山君共用一条打击声。英雄退场声未启用，当前攻击不叠加材质受击声；未接线的 UI 点击声不在本页。<br>本页单独试听音频，音量与游戏内混音可能不同；不会修改游戏设置。猎户音效为 CC BY-NC 4.0，当前整版仅供非商业试玩。<br><a href="../../runtime/board-selected-20261009/ATTRIBUTION.md">素材来源与授权</a> · <a href="../../candidates/healer-lilmati-v1/index.html">药灵童子新旧版对比</a> · 核对日期：2026-10-10</div></main><script>
const audios=[...document.querySelectorAll('audio')],status=document.querySelector('#status');
function stopAll(except){audios.forEach(a=>{if(a!==except){a.pause();if(a.readyState)a.currentTime=0;}});}
audios.forEach(a=>{a.volume=.5;a.addEventListener('play',()=>{stopAll(a);status.textContent='正在播放：'+a.closest('article').getAttribute('aria-label');});a.addEventListener('ended',()=>status.textContent='播放完成，可以选择下一条');a.addEventListener('error',()=>status.textContent='这条声音暂时无法加载，请确认音频文件仍在原目录。');});
document.querySelector('#stop').addEventListener('click',()=>{stopAll();status.textContent='已停止播放';});
document.querySelectorAll('[data-filter]').forEach(b=>b.addEventListener('click',()=>{stopAll();document.querySelectorAll('[data-filter]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));document.querySelectorAll('article').forEach(c=>c.hidden=b.dataset.filter!=='all'&&c.dataset.group!==b.dataset.filter);status.textContent='当前显示：'+b.textContent;}));
</script></body></html>'''
(P/'index.html').write_text(page)
assert len(items)==14
for src in re.findall(r'(?:src|href)="([^"]+)"',page):assert (P/src).is_file(),src
print('14 audio entries and all local links verified; runtime WAVs referenced unchanged')
