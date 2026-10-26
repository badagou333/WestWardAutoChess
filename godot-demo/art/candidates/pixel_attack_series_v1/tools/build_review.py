#!/usr/bin/env python3
"""Build a local art review gallery; current acceptance comes from STATUS.json."""
from pathlib import Path
from html import escape
from html.parser import HTMLParser
import json,hashlib,argparse
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent.parent
ROLES=[("guard_monk","护寺棍僧","右上出棍"),("wild_hunter","山野猎户","拉弓放箭"),("foxfire_imp","狐火小妖","双掌交替火攻"),("sparrow_spirit","山雀精","挥翼风刃"),("mountain_wolf","山狼","前探咬合"),("boar","山猪","单手挥锤"),("gray_rat","灰鼠","投石与收索"),("bear_lord","熊山君","双手重棍"),("herbal_spirit_child","药灵童子","治疗施放")]
CSS="""*{box-sizing:border-box}body{margin:0;background:#141a22;color:#f4ead6;font:16px -apple-system,BlinkMacSystemFont,sans-serif}header{padding:32px 5vw;border-bottom:1px solid #4a4a43}h1{margin:0 0 12px;font-size:30px}p{line-height:1.65;color:#c6c4bb}nav{display:flex;flex-wrap:wrap;gap:10px;margin:18px 0}a{color:#efcf81;text-underline-offset:4px}nav a,button{border:1px solid #756343;border-radius:8px;background:#262a2c;color:#eedcaa;padding:9px 13px;cursor:pointer;font:inherit}main{max-width:1500px;margin:auto;padding:20px}.role{padding:20px;margin:18px 0;border:1px solid #4b4943;border-radius:14px;background:#1d242c}h2{margin:0 0 8px;font-size:25px}.meta{color:#b9bbb9;font-size:14px}.preview{display:grid;grid-template-columns:repeat(2,minmax(0,448px));gap:18px;margin:18px 0}.preview img,.frame img{display:block;width:100%;height:auto;image-rendering:pixelated;background:#232830}.preview figure{margin:0}.preview figcaption{padding:8px 0;color:#d4c8aa}.frames{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px;margin:18px 0}.frame{margin:0;border:1px solid #4a4a44;border-radius:7px;overflow:hidden}.frame figcaption{padding:8px;color:#c7c2b4;font-size:13px}details{border-top:1px solid #41474a;padding-top:15px;margin-top:16px}summary{cursor:pointer;color:#e6cc93;font-size:18px}.light .frame img{background:repeating-conic-gradient(#eee 0% 25%,#ccc 0% 50%) 50%/20px 20px}.note{font-size:14px;color:#aab4b7}footer{padding:25px;text-align:center;color:#9da8ae}@media(max-width:700px){.preview{grid-template-columns:1fr}header{padding:25px 20px}.role{padding:14px}.frames{grid-template-columns:repeat(2,minmax(0,1fr))}}"""
def filehash(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def gifinfo(p):
    im=Image.open(p);duration=0
    for i in range(im.n_frames):im.seek(i);im.load();duration+=im.info.get("duration",0)
    return {"frames":im.n_frames,"total_ms":duration,"sha256":filehash(p)}
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--font",help="Installed Chinese-capable font path for the overview PNG")
    parser.add_argument("--skip-overview",action="store_true",help="Keep the saved overview image unchanged when correcting review status")
    args=parser.parse_args()
    candidates=[args.font] if args.font else ["/System/Library/Fonts/STHeiti Medium.ttc","C:/Windows/Fonts/msyh.ttc","/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc","/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"]
    font_path=next((Path(x) for x in candidates if x and Path(x).is_file()),None)
    if font_path is None:raise SystemExit("Pass --font with an installed Chinese-capable TTF/TTC/OTF font; no font is downloaded automatically")
    status=json.loads((ROOT/"STATUS.json").read_text());byid={x["id"]:x for x in status["roles"]}
    cards=[];nav=[];report=[];sheet=Image.new("RGB",(1344,1488),(35,40,48))
    small_path=font_path.with_name("STHeiti Light.ttc") if font_path.name=="STHeiti Medium.ttc" else font_path
    if not small_path.is_file():small_path=font_path
    font=ImageFont.truetype(str(font_path),25);small=ImageFont.truetype(str(small_path),16)
    pick={"guard_monk":5,"wild_hunter":2,"foxfire_imp":8,"sparrow_spirit":4,"mountain_wolf":3,"boar":4,"gray_rat":5,"bear_lord":4,"herbal_spirit_child":3}
    for index,(role,title,action) in enumerate(ROLES):
        folder=ROOT.parent/"guard_monk_pixel_attack_v5" if role=="guard_monk" else ROOT/role
        prefix="../guard_monk_pixel_attack_v5" if role=="guard_monk" else role
        m=json.loads((folder/"manifest.json").read_text())
        if role=="guard_monk":
            frames=m["stages"];times=[round(x["at"]*1000) for x in frames];nbody=len(m["used_body_ids"])
        else:
            frames=m["renders"];times=[x["at_ms"] for x in frames];nbody=len(m["bodies"])
        framecards=[]
        for i,(record,at) in enumerate(zip(frames,times)):
            src=folder/record["file"];assert src.is_file(),src
            Image.open(src).load()
            framecards.append(f'<figure class="frame"><a href="{escape(prefix+"/"+record["file"])}" target="_blank"><img loading="lazy" src="{escape(prefix+"/"+record["file"])}" alt="{title} 第{i+1}帧"></a><figcaption>第{i+1}帧 · {at}毫秒</figcaption></figure>')
        normal=gifinfo(folder/"preview.gif");slow=gifinfo(folder/"preview_slow.gif")
        action_ms=round(m["action_duration_seconds"]*1000) if role=="guard_monk" else m["duration_ms"]
        idle=round(m["preview_cycle_seconds"]*1000)-action_ms if role=="guard_monk" else m["idle_ms"]
        assert normal["total_ms"]==action_ms+idle and slow["total_ms"]==2*action_ms+idle
        gate={"candidate_pass":"候选复核通过","needs_viewpoint_rework":"视角不符 · 待返工","needs_viewpoint_review":"斜向棋盘适配 · 待复核"}.get(byid[role]["status"],"最终复核中")
        cards.append(f'<section class="role" id="{role}"><h2>{title} · {action}</h2><div class="meta">{gate} · {nbody}个身体姿势 · {len(frames)}个显示阶段</div><div class="preview"><figure><img loading="lazy" src="{prefix}/preview.gif" alt="{title}正常动画"><figcaption>正常 · {normal["total_ms"]/1000:g}秒</figcaption></figure><figure><img loading="lazy" src="{prefix}/preview_slow.gif" alt="{title}半速动画"><figcaption>半速 · {slow["total_ms"]/1000:g}秒</figcaption></figure></div><p><a href="{prefix}/contact_sheet.png" target="_blank">整套逐帧图</a>　<a href="{prefix}/REVIEW.md">逐帧检查记录</a>　<a href="{prefix}/README.md">素材说明</a></p><details><summary>展开全部{len(frames)}个显示帧</summary><p class="note">按播放顺序排列；点击图片查看原图。相同身体可因残影或弹体位置不同而显示多次。</p><div class="frames">{"".join(framecards)}</div></details></section>')
        nav.append(f'<a href="#{role}">{title}</a>')
        record=frames[min(pick[role],len(frames)-1)];im=Image.open(folder/record["file"]).convert("RGBA")
        x=(index%3)*448;y=(index//3)*496;sheet.paste(Image.alpha_composite(Image.new("RGBA",(448,448),(35,40,48,255)),im).convert("RGB"),(x,y+48))
        dr=ImageDraw.Draw(sheet);dr.text((x+20,y+5),title+" · "+action,fill=(238,219,172),font=font);dr.text((x+20,y+33),f"{nbody} 姿势 / {len(frames)} 阶段",fill=(169,180,185),font=small)
        report.append({"id":role,"title":title,"action":action,"status":byid[role]["status"],"body_count":nbody,"stage_count":len(frames),"folder":prefix,"normal":normal,"slow":slow,"all_stage_files_exist_and_decode":True})
    correction='<p role="alert" style="padding:16px;border:2px solid #dd995a;background:#35281f;color:#ffe3bf"><strong>当前斜向棋盘用途未通过 · 旧通过结论已撤回</strong><br>本批其他八角色沿用了旧造型／动作视角，遗漏最新斜俯视方向要求，待返工；棍僧须核对当前棋盘适配。以下为旧稿和历史局部检查，图片尚未返工。<br><a href="README.md">查看方向依据与返工门槛</a></p>' if status["quality_gate"]=="reopened_viewpoint_baseline_mismatch" else ''
    html='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>像素主动作 · 逐帧审阅</title><style>'+CSS+'</style><header><h1>像素主动作 · 逐帧审阅</h1>'+correction+'<p>八套攻击 ＋ 药灵治疗。每套提供正常、半速和全部显示帧，逐帧记录可追溯。<br>当前状态见各角色标记；文件可播放不代表视觉或游戏用途通过。</p><button onclick="document.body.classList.toggle(\'light\')">切换单帧底色</button><nav>'+''.join(nav)+'</nav></header><main>'+''.join(cards)+'</main><footer>2026-10-26 · 05｜美术 / 角色 / UI</footer></html>'
    (ROOT/"review.html").write_text(html)
    if not args.skip_overview:sheet.save(ROOT/"overview.png",optimize=True)
    class References(HTMLParser):
        def __init__(self):super().__init__();self.files=[]
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ("href","src") and value and not value.startswith("#"):self.files.append(value)
    refs=References();refs.feed(html)
    for relative in refs.files:
        target=(ROOT/relative).resolve();assert target.is_relative_to(ROOT.parent) and target.is_file(),relative
    total={"updated":"2026-10-26","role_count":len(report),"body_count":sum(x["body_count"] for x in report),"stage_count":sum(x["stage_count"] for x in report),"all_declared_media_decode":True,"normal_and_slow_timing_matches_manifests":True,"local_html_file_reference_count":len(refs.files),"all_local_html_file_references_exist":True,"html_verification":"static references and media decode; browser interaction not verified (local file URL policy)","runtime_integrated":False,"roles":report}
    total["quality_gate"]=status["quality_gate"]
    total["current_board_use_approved"]=status.get("current_board_use_approved",False)
    total["media_integrity_is_not_visual_acceptance"]=True
    (ROOT/"delivery_audit.json").write_text(json.dumps(total,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({k:v for k,v in total.items() if k!="roles"},ensure_ascii=False))
if __name__=="__main__":main()
