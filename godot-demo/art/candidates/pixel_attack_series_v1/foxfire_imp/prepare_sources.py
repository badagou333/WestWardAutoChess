#!/usr/bin/env python3
"""Register illustrated poses; second cast uses the actual other raised hand."""
from pathlib import Path
import importlib.util,json
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent
ss=importlib.util.spec_from_file_location("attack_builder",ROOT.parent/"tools/build_attack.py")
b=importlib.util.module_from_spec(ss);ss.loader.exec_module(b)
BOXES=[[40,40,410,414],[465,40,824,414],[865,40,1235,414],[40,440,414,824],[465,440,824,824],[865,440,1235,824],[40,840,414,1225]]
ANCHORS=[[140,397],[558,396],[952,396],[143,803],[559,804],[933,804],[146.5,1183]]
def main():
    raw=Image.open(ROOT/"source/attack_sheet.webp").convert("RGBA")
    images=[]
    for box,anchor in zip(BOXES,ANCHORS):
        im,_=b.extract(raw,{"source_box":box,"source_anchor":anchor},1.0,(448,448),(125,399))
        images.append(im)
    hand=Image.open(ROOT/"source/far_hand_flick.webp").convert("RGBA").resize((85,115),Image.Resampling.NEAREST)
    patch=Image.new("RGBA",(448,448));patch.alpha_composite(hand,(65,85))
    mask=Image.new("L",(448,448));ImageDraw.Draw(mask).polygon([(65,85),(150,85),(150,177),(139,191),(94,195),(65,180)],fill=255)
    m=np.array(mask)>0;base=images[4];a=np.array(base).copy();z=np.array(patch);a[m]=z[m]
    a[:,:,3]=np.where(a[:,:,3]>=128,255,0);a[a[:,:,3]==0]=0
    assert np.array_equal(a[~m],np.array(base)[~m])
    release=Image.fromarray(a);mask.save(ROOT/"source/far_hand_mask.png")
    adopted=[("00_ready",images[3]),("01_left_load",images[1]),("02_left_release",images[2]),("04_right_load",images[4]),("05_right_release",release),("06_right_recover",images[6])]
    sheet=Image.new("RGBA",(448*3,448*2));bodies=[]
    for i,(label,im) in enumerate(adopted):
        x=(i%3)*448;y=(i//3)*448;sheet.alpha_composite(im,(x,y))
        bodies.append({"id":label,"name":label[3:],"source":"registered","source_box":[x,y,x+448,y+448],"source_anchor":[x+125,y+399]})
    out=ROOT/"source/registered_poses.webp";sheet.save(out,lossless=True,quality=100,method=6,exact=True)
    assert sheet.tobytes()==Image.open(out).convert("RGBA").tobytes()
    bolt=raw.crop((925,888,1210,1020))
    placements=[("left_start",(335,180),(108,50)),("left_out",(390,180),(108,50)),("right_start",(95,105),(72,33)),("right_arc",(205,35),(72,33)),("right_out",(345,35),(72,33)),("right_exit",(430,35),(72,33))]
    for name,pos,size in placements:
        fx=Image.new("RGBA",(448,448));fx.alpha_composite(bolt.resize(size,Image.Resampling.NEAREST),pos);fx.save(ROOT/"source"/f"{name}.png")
    track=[{"at_ms":0,"body":"00_ready"},{"at_ms":160,"body":"01_left_load"},{"at_ms":300,"body":"02_left_release","layers":[{"id":"left_start","opacity":1}]},{"at_ms":360,"body":"02_left_release","layers":[{"id":"left_out","opacity":.85}]},{"at_ms":420,"body":"02_left_release"},{"at_ms":500,"body":"00_ready"},{"at_ms":650,"body":"04_right_load"},{"at_ms":850,"body":"05_right_release","layers":[{"id":"right_start","opacity":1}]},{"at_ms":880,"body":"05_right_release","layers":[{"id":"right_arc","opacity":1}]},{"at_ms":910,"body":"05_right_release","layers":[{"id":"right_out","opacity":.9}]},{"at_ms":940,"body":"05_right_release","layers":[{"id":"right_exit","opacity":.65}]},{"at_ms":970,"body":"05_right_release"},{"at_ms":1050,"body":"06_right_recover"},{"at_ms":1200,"body":"00_ready"}]
    spec={"character":"foxfire_imp","display_name":"狐火小妖 / alternating palm fire","canvas":[448,448],"anchor":[125,399],"palette_colors":96,"sources":{"registered":{"file":"source/registered_poses.webp","scale":1.0,"expected_pixel_sha256":b.pixel_hash(sheet)}},"bodies":bodies,"layers":{name:{"file":f"source/{name}.png"} for name,_,_ in placements},"track":track,"events":[{"name":"left_fire_release","at_ms":300},{"name":"right_fire_release","at_ms":850}],"duration_ms":1400,"idle_ms":350}
    (ROOT/"spec.json").write_text(json.dumps(spec,ensure_ascii=False,indent=2)+"\n")
    report={"body":"05_right_release","base":"original right-load pose4","mask_bbox":list(mask.getbbox()),"changed_pixels_before_palette":int(np.any(a!=np.array(base),axis=2).sum()),"outside_mask_raw_rgba_equal":True,"retained_fire_hand_and_sleeve_raw_rgba_exact":True,"no_hand_mirroring":True,"registered_rgba_sha256":b.pixel_hash(sheet),"not_adopted":["narrow ready cell0","same-arm release cell5","old stepping variants","full-arm redrawing attempts"],"final_motion":"screen-left raised palm wrist flick; screen-right palm retains its flame; planted stance"}
    (ROOT/"source/preparation_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(report,ensure_ascii=False))
if __name__=="__main__":main()
