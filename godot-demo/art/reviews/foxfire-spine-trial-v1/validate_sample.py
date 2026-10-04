"""Structural and geometric input checks, not native Spine validation."""
import json, hashlib, math
from pathlib import Path
from PIL import Image
from build_sample import ROOT, pose, multiply, sample, DURATIONS, FEET

data=json.loads((ROOT/"foxfire-external-4.3.json").read_text())
layout=json.loads((ROOT/"parts-layout.json").read_text())
checks=[];metrics={}
def check(name,condition):
    checks.append({"check":name,"passed":bool(condition)})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
# reviews/<sample> -> art -> production
original=ROOT.parent.parent/"production/foxfire_imp/nine_sols_v1/source-clean.png"
check("source unchanged and identical to approved runtime input",
      sha(original)==sha(ROOT/"source/original.png")=="873e97b812f7363449efc7981323a7046f5d75ee40dca3d58376ec79b12ff6ae")
check("candidate excluded from Godot import",(ROOT/".gdignore").exists())
seen=set()
for b in data["bones"]:
    check("unique parent-first bone "+b["name"],b["name"] not in seen and ("parent" not in b or b["parent"] in seen))
    seen.add(b["name"])
slots={s["name"]:s for s in data["slots"]}
check("unique slot names",len(slots)==len(data["slots"]))
for s in slots.values():
    check("slot bone exists "+s["name"],s["bone"] in seen)
for name,rec in layout.items():
    im=Image.open(ROOT/f"images/{name}.png")
    source=Image.open(ROOT/rec["source_file"]).convert("RGBA")
    check("lossless rectangular extraction "+name,im.tobytes()==source.crop(rec["source_box"]).tobytes())
    box=im.getchannel("A").point(lambda v:255 if v>=8 else 0).getbbox()
    check("transparent margin and opaque content "+name,im.mode=="RGBA" and box and
          box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height)
for skin in data["skins"]:
    for sn,attachments in skin["attachments"].items():
        check("skin slot exists "+sn,sn in slots)
        for name,a in attachments.items():
            check("relative image resolves "+sn,not Path(a["path"]).is_absolute() and (ROOT/"images"/(a["path"]+".png")).exists())
            check("positive attachment dimensions "+sn,a["width"]>0 and a["height"]>0)
for anim,clip in data["animations"].items():
    for typ in ["bones","slots"]:
        for name,tracks in clip.get(typ,{}).items():
            check("animation target exists "+anim+"/"+name,name in (seen if typ=="bones" else slots))
            for track,keys in tracks.items():
                times=[k.get("time",0) for k in keys]
                check("ordered finite keys "+anim+"/"+name+"/"+track,
                      times==sorted(set(times)) and all(math.isfinite(t) and 0<=t<=DURATIONS[anim] for t in times))
                if track in ["rotate","alpha"]:
                    check("4.3 scalar value field "+anim+"/"+name+"/"+track,all("value" in k and "angle" not in k for k in keys))
    start,end=pose(data,anim,0),pose(data,anim,DURATIONS[anim])
    err=max(abs(a-b) for name in seen for a,b in zip(start[name],end[name]))
    metrics[anim+"_endpoint_matrix_error"]=err
    check("loop or return-to-start pose "+anim,err<.001)
check("exactly three requested animations",set(data["animations"])=={"idle","basic_attack","move"})
events=data["animations"]["basic_attack"]["events"]
check("single visual release marker",len(events)==1 and events[0]["name"]=="release" and events[0]["time"]==.48)
release=pose(data,"basic_attack",.48)
err=max(abs(a-b) for a,b in zip(release["flame"],release["projectile"]))
metrics["release_world_matrix_error"]=err
check("projectile begins at palm flame transform",err<.001)
# Numerical ground contacts, with proposed -220 px/s forward displacement.
# This is NOT a visual gait pass or validation against actual game movement.
for name,phase,start,end in [("leg_back",0,0,.5),("leg_front",.5,.5,1)]:
    px,py=layout[name]["pivot"];fx,fy=FEET[name]
    values=[]
    for i in range(51):
        t=start+(end-start)*i/50
        m=pose(data,"move",t)[name]
        p=multiply(m,[1,0,0,1,fx-px,py-fy])
        # endpoint wraps mathematically; omit transition instant.
        if i<50:values.append([p[4]-220*t,p[5]])
    spread=[max(p[j] for p in values)-min(p[j] for p in values) for j in [0,1]]
    metrics[name+"_stance_world_spread_px"]=spread
    check("proposed stance contact stable "+name,max(spread)<.01)
    idle0=pose(data,"idle",0)[name]
    check("idle feet stationary "+name,all(pose(data,"idle",i/20)[name]==idle0 for i in range(41)))
for name in ["idle","move","basic_attack"]:
    im=Image.open(ROOT/f"external-{name}.gif")
    total=0
    for i in range(im.n_frames):
        im.seek(i);total+=im.info.get("duration",0)
    metrics[name+"_gif_frames"]=im.n_frames
    metrics[name+"_gif_duration_ms"]=total
    check("preview decodes and duration matches "+name,total==round(DURATIONS[name]*1000))
report={"status":"passed" if all(c["passed"] for c in checks) else "failed",
        "scope":"External input structural/geometric QA only. NOT native Spine or visual acceptance.",
        "native_spine_import_verified":False,"native_spine_playback_verified":False,
        "checks":checks,"metrics":metrics}
(ROOT/"validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(report["status"],len(checks),"checks")
for c in checks:
    if not c["passed"]:print("FAIL",c["check"])
raise SystemExit(0 if report["status"]=="passed" else 1)
