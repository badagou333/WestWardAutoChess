#!/usr/bin/env python3
"""Register imagegen recovery/step artwork and preserve protected body pixels."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def normalized(path,size):
    raw=Image.open(path).convert('RGBA').resize(size,Image.Resampling.NEAREST)
    colors=json.loads((ROOT.parent/'guard_monk_pixel_attack_v1/manifest.json').read_text())['shared_opaque_palette_rgb']
    palette=Image.new('P',(1,1));palette.putpalette([v for c in colors for v in c]+list(colors[0])*(256-len(colors)))
    q=np.array(raw.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA'))
    q[:,:,3]=np.where(np.array(raw.getchannel('A'))>=128,255,0);q[q[:,:,3]==0]=0
    return Image.fromarray(q)

def apply(base,edit,polygons,protected=()):
    mask=Image.new('L',base.size);d=ImageDraw.Draw(mask)
    for poly in polygons:d.polygon([tuple(p) for p in poly],fill=255)
    for rect in protected:d.rectangle(rect,fill=0)
    old=np.array(base);new=np.array(edit);sel=np.array(mask)>0;out=old.copy();out[sel]=new[sel]
    return Image.fromarray(out),mask

def placed(edit,offset):
    out=Image.new('RGBA',(448,448));out.alpha_composite(edit,offset);return out

def main():
    outdir=ROOT/'body';outdir.mkdir(exist_ok=True)
    base4=Image.open(ROOT.parent/'guard_monk_pixel_attack_v1/frames/04_pullback.png').convert('RGBA')
    rec=normalized(ROOT/'source/recovery_generated.webp',(448,448))
    arms=normalized(ROOT/'source/recovery_arm_geometry.webp',(448,448))
    # The illustrated arm pair is translated to the original shaft's two grip
    # landmarks; no whole-body movement or arm rotation is synthesized.
    arm_registered=placed(arms,(-20,36))
    protected=[(125,165,244,239),(0,314,447,447)]
    rec4,mask1=apply(base4,rec,[[[185,275],[257,187],[332,133],[346,159],[300,236],[285,301],[202,312]]],protected)
    rec4,mask2=apply(rec4,arm_registered,[[[172,242],[218,241],[260,187],[288,190],[294,228],[264,268],[271,294],[236,307],[196,301],[172,272]],[[272,216],[319,216],[319,283],[260,283],[260,250],[272,250]]],protected)
    # Register the separately drawn bent foreleg slightly above its reference
    # sole plane, so the return is an airborne step rather than a flat slide.
    rec4,mask3=apply(rec4,placed(rec,(0,-8)),[[[240,333],[279,329],[327,353],[331,407],[244,407],[234,372]]])
    array=np.array(rec4);visible=array[:,:,3]>0;seen=np.zeros(visible.shape,dtype=bool);removed=[]
    for sy,sx in zip(*np.where(visible)):
        if seen[sy,sx]:continue
        queue=[(int(sy),int(sx))];seen[sy,sx]=True;component=[]
        while queue:
            yy,xx=queue.pop();component.append((yy,xx))
            for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
                ny,nx=yy+dy,xx+dx
                if 0<=ny<448 and 0<=nx<448 and visible[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;queue.append((ny,nx))
        if len(component)<=4 and all(280<=xx<310 and 200<=yy<230 for yy,xx in component):
            for yy,xx in component:array[yy,xx]=0
            removed.append({'pixels':len(component),'points_yx':component})
    rec4=Image.fromarray(array);rec4.save(outdir/'04_recovery_fixed.png')
    base0=Image.open(ROOT.parent/'guard_monk_pixel_attack_v1/frames/00_raised_windup.png').convert('RGBA')
    leg=normalized(ROOT/'source/step_generated.webp',(100,104))
    step6,mask4=apply(base0,placed(leg,(225,300)),[[[242,337],[283,331],[325,354],[325,413],[232,413],[232,369]]])
    step6.save(outdir/'06_step_lift.png')
    for name,mask in [('recovery_base',mask1),('recovery_arms',mask2),('recovery_foreleg',mask3),('step_foreleg',mask4)]:mask.save(ROOT/'source'/f'{name}_mask.png')
    report={'alignment_notes':{'recovery_arm_translation':[-20,36],'return_leg_translation':[0,-8],'step_crop_top_left':[225,300]},'removed_source_specks':removed,'outputs':[]}
    for name,base in [('04_recovery_fixed.png',base4),('06_step_lift.png',base0)]:
        q=np.array(Image.open(outdir/name));diff=np.any(q!=np.array(base),axis=2);ys,xs=np.where(diff)
        report['outputs'].append({'file':'body/'+name,'sha256':sha(outdir/name),'changed_pixels':int(diff.sum()),'changed_bbox':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]})
    (ROOT/'patch_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':main()
