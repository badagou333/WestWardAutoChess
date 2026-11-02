#!/usr/bin/env python3
"""D-20261102-002. Deterministic full-PTS front matte and same-source club repair.

No generated imagery, temporal interpolation, per-frame body registration or colour
grading. Requires Python 3, NumPy, Pillow, SciPy and FFmpeg with showinfo durations.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, shutil, subprocess, tempfile, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov'
SOURCE_SHA='d37dffe785d83306c0f41f54b12348d0043f189bcf91251659816e291be548c0'
# Measured in first cropped-source frame: visible body top y=263, support
# points approximately (412,703),(592,638). The anchor (500,675) also matches
# same-original-frame registration against the current runtime to <0.25px.
# Preserve the established ~118px display height; never track moving feet.
SOURCE_FOOT=(500,675)
SCALE=0.337662
FOOT=(177,213)
CANVAS=(400,320) # right extension accommodates repaired head at source x>960
DISPLAY_SCALE=.75
PATCHES={43:dict(donor=45,source_pivot=[775,432],target_pivot=[775,511],angle=20,scale=1.22,blur=1.25),
         44:dict(donor=45,source_pivot=[775,432],target_pivot=[787,453],angle=9,scale=1.12,blur=.35)}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(cmd):
    p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    return p.stderr.decode()
def morph(mask,n,maximum=False):
    return np.asarray(Image.fromarray(mask.astype('uint8')*255).filter(ImageFilter.MaxFilter(n) if maximum else ImageFilter.MinFilter(n)))>0
def fill(mask):
    outside=np.zeros_like(mask);outside[0,0]=True
    return ~ndimage.binary_propagation(outside,mask=~mask)
def polygon_mask(size,points):
    im=Image.new('L',size);ImageDraw.Draw(im).polygon(points,fill=255);return np.asarray(im)>0

def matte(a,n):
    lo,hi=a.min(2),a.max(2)
    seeds=(lo<135)|((hi-lo>14)&(lo<185))
    if n==45:
        # Detached sweep fleck below the weapon, visible on dark review;
        # no club/hand pixels lie inside this measured source rectangle.
        seeds[480:515,920:950]=False
    foot_protect=np.zeros(lo.shape,bool)
    if 42<=n<=48:
        # New front-specific outlines, traced on these source frames. They
        # retain pale toes beneath the sweep; never reuse rear foot masks.
        left=[(388,642),(428,640),(439,654),(444,670),(446,689),(440,701),
              (433,706),(426,703),(420,713),(413,704),(404,711),(398,702),
              (391,704),(383,696),(376,686),(377,671),(381,656)]
        right=[(544,607),(577,598),(608,607),(619,614),(630,620),(634,633),
               (626,632),(629,641),(614,639),(609,645),(594,641),(573,637),(543,627)]
        foot_protect=polygon_mask((960,960),left)|polygon_mask((960,960),right)
        seeds|=foot_protect&(lo<170)
    mask=fill(morph(morph(seeds,5,True),5))
    pale=(lo>224)&(hi-lo<15)
    pale=morph(morph(pale,3),3,True)
    mask &= ~(pale&~foot_protect)
    labels,count=ndimage.label(mask)
    sizes=np.bincount(labels.ravel());keep=sizes>=25;keep[0]=False
    removed_specks=int((mask&~keep[labels]).sum())
    mask=keep[labels]
    assert 20000<mask.sum()<400000,'Unexpected matte coverage'
    core=morph(mask,5)
    known=core.copy();ref=a.copy()
    for _ in range(7):
        new=known.copy()
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            take=~new & np.roll(known,(dy,dx),(0,1))
            shifted=np.roll(ref,(dy,dx),(0,1));ref[take]=shifted[take];new[take]=True
        known=new
    geom=np.asarray(Image.fromarray(mask.astype('uint8')*255).filter(ImageFilter.GaussianBlur(.65))).astype('float32')/255
    # Background estimate comes from a source region untouched by the actor.
    bg=np.median(a[800:900,100:200],axis=(0,1))
    yy,xx=np.mgrid[:960,:960]
    strength=float(np.interp(n,[40,41,42,43,44,45,46,47,48,49,50],[0,0,.20,.35,.32,.27,.18,.09,.04,0,0]))
    regions=np.maximum(np.clip(1-((xx-412)/65)**2-((yy-671)/85)**2,0,1),
                       np.clip(1-((xx-584)/80)**2-((yy-625)/48)**2,0,1))
    local_bg=bg-((strength/.35)*35*regions)[...,None]
    direction=local_bg-ref
    coverage=np.clip(((local_bg-a)*direction).sum(2)/((direction**2).sum(2)+1e-6),.02,1)
    band=~core&(geom>0)&known
    colour=np.where(band[...,None],(a-local_bg*(1-coverage[...,None]))/coverage[...,None],a)
    alpha=np.where(band,np.minimum(geom,coverage),geom)
    # Limited optical-veil inversion only below the belt; source texture is
    # retained. It is an estimate, not recovery of information hidden by FX.
    veil=strength*regions*np.clip((a.mean(2)-60)/75,0,1)
    colour=(colour-222*veil[...,None])/(1-veil[...,None])
    rgba=np.rint(np.dstack((np.clip(colour,0,255),alpha*255))).astype('uint8')
    rgba[rgba[:,:,3]==0,:3]=0
    # Explicit check: all deep upper-body source pixels including shoulders
    # keep their original RGB. Alpha checks remain distinct from appearance.
    protected=core&(yy<530)
    assert np.array_equal(rgba[protected,:3],a[protected].astype('uint8'))
    return Image.fromarray(rgba),dict(upper_body_unchanged_pixels=int(protected.sum()),removed_isolated_seed_pixels=removed_specks,background_rgb=bg.tolist(),veil_strength=strength,source_matte_bbox=list(Image.fromarray(mask).getbbox()))

def repair_weapon(im,donor,n):
    p=PATCHES[n];w,h=1120,960
    # Crop only the donor's complete club head, including its base collar.
    # Transparent donor pixels already have a soft matte; body is excluded.
    cut=donor.copy();arr=np.array(cut)
    yy,xx=np.mgrid[:960,:960]
    region=(xx>=754)&(yy>=305)&(yy<=475)
    feather=np.clip((xx-754)/7,0,1)*region
    arr[:,:,3]=np.rint(arr[:,:,3]*feather).astype('uint8')
    cut=Image.fromarray(arr).convert('RGBa')
    angle=math.radians(p['angle']);s=p['scale'];c=math.cos(angle)/s;k=math.sin(angle)/s
    sx,sy=p['source_pivot'];tx,ty=p['target_pivot']
    transformed=cut.transform((w,h),Image.Transform.AFFINE,(c,k,sx-c*tx-k*ty,-k,c,sy+k*tx-c*ty),Image.Resampling.BICUBIC)
    if p['blur']: transformed=transformed.filter(ImageFilter.GaussianBlur(p['blur']))
    transformed=transformed.convert('RGBA')
    patch_array=np.array(transformed)
    patch_array[:,:754]=0 # repair must never overlap the arm or torso
    transformed=Image.fromarray(patch_array)
    base=Image.new('RGBA',(w,h));base.alpha_composite(im)
    b=np.array(base); yy,xx=np.mgrid[:h,:w]
    # Only remove the original damaged head, feathering the base collar.
    remove=np.clip((xx-754)/8,0,1)*((yy>330)&(yy<590))
    b[:,:,3]=np.rint(b[:,:,3]*(1-remove)).astype('uint8')
    out=Image.fromarray(b);out.alpha_composite(transformed)
    assert np.array_equal(np.asarray(out)[:,:750],np.asarray(base)[:,:750])
    return out,transformed

def fixed(im):
    tx=FOOT[0]-SOURCE_FOOT[0]*SCALE;ty=FOOT[1]-SOURCE_FOOT[1]*SCALE
    return im.convert('RGBa').transform(CANVAS,Image.Transform.AFFINE,(1/SCALE,0,-tx/SCALE,0,1/SCALE,-ty/SCALE),Image.Resampling.BICUBIC).convert('RGBA')

def build(args):
    out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    for name in ('frames','audio','source','review'): (out/name).mkdir(exist_ok=True)
    assert sha(SOURCE)==SOURCE_SHA
    with tempfile.TemporaryDirectory(prefix='bear-front-decode-') as tmp:
        raw=Path(args.decoded_dir or tmp)
        log=run([args.ffmpeg,'-hide_banner','-i',str(SOURCE),'-map','0:v:0','-vf','showinfo','-fps_mode','passthrough','-f','null','-'])
        (out/'source/video-showinfo.log').write_text('\n'.join(line.rstrip() for line in log.splitlines())+'\n')
        timing=[(int(i),int(p),int(d)) for i,p,d in re.findall(r'n:\s*(\d+) pts:\s*(-?\d+) pts_time:[\d.-]+\s+duration:\s*(\d+)',log)]
        assert len(timing)==84 and [t[0] for t in timing]==list(range(84))
        assert timing[0][1]==0 and timing[-1][1]+timing[-1][2]==46080
        if not args.decoded_dir:
            run([args.ffmpeg,'-hide_banner','-loglevel','error','-i',str(SOURCE),'-map','0:v:0','-fps_mode','passthrough',str(raw/'frame_%03d.png')])
        donor,_=matte(np.asarray(Image.open(raw/'frame_045.png').convert('RGB')).astype('float32'),45)
        records=[]
        indices=args.sample or range(1,85)
        for n in indices:
            path=raw/f'frame_{n:03d}.png';a=np.asarray(Image.open(path).convert('RGB')).astype('float32')
            im,stats=matte(a,n)
            if n in PATCHES:
                fixed(im).save(out/'review'/f'weapon-before-{n}.png')
                im,patch=repair_weapon(im,donor,n)
                patch.save(out/'review'/f'weapon-patch-source-{n}.png')
                im.save(out/'review'/f'weapon-repaired-source-{n}.png')
            result=fixed(im);dst=out/'frames'/f'attack_{n:04d}.png';result.save(dst,optimize=True)
            aa=np.asarray(result)
            assert not(aa[0,:,3].any() or aa[-1,:,3].any() or aa[:,0,3].any() or aa[:,-1,3].any())
            _,pts,dur=timing[n-1]
            records.append(dict(file=dst.name,source_frame=n,original_source_frame=n+9,source_pts=pts,original_source_pts=pts+5888,
                duration_ticks=dur,source_time_seconds=pts/15360,output_time_seconds=pts/15360,duration_seconds=dur/15360,
                sha256=sha(dst),decoded_source_sha256=sha(path),bbox=list(result.getbbox()),repair=PATCHES.get(n),**stats))
        if args.sample:
            print(json.dumps(records));return
        alog=run([args.ffmpeg,'-y','-hide_banner','-i',str(SOURCE),'-map','0:a:0','-af','ashowinfo','-c:a','pcm_s16le',str(out/'audio/source-track.wav')])
        (out/'source/audio-ashowinfo.log').write_text('\n'.join(line.rstrip() for line in alog.splitlines())+'\n')
        with wave.open(str(out/'audio/source-track.wav')) as w:
            audio=dict(file='audio/source-track.wav',sample_rate=w.getframerate(),channels=w.getnchannels(),sample_width_bytes=w.getsampwidth(),sample_frames=w.getnframes(),duration_seconds=w.getnframes()/w.getframerate(),offset_seconds=0,sha256=sha(out/'audio/source-track.wav'))
        assert re.search(r'pts:0 pts_time:0',alog)
        m=dict(schema='board-bear-front-attack-v2',status='candidate_needs_visual_review',art_source='user-approved cropped existing video; deterministic local processing',
          source_video='../bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov',source_sha256=SOURCE_SHA,source_size=[960,960],source_time_base=[1,15360],
          original_frame_range=[10,93],original_pts_offset_ticks=5888,decoded_frame_count=84,canvas=list(CANVAS),foot=list(FOOT),source_foot=list(SOURCE_FOOT),
          global_scale=SCALE,global_translation=[FOOT[0]-SOURCE_FOOT[0]*SCALE,FOOT[1]-SOURCE_FOOT[1]*SCALE],display_scale=DISPLAY_SCALE,
          source_sign=1,source_back=False,video_duration_seconds=3,loop_interval_seconds=0,
          loop_note='No added hold: audio ends before 3s; source end/start pose difference requires continuous review.',audio=audio,frames=records)
        (out/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
        print(json.dumps(dict(frames=len(records),duration=3,audio=audio,rest_bbox=records[0]['bbox'])))

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--ffmpeg',default=shutil.which('ffmpeg') or 'ffmpeg')
    ap.add_argument('--output',default=str(HERE));ap.add_argument('--decoded-dir');ap.add_argument('--sample',type=int,nargs='+')
    build(ap.parse_args())
