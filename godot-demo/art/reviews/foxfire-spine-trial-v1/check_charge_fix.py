"""Exact-time charge review and alpha-silhouette clearance, external QA only."""
import copy, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from build_sample import ROOT, render, pose

FOLDER=ROOT/"qa-charge-fix"
before=json.loads((FOLDER/"before-input.json").read_text())
after=json.loads((ROOT/"foxfire-external-4.3.json").read_text())
comparison=copy.deepcopy(after)
del comparison["animations"]["basic_attack"]["bones"]["flame"]["rotate"]
assert comparison==before, "Scope expanded beyond the single flame rotation track"
assert pose(before,"basic_attack",.48)==pose(after,"basic_attack",.48)
assert pose(before,"basic_attack",0)==pose(after,"basic_attack",0)
assert pose(before,"basic_attack",1.4)==pose(after,"basic_attack",1.4)

def clearance(data,t,scale):
    masks=[]
    for slot in ["head","flame"]:
        alpha=render(data,"basic_attack",t,scale,only_slots={slot}).getchannel("A")
        mask=alpha.point(lambda a:255 if a>=8 else 0)
        eroded=mask.filter(ImageFilter.MinFilter(3))
        pixels=np.asarray(mask)>0
        edge=pixels & ~(np.asarray(eroded)>0)
        masks.append((pixels,np.column_stack(np.nonzero(edge))))
    overlap=int(np.count_nonzero(masks[0][0]&masks[1][0]))
    a,b=masks[0][1],masks[1][1]
    best=float("inf");closest=None
    for start in range(0,len(a),128):
        chunk=a[start:start+128]
        diff=chunk[:,None,:].astype(float)-b[None,:,:]
        sq=np.sum(diff*diff,axis=2)
        index=np.unravel_index(np.argmin(sq),sq.shape)
        if sq[index]<best:
            best=float(sq[index]);closest=[chunk[index[0]].tolist(),b[index[1]].tolist()]
    return {"overlap_pixels":overlap,"nearest_opaque_pixel_center_distance":round(math.sqrt(best),4),
            "nearest_points_yx":closest,"scale":scale,"alpha_threshold":8}

results={}
font=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf",19)
smallfont=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf",15)
sheet=Image.new("RGB",(1440,1110),"#dfd8c8")
draw=ImageDraw.Draw(sheet)
draw.text((20,12),"EXTERNAL INPUT COMPARISON / NOT SPINE CAPTURE",fill="#813b27",font=font)
for row,t in enumerate([.28,.30]):
    results[str(t)]={}
    for col,(label,data) in enumerate([("BEFORE e4e0d6d",before),("AFTER charge fix",after)]):
        normal=clearance(data,t,1)
        game=clearance(data,t,.085)
        results[str(t)][label]={"source_scale":normal,"game_scale":game}
        x,y=col*720,row*530+55
        draw.text((x+16,y),f"{label} | {t:.2f}s",fill="#332b23",font=font)
        large=render(data,"basic_attack",t,.4).crop((125,0,475,340)).resize((490,476),Image.Resampling.LANCZOS)
        sheet.paste(large,(x+8,y+30),large)
        im=render(data,"basic_attack",t,.085)
        tile=Image.new("RGB",(200,200),"#34332d")
        tile.paste(im,(20,50),im)
        sheet.paste(tile,(x+506,y+80))
        draw.text((x+507,y+285),"Runtime scale 0.085",fill="#332b23",font=smallfont)
        draw.text((x+507,y+313),f"Min distance: {game['nearest_opaque_pixel_center_distance']:.2f}px",fill="#332b23",font=smallfont)
        draw.text((x+507,y+337),f"Overlap: {game['overlap_pixels']}px",fill="#332b23",font=smallfont)
        assert game["overlap_pixels"]==0 or col==0
        if col==1:
            assert game["nearest_opaque_pixel_center_distance"]>=2
            assert normal["nearest_opaque_pixel_center_distance"]>results[str(t)]["BEFORE e4e0d6d"]["source_scale"]["nearest_opaque_pixel_center_distance"]
sheet.save(FOLDER/"before-after-028-030.png")
# The full charge/uncurl interval: screen-space clearance must remain visible.
sweep=[]
for i in range(10,24):
    t=i/50
    info=clearance(after,t,.085)
    sweep.append({"time":t,**info})
assert all(x["overlap_pixels"]==0 and x["nearest_opaque_pixel_center_distance"]>=2 for x in sweep)
report={
    "status":"passed",
    "scope":"External rendered alpha silhouettes only; not native Spine or 05 acceptance.",
    "change":"Only basic_attack/flame/rotate: 0 at start, +24deg at .30s, 0 at .48s and end",
    "semantic_rest_unchanged":True,
    "exact_release_pose_unchanged":True,
    "exact_start_end_unchanged":True,
    "measurement":"Euclidean distance between alpha>=8 pixel centers. Distance 1 means adjacent opaque pixels, not a full transparent pixel. Background/visual glow below alpha 8 is not measured.",
    "times":results,"game_scale_sweep":sweep,
    "walk_rigidity_and_idle_move_transition_fixed":False,
    "native_spine_verified":False}
(FOLDER/"clearance.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
for time,variants in results.items():
    print(time,{name:[value["source_scale"]["nearest_opaque_pixel_center_distance"],value["game_scale"]["nearest_opaque_pixel_center_distance"]] for name,value in variants.items()})
print("PASS: only intended rotation changed; source/game-scale clearance; release/start/end unchanged.")
