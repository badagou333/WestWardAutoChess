#!/usr/bin/env python3
"""Assemble generated sling parts with explicit masks; never repaint anatomy.

All source bodies share .84 nearest sampling once. Weapon-only registration
uses generated cord pixels, leather cradle pixels and the generated one-stone
asset. The old malformed collect body is replaced by the clean ready body
plus the already generated empty catching paw; it remains an actual distinct
catch pose. Every source crop/mask and endpoint is recorded for review.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
SRC = ROOT / "source"
SCALE = .84
ANCHOR = (130, 400)
IDS = ["00_ready", "01_load_stone", "02_wind_back", "03_overhead",
       "04_release", "05_catch_end", "06_take_stone", "07_lift_stone"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_webp(image, path):
    image.save(path, lossless=True, exact=True, quality=100, method=6)
    assert np.array_equal(np.asarray(image), np.asarray(Image.open(path).convert("RGBA")))


def binary(image):
    a = np.asarray(image).copy()
    a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
    a[a[:, :, 3] == 0] = 0
    return Image.fromarray(a)


def polygon(points, size=(512, 512)):
    m = Image.new("L", size)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return np.asarray(m) > 0


def clear(image, mask):
    a = np.asarray(image).copy()
    a[mask] = 0
    return Image.fromarray(a)


def patch(image, donor, mask):
    a = np.asarray(image).copy()
    a[mask] = np.asarray(donor)[mask]
    return Image.fromarray(a)


def translate(image, xy):
    c = Image.new("RGBA", image.size)
    c.alpha_composite(image, xy)
    return c


def cord(image, p, q, source):
    """Sample a generated straight brown cord, preserving its painted width."""
    p = np.array(p, dtype=float)
    q = np.array(q, dtype=float)
    delta = q - p
    length = float(np.linalg.norm(delta))
    u = delta / length
    n = np.array([-u[1], u[0]])
    a = np.asarray(source)
    first = np.array([155., 125.])
    last = np.array([317., 70.])
    d = last - first
    su = d / np.linalg.norm(d)
    sn = np.array([-su[1], su[0]])
    yy, xx = np.indices((512, 512))
    dx = xx - p[0]
    dy = yy - p[1]
    along = dx * u[0] + dy * u[1]
    across = dx * n[0] + dy * n[1]
    posx = np.rint(first[0] + su[0] * along / length * np.linalg.norm(d) + sn[0] * across).astype(int)
    posy = np.rint(first[1] + su[1] * along / length * np.linalg.norm(d) + sn[1] * across).astype(int)
    valid = ((along >= -1) & (along <= length + 1) & (abs(across) <= 5)
             & (posx >= 0) & (posx < a.shape[1]) & (posy >= 0) & (posy < a.shape[0]))
    rgba = np.zeros((512, 512, 4), dtype=np.uint8)
    rgba[valid] = a[posy[valid], posx[valid]]
    image.alpha_composite(Image.fromarray(rgba))
    return {"p": p.tolist(), "q": q.tolist(), "chord_px_before_common_scale": length}


def cup_asset(sheet, stone):
    # Exact generated empty leather U, including both painted knots.
    cup = binary(sheet.crop((136, 201, 200, 262)))
    m = polygon([(7, 3), (20, 3), (23, 23), (43, 23), (44, 3),
                 (59, 3), (64, 37), (50, 60), (18, 61), (1, 40)], cup.size)
    cup = clear(cup, ~m)
    loaded = cup.copy()
    loaded.alpha_composite(stone, (21, 19))
    # Restore the generated front leather lip over the stone's lower edge.
    front = np.asarray(cup).copy()
    front[:35] = 0
    loaded.alpha_composite(Image.fromarray(front))
    return cup, loaded


def place_cup(image, asset, knots_mid, angle):
    """Rotate one generated cup about its two-knot midpoint (32,13)."""
    a = np.asarray(asset)
    yy, xx = np.indices((512, 512))
    rad = math.radians(angle)
    c, s = math.cos(rad), math.sin(rad)
    x, y = xx - knots_mid[0], yy - knots_mid[1]
    sx = np.rint(c*x + s*y + 32).astype(int)
    sy = np.rint(-s*x + c*y + 13).astype(int)
    valid = (sx >= 0) & (sx < a.shape[1]) & (sy >= 0) & (sy < a.shape[0])
    out = np.zeros((512, 512, 4), dtype=np.uint8)
    out[valid] = a[sy[valid], sx[valid]]
    image.alpha_composite(Image.fromarray(out))
    def rotate(point):
        dx, dy = point[0]-32, point[1]-13
        return (knots_mid[0]+c*dx-s*dy, knots_mid[1]+s*dx+c*dy)
    return rotate((15, 13)), rotate((52, 13))


def old_overhead_mask():
    m = Image.new("L", (512, 512)); d = ImageDraw.Draw(m)
    # The first narrow cord guides left faint detached source-edge pixels.
    # This bounded transparent weapon area clears the complete old radius.
    d.rectangle((150,75,345,132),fill=255)
    d.rectangle((284,80,343,135),fill=255)
    # The ear contour starts at row132. Restore it from the original body;
    # no generated face/ear replacement is introduced by this clean-up.
    a = np.asarray(m).copy(); a[132:,190:284] = 0
    return a > 0


def sole(image, front=False):
    a = np.asarray(image)[:, :, 3]
    # Disjoint foot windows; tails and weapons do not reach these low rows.
    x0, x1 = (235, 385) if front else (70, 215)
    yy, xx = np.where(a[375:445, x0:x1] > 0)
    bottom = 375 + int(yy.max())
    xs = np.where(a[bottom-2:bottom+1, x0:x1] > 0)[1]
    return (float(x0 + xs.mean()), bottom)


def register_front(image, dx, dy):
    old = np.asarray(image).copy(); out = old.copy()
    source = np.zeros((448, 448), bool)
    source[354:420, 235:355] = True
    out[source] = 0
    for y in range(354, 427):
        if y >= 387 + dy:
            sy = y-dy
        else:
            rate = dy/33
            sy = round((y + rate*354)/(1+rate))
        if not 0 <= sy < 448: continue
        f = max(0, min(1, (sy-354)/33))
        shift = round(dx*f)
        for x in range(210, 380):
            sx = x-shift
            if 0 <= sx < 448 and source[sy,sx] and old[sy,sx,3]:
                out[y,x] = old[sy,sx]
    out[out[:,:,3] == 0] = 0
    return Image.fromarray(out)


def main():
    sp = importlib.util.spec_from_file_location("engine", ROOT.parent/"tools/build_attack.py")
    eng = importlib.util.module_from_spec(sp); sp.loader.exec_module(eng)
    sheet = Image.open(SRC/"mechanics_sheet.webp").convert("RGBA")
    arr = np.asarray(sheet)
    layout = json.loads((SRC/"component_layout.json").read_text())
    base=[]; crop_records=[]
    for q in layout[:8]:
        sel,_,_=eng.component_union(arr[:,:,3]>=128,[q["seed"]])
        a=arr.copy();a[~sel]=0;a[sel,3]=255
        b=q["bbox"];crop=Image.fromarray(a).crop(b)
        off=[(512-crop.width)//2,(512-crop.height)//2]
        c=Image.new("RGBA",(512,512));c.alpha_composite(crop,off)
        base.append(c);crop_records.append({"index":q["index"],"complete_bbox":b,"seed":q["seed"],"paste":off})
    local_load=binary(Image.open(SRC/"load_local.webp").convert("RGBA").resize((512,512),Image.Resampling.NEAREST))
    local_release=binary(Image.open(SRC/"release_local.webp").convert("RGBA").resize((512,512),Image.Resampling.NEAREST))
    stone=binary(sheet.crop(layout[8]["bbox"])).resize((22,19),Image.Resampling.NEAREST)
    empty,loaded=cup_asset(sheet,stone)
    exact_webp(empty,SRC/"empty_cradle.webp");exact_webp(loaded,SRC/"loaded_cradle.webp")
    report={"source_scale_common":SCALE,"body_height_fitting":False,"upstream_complete_extraction":crop_records,"repairs":[],"cords":{}}
    bodies=[im.copy() for im in base]
    loadmask=polygon([(131,279),(230,271),(231,319),(220,354),(134,354)])
    bodies[1]=patch(base[1],local_load,loadmask)
    Image.fromarray((loadmask*255).astype('uint8')).save(SRC/"load_patch_mask.png")
    report["repairs"].append({"id":IDS[1],"donor":"load_local.webp at .4 to original512 input","mask":"source/load_patch_mask.png","outside_mask_rgba_preserved":True})
    # Back windup: clear only its isolated old weapon, keep raised paw/arm.
    backmask=polygon([(0,150),(162,141),(171,155),(143,191),(105,251),(21,263),(0,242)])
    bodies[2]=clear(base[2],backmask)
    ends=place_cup(bodies[2],loaded,(86,208),58)
    report["cords"][IDS[2]]=[cord(bodies[2],(168,146),ends[0],local_release),cord(bodies[2],(176,151),ends[1],local_release)]
    # The original exaggerated overhead radius is replaced by the same cup
    # and cord material at the standing sling's approximate physical radius.
    om=old_overhead_mask();bodies[3]=clear(base[3],om)
    ends=place_cup(bodies[3],loaded,(243,119),-102)
    report["cords"][IDS[3]]=[cord(bodies[3],(143,130),ends[0],local_release),cord(bodies[3],(146,135),ends[1],local_release)]
    # Release is derived from the same overhead body; only generated wrist
    # and independently generated empty/open weapon are substituted.
    bodies[4]=clear(base[3],om)
    bodies[4]=clear(bodies[4],polygon([(157,131),(178,131),(178,141),(157,141)]))
    handmask=polygon([(103,129),(119,120),(149,121),(160,131),(159,151),(145,166),(106,164)])
    bodies[4]=patch(bodies[4],local_release,handmask)
    cup=binary(local_release.crop((321,49,405,99))).resize((50,30),Image.Resampling.NEAREST)
    bodies[4].alpha_composite(cup,(249,85))
    report["cords"][IDS[4]]=[cord(bodies[4],(147,130),(251,96),local_release)]
    free=local_release.crop((403,57,501,152))
    bodies[4].alpha_composite(free,(294,85))
    Image.fromarray((handmask*255).astype('uint8')).save(SRC/"release_wrist_mask.png")
    report["repairs"].append({"id":IDS[4],"base":"source pose3 overhead","wrist":"release_local.webp","mask":"source/release_wrist_mask.png","empty_cradle":"release_local.webp crop321,49,405,99 ->50x30","free_cord":"same source crop403,57,501,152, unscaled; rooted at other cradle knot","retained_cord_only_at_hand":True})
    # Catch: clean ready torso plus exact generated empty pinch-paw. Its
    # pre-existing little cord under the thumb is retained as grip overlap.
    bodies[5]=base[0].copy()
    catchmask=polygon([(245,276),(284,274),(291,284),(292,306),(278,319),(253,315),(244,306)])
    donor=translate(base[5],(6,-4))
    mask=translate(Image.fromarray(np.repeat((catchmask*255).astype('uint8')[:,:,None],4,axis=2)),(6,-4)).getchannel('A')
    cm=np.asarray(mask)>0;bodies[5]=patch(bodies[5],donor,cm)
    clean=polygon([(78,215),(141,215),(147,344),(80,346)])
    bodies[5]=clear(bodies[5],clean)
    ends=place_cup(bodies[5],empty,(125,325),0)
    report["cords"][IDS[5]]=[cord(bodies[5],(115,212),ends[0],local_release),cord(bodies[5],ends[1],(252,297),local_release)]
    Image.fromarray((cm*255).astype('uint8')).save(SRC/"catch_paw_mask.png")
    report["repairs"].append({"id":IDS[5],"base":"source pose0 clean ready torso","paw_donor":"source pose5 originally valid empty pinch paw only","paw_translation":[6,-4],"mask":"source/catch_paw_mask.png","extra_waist_rope_and_tassel_never_adopted":True,"sling_graph":"throwing paw -> retention cord -> empty cradle -> release cord -> free paw","body_outside_paw_and_weapon_masks_preserved":True})
    masks=Image.new('L',(512*4,512*2));changes=[]
    for i,im in enumerate(bodies):
        original=base[3 if i==4 else 0 if i==5 else i]
        change=np.any(np.asarray(im)!=np.asarray(original),axis=2)
        masks.paste(Image.fromarray((change*255).astype('uint8')),((i%4)*512,(i//4)*512))
        ys,xs=np.where(change)
        changes.append({'id':IDS[i],'body_source_index':3 if i==4 else 0 if i==5 else i,'changed_rgba_pixels':int(change.sum()),'change_bbox':None if not len(xs) else [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]})
    masks.save(SRC/'repair_masks.png');report['source_changes']=changes
    # Common nearest scaling and rear sole registration, no per-pose fit.
    normalized=[];sole_records=[]
    for i,im in enumerate(bodies):
        # Source feet are at different layout positions. The source rear
        # sole window derives directly from the complete component crop.
        a=np.asarray(im);yy,xx=np.where(a[375:445,:220,3]>0);bottom=375+int(yy.max());xs=np.where(a[bottom-2:bottom+1,:220,3]>0)[1];rear=(float(xs.mean()),bottom)
        scaled=im.resize((round(512*SCALE),round(512*SCALE)),Image.Resampling.NEAREST)
        dst=Image.new('RGBA',(448,448));offset=(round(ANCHOR[0]-rear[0]*SCALE),round(ANCHOR[1]-rear[1]*SCALE));dst.alpha_composite(scaled,offset)
        normalized.append(binary(dst));sole_records.append({"id":IDS[i],"source_rear_sole":list(rear),"common_scale":SCALE,"paste":list(offset)})
    rear_target=sole(normalized[0],False)
    for i,im in enumerate(normalized):
        current=sole(im,False)
        correction=(round(rear_target[0]-current[0]),rear_target[1]-current[1])
        normalized[i]=translate(im,correction)
        sole_records[i]['rear_raster_correction']=list(correction)
    before=[im.copy() for im in normalized]
    target=sole(before[0],True)
    for i,im in enumerate(normalized):
        current=sole(im,True);dy=target[1]-current[1];v=register_front(im,0,dy);dx=round(target[0]-sole(v,True)[0]);normalized[i]=register_front(im,dx,dy)
        sole_records[i].update({"front_before":list(current),"front_correction_at_sole":[dx,dy],"front_after":list(sole(normalized[i],True)),"rear_after":list(sole(normalized[i],False)),"taper_band_y":[354,387]})
    report['sole_registration']=sole_records
    report['front_target']=list(target)
    strips=[]
    for name,images in [('before_foot_registration',before),('registered_poses',normalized)]:
        strip=Image.new('RGBA',(448*4,448*2))
        for i,im in enumerate(images):strip.alpha_composite(im,((i%4)*448,(i//4)*448))
        exact_webp(strip,SRC/(name+'.webp'));strips.append((name,strip))
    # Compact read-only foot comparison: source registration above, fixed
    # planted soles below. Full bodies remain in atlas/contact and WebPs.
    review=Image.new('RGBA',(960,288));draw=ImageDraw.Draw(review)
    for i,im in enumerate(normalized):
        x,y=(i%4)*240,(i//4)*144
        draw.text((x+2,y),IDS[i]+' before / after',fill='white')
        review.alpha_composite(before[i].crop((90,350,330,412)),(x,y+16))
        review.alpha_composite(im.crop((90,350,330,412)),(x,y+80))
    review.save(ROOT/'foot_alignment_review.png')
    report['registered_source_sha256']=sha(SRC/'registered_poses.webp')
    report['registered_rgba_sha256']=hashlib.sha256(strips[-1][1].tobytes()).hexdigest()
    (SRC/'preparation_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'bodies':len(normalized),'front_target':list(target),'sole_registration':sole_records},ensure_ascii=False))


if __name__=='__main__':main()
