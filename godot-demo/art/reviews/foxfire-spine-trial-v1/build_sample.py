"""Extract generated parts without repainting; author external Spine 4.3 input.

Requires Pillow. No Spine runtime, editor automation, save/export workaround,
or game assets are used. Preview transforms are an independent QA aid.
"""
from pathlib import Path
import json, math, hashlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
def write(name, data):
    (ROOT/name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n")

# Explicit inspected regions, not a uniform grid. Crop preserves generated RGBA.
# target = x,y,width,height in the reference's 1199 x 1312 coordinate space.
PARTS = {
 "head": ([50,0,410,415], [390,5,345,480], [520,450]),
 "torso": ([440,0,820,415], [265,435,515,655], [520,760]),
 "tail": ([860,0,1254,415], [676,650,435,565], [718,755]),
 "arm_cast": ([80,418,390,715], [225,563,275,333], [458,598]),
 "hand_cast": ([500,470,740,655], [166,499,144,122], [292,592]),
 "arm_rest": ([930,418,1230,711], [570,525,225,393], [615,563]),
 "hand_rest": ([125,750,285,952], [642,782,76,126], [678,808]),
 "leg_back": ([480,706,735,977], [350,930,200,296], [485,945]),
 "leg_front": ([910,710,1150,977], [545,929,160,326], [605,945]),
 "scarf": ([20,980,430,1254], [650,535,246,198], [664,548]),
 "flame": ([515,975,730,1254], [176,141,160,363], [252,504]),
}
def extract():
    sheet = Image.open(ROOT/"source/parts-sheet.png").convert("RGBA")
    records = {}
    for name, (box, target, pivot) in PARTS.items():
        part = (Image.open(ROOT/"source/torso-corrected.png").convert("RGBA")
                if name == "torso" else sheet.crop(box))
        bounds = part.getchannel("A").point(lambda a: 255 if a >= 8 else 0).getbbox()
        assert bounds, name
        # Preserve transparent fringe; no masks or color cleanup.
        bounds = [max(0,bounds[0]-3),max(0,bounds[1]-3),
                  min(part.width,bounds[2]+3),min(part.height,bounds[3]+3)]
        part = part.crop(bounds)
        part.save(ROOT/f"images/{name}.png")
        records[name] = {"source_file":"source/torso-corrected.png" if name == "torso" else "source/parts-sheet.png",
                         "source_box":list(bounds) if name == "torso" else [box[0]+bounds[0],box[1]+bounds[1],
                                      box[0]+bounds[2],box[1]+bounds[3]],
                         "pixels":list(part.size),"target":target,"pivot":pivot}
    write("parts-layout.json", records)
    return records

ORDER = ["tail","scarf","leg_back","leg_front","arm_cast","hand_cast",
         "torso","arm_rest","hand_rest","head","flame"]
def reassemble(records):
    canvas = Image.new("RGBA", (1199,1312))
    for name in ORDER:
        x,y,w,h=records[name]["target"]
        part=Image.open(ROOT/f"images/{name}.png").resize((w,h),Image.Resampling.LANCZOS)
        canvas.alpha_composite(part,(x,y))
    canvas.save(ROOT/"reassembled.png")
    # Inspection backgrounds only; these are not new production artwork.
    result=Image.new("RGB",(1600,1000),"#e5decd")
    original=Image.open(ROOT/"source/original.png")
    for i,im in enumerate([original,canvas]):
        small=im.copy();small.thumbnail((700,920))
        result.paste(small,(i*800+60,40),small)
    result.save(ROOT/"qa-reassembly.png")

PARENTS = {"torso":"root","head":"torso","tail":"torso","scarf":"torso",
           "arm_cast":"torso","hand_cast":"arm_cast","arm_rest":"torso",
           "hand_rest":"arm_rest","leg_back":"root","leg_front":"root",
           "flame":"hand_cast","projectile":"root"}
DURATIONS={"idle":2.0,"basic_attack":1.4,"move":1.0}
FEET={"leg_back":[420,1226],"leg_front":[640,1255]}
def key1(values):
    return [{"time":t,"value":v} for t,v in values]
def key2(values):
    return [{"time":t,"x":x,"y":y} for t,x,y in values]
def bone_keys(rot=None, trans=None, scale=None):
    result={}
    if rot is not None: result["rotate"]=key1(rot)
    if trans is not None: result["translate"]=key2(trans)
    if scale is not None: result["scale"]=key2(scale)
    return result

def make_input(records):
    pivots={name:rec["pivot"] for name,rec in records.items()}
    pivots["root"]=[610,1255]
    pivots["projectile"]=pivots["flame"]
    bones=[{"name":"root"}]
    for name,parent in PARENTS.items():
        px,py=pivots[name];qx,qy=pivots[parent]
        bones.append({"name":name,"parent":parent,"x":px-qx,"y":qy-py,
                      "length":60,"color":"df9c4bff"})
    slots=[]; attachments={}
    for name in ORDER+["projectile"]:
        part="flame" if name=="projectile" else name
        x,y,w,h=records[part]["target"];px,py=pivots[name]
        iw,ih=records[part]["pixels"]
        slots.append({"name":name,"bone":name,"attachment":part,
                      "color":"ffffff00" if name=="projectile" else "ffffffff"})
        attachments[name]={part:{"type":"region","path":part,
                                "x":x+w/2-px,"y":py-y-h/2,
                                # Editor uses the loaded PNG dimensions. Keep
                                # those dimensions and express size via SRT.
                                "width":iw,"height":ih,"scaleX":w/iw,"scaleY":h/ih}}
    idle={"bones":{
        "torso":bone_keys(trans=[(0,0,0),(.5,0,3),(1,0,0),(1.5,0,-2),(2,0,0)]),
        "head":bone_keys(rot=[(0,0),(.6,-1),(1.3,.6),(2,0)]),
        "tail":bone_keys(rot=[(0,0),(.7,2),(1.4,-1),(2,0)]),
        "scarf":bone_keys(rot=[(0,0),(.4,-2),(1.3,2),(2,0)]),
        "hand_cast":bone_keys(rot=[(0,0),(1,2),(2,0)]),
        "flame":bone_keys(scale=[(0,1,1),(.4,.97,1.03),(.9,1.03,.98),(1.5,.98,1.02),(2,1,1)])
    }}
    attack={"bones":{
        "torso":bone_keys(rot=[(0,0),(.3,-3),(.48,2),(.65,1),(1.4,0)],
                          trans=[(0,0,0),(.3,12,-7),(.48,-15,3),(.7,-5,0),(1.4,0,0)]),
        "head":bone_keys(rot=[(0,0),(.3,3),(.48,-3),(1.4,0)]),
        "arm_cast":bone_keys(rot=[(0,0),(.3,-13),(.48,8),(.65,8),(1.4,0)]),
        "hand_cast":bone_keys(rot=[(0,0),(.3,-8),(.48,7),(.65,7),(1.4,0)]),
        "arm_rest":bone_keys(rot=[(0,0),(.3,-2),(.5,5),(1.4,0)]),
        "tail":bone_keys(rot=[(0,0),(.35,-3),(.65,4),(1.4,0)]),
        "scarf":bone_keys(rot=[(0,0),(.3,-4),(.55,7),(.85,-2),(1.4,0)]),
        # Counter the -24 degree combined torso/arm/hand charge tilt so the
        # flame grows upright away from the ear. Back to zero at release.
        "flame":bone_keys(rot=[(0,0),(.3,24),(.48,0),(1.4,0)],
                          scale=[(0,1,1),(.3,.7,.8),(.48,1.18,1.18),(1.15,1,1),(1.4,1,1)])
    },"slots":{"flame":{"alpha":key1([(0,1),(.479,1),(.48,0),(1.05,0),(1.25,1),(1.4,1)])},
                "projectile":{"alpha":key1([(0,0),(.479,0),(.48,1),(.8,1),(.95,0),(1.4,0)])}},
       "events":[{"time":.48,"name":"release","string":"preview only; no gameplay damage"}]}
    move={"bones":{}}
    for name,offset in [("leg_back",0),("leg_front",.5)]:
        rot=[];trans=[]
        px,py=pivots[name];fx,fy=FEET[name];dx,dy=fx-px,py-fy
        for i in range(41):
            t=i/40;p=(t+offset)%1
            if p<=.5:
                x=-55+220*p;y=0;r=0
            else:
                u=(p-.5)*2
                x=55-110*u;y=42*math.sin(math.pi*u);r=6*math.sin(math.pi*u)
            a=math.radians(r);rx=math.cos(a)*dx-math.sin(a)*dy;ry=math.sin(a)*dx+math.cos(a)*dy
            rot.append((t,round(r,5)))
            trans.append((t,round(x+dx-rx,5),round(y+dy-ry,5)))
        move["bones"][name]=bone_keys(rot=rot,trans=trans)
    move["bones"].update({
        "torso":bone_keys(trans=[(0,0,0),(.25,0,8),(.5,0,0),(.75,0,8),(1,0,0)]),
        "head":bone_keys(rot=[(0,0),(.25,1),(.5,0),(.75,1),(1,0)]),
        "arm_cast":bone_keys(rot=[(0,0),(.25,-3),(.5,0),(.75,3),(1,0)]),
        "arm_rest":bone_keys(rot=[(0,0),(.25,5),(.5,0),(.75,-5),(1,0)]),
        "tail":bone_keys(rot=[(0,0),(.25,3),(.5,0),(.75,-3),(1,0)]),
        "scarf":bone_keys(rot=[(0,0),(.25,-4),(.5,0),(.75,4),(1,0)]),
        "flame":bone_keys(scale=[(0,1,1),(.25,.98,1.02),(.5,1,1),(.75,1.02,.98),(1,1,1)])
    })
    data={"skeleton":{"spine":"4.3.26","x":-610,"y":-57,"width":1199,"height":1312,
                      "fps":30,"images":"./images/"},
          "bones":bones,"slots":slots,"skins":[{"name":"default","attachments":attachments}],
          "events":{"release":{"string":"visual timing marker only"}},
          "animations":{"idle":idle,"basic_attack":attack,"move":move}}
    # Released fire starts at its actual animated palm location, then travels left.
    mat=pose(data,"basic_attack",.48)["flame"]
    sx,sy=mat[4],mat[5]
    proj=next(b for b in bones if b["name"]=="projectile")
    bx,by=proj["x"],proj["y"]
    attack["bones"]["projectile"]=bone_keys(
        rot=[(0,0),(.48,math.degrees(math.atan2(mat[1],mat[0]))),
             (.95,math.degrees(math.atan2(mat[1],mat[0]))),(1.4,0)],
        trans=[(0,0,0),(.479,sx-bx,sy-by),(.48,sx-bx,sy-by),
               (.95,sx-bx-380,sy-by+35),(1.4,0,0)],
        scale=[(0,1,1),(.48,1.18,1.18),(.95,.85,.85),(1.4,1,1)])
    write("foxfire-external-4.3.json",data)
    write("animation-notes.json",{
        "origin":"External authored input, NOT saved/exported by Spine Trial",
        "native_verification_record":"NATIVE_ALIGNMENT_20261007.md",
        "durations_seconds":DURATIONS,"loop":["idle","move"],"single_play":["basic_attack"],
        "release_time":.48,"root_motion":"in-place; engine displacement NOT in input",
        "move_reference_speed_source_px_per_second":220,
        "feet_reference_source_pixels":FEET,
        "warning":"Timing is a standalone visual proposal, not game attack speed/damage.",
        "reference_runtime_scale":.085})
    return data

def sample(keys,t,prop,default=0):
    if not keys:return default
    if t<keys[0].get("time",0):return default
    for a,b in zip(keys,keys[1:]):
        ta,tb=a.get("time",0),b.get("time",0)
        if ta<=t<tb:
            v=a.get(prop,default);w=b.get(prop,default)
            return v if a.get("curve")=="stepped" else v+(w-v)*(t-ta)/(tb-ta)
    return keys[-1].get(prop,default)

def multiply(a,b):
    aa,ab,ac,ad,ax,ay=a;ba,bb,bc,bd,bx,by=b
    return [aa*ba+ac*bb,ab*ba+ad*bb,aa*bc+ac*bd,ab*bc+ad*bd,
            aa*bx+ac*by+ax,ab*bx+ad*by+ay]
def pose(data,anim,t):
    matrices={}
    timelines=data["animations"].get(anim,{}).get("bones",{})
    for b in data["bones"]:
        tracks=timelines.get(b["name"],{})
        r=math.radians(b.get("rotation",0)+sample(tracks.get("rotate"),t,"value"))
        x=b.get("x",0)+sample(tracks.get("translate"),t,"x")
        y=b.get("y",0)+sample(tracks.get("translate"),t,"y")
        sx=sample(tracks.get("scale"),t,"x",1);sy=sample(tracks.get("scale"),t,"y",1)
        mat=[math.cos(r)*sx,math.sin(r)*sx,-math.sin(r)*sy,math.cos(r)*sy,x,y]
        matrices[b["name"]]=multiply(matrices[b["parent"]],mat) if "parent" in b else mat
    return matrices

def render(data,anim,t,scale=.4,only_slots=None):
    # Independent, limited affine preview of this input. Not a Spine renderer.
    canvas=Image.new("RGBA",(round(1600*scale),round(1420*scale)))
    mats=pose(data,anim,t)
    skins=data["skins"][0]["attachments"]
    for slot in data["slots"]:
        if only_slots is not None and slot["name"] not in only_slots:continue
        name=slot["name"];part=slot["attachment"];att=skins[name][part]
        im=Image.open(ROOT/f"images/{part}.png").convert("RGBA")
        default=int(slot.get("color","ffffffff")[-2:],16)/255
        keys=data["animations"].get(anim,{}).get("slots",{}).get(name,{}).get("alpha")
        opacity=sample(keys,t,"value",default)
        if opacity<=0:continue
        # Image pixel coordinates -> attachment space -> bone -> preview pixels.
        w=att["width"]*att.get("scaleX",1);h=att["height"]*att.get("scaleY",1)
        local=[w/im.width,0,0,-h/im.height,
               att["x"]-w/2,att["y"]+h/2]
        m=multiply([scale,0,0,-scale,850*scale,1320*scale],multiply(mats[slot["bone"]],local))
        a,b,c,d,x,y=m;det=a*d-b*c
        inv=(d/det,-c/det,(c*y-d*x)/det,-b/det,a/det,(b*x-a*y)/det)
        warped=im.transform(canvas.size,Image.Transform.AFFINE,inv,Image.Resampling.BICUBIC)
        if opacity<1:warped.putalpha(warped.getchannel("A").point(lambda v:round(v*opacity)))
        canvas.alpha_composite(warped)
    return canvas

def make_previews(data):
    font=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf",16)
    contact=Image.new("RGB",(1440,3*430),"#e5decd")
    draw=ImageDraw.Draw(contact)
    for row,(anim,duration) in enumerate(DURATIONS.items()):
        # 5 useful exact poses; attack includes release and travel.
        times=[0,.3,.48,.72,1.4] if anim=="basic_attack" else [0,duration*.25,duration*.5,duration*.75,duration]
        for col,t in enumerate(times):
            im=render(data,anim,t,.18)
            contact.paste(im,(col*288,row*430+38),im)
            draw.text((col*288+12,row*430+10),f"{anim} {t:.2f}s",fill="#322b21",font=font)
        frames=[]
        for i in range(round(duration*25)):
            im=render(data,anim,i/25,.4)
            bg=Image.new("RGB",im.size,"#dfd8c8");bg.paste(im,(0,0),im)
            d=ImageDraw.Draw(bg)
            d.text((12,10),f"EXTERNAL INPUT PREVIEW / {anim}",fill="#332b23",font=font)
            d.text((12,32),"Not captured in Spine. Native QA: see report.",fill="#332b23",font=font)
            frames.append(bg)
        # GIF inspection copy; originals retain alpha. No Trial export involved.
        frames[0].save(ROOT/f"external-{anim}.gif",save_all=True,append_images=frames[1:],
                       duration=40,loop=0,disposal=2)
    draw.text((12,1240),"EXTERNAL INPUT CONTACT SHEET - NOT SPINE PLAYBACK",fill="#8b3b25",font=font)
    contact.save(ROOT/"qa-motion-contact.png")
    # Same source scale used by the existing runtime manifest: a 256px frame.
    small=Image.new("RGB",(3*256,256),"#34332d")
    for i,a in enumerate(DURATIONS):
        im=render(data,a,0 if a!="basic_attack" else .48,.085)
        small.paste(im,(i*256+56,106),im)
    small.save(ROOT/"qa-game-scale.png")

if __name__ == "__main__":
    records=extract()
    reassemble(records)
    data=make_input(records)
    make_previews(data)
    print("Extracted",len(records),"parts; wrote external input and QA previews.")
