#!/usr/bin/env python3
"""Rebuild the approved back attack: same pixels, all source PTS, no synthesis.

Python 3 + Pillow + NumPy; FFmpeg 5+ via --ffmpeg/PATH. Source-specific
matte thresholds and local arc removal are deliberately documented here.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
SOURCE_SHA = "30ef7c2cf59580e9b257300cd884fda4fa10359490389f98553889cbe97c1682"
CANVAS = (384, 320)
SOURCE_FOOT = (471, 711)
FOOT = (177, 213)
SCALE = 0.35
DISPLAY_SCALE = 0.75
# Approved MP4 audio edit list: 3624 movie ticks at 1000 Hz, starting after
# 1024 AAC priming samples. Keep exactly its 115968 presented samples.
AUDIO_PRESENTED_SAMPLES = 115968
# Source frame numbers are one-based. This is newly measured for this clip,
# unrelated to the old front 20-frame FOOT_VEILS table.
VEIL_KEYS = [(149,0),(151,0),(152,.65),(156,.65),(157,.70),(161,.72),(165,.65),
             (169,.54),(173,.43),(177,.34),(181,.25),(185,.13),(189,.04),(193,0)]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def morph(mask, size, maximum=False):
    filt = ImageFilter.MaxFilter(size) if maximum else ImageFilter.MinFilter(size)
    return np.asarray(Image.fromarray(mask.astype(np.uint8)*255).filter(filt)) > 0

def filled(mask):
    im = Image.fromarray((~mask).astype(np.uint8)*255).copy()
    ImageDraw.floodfill(im, (0,0), 128)
    return np.asarray(im) != 128

def matte(a, source_frame):
    lo, hi = a.min(2), a.max(2)
    # Dark silhouette or brown/red/cloth colour. Grey sweep stays outside;
    # enclosed silver armour is restored by hole filling, not colour erasure.
    seeds = (lo < 135) | ((hi-lo > 14) & (lo < 185))
    if 152 <= source_frame <= 172:
        # The two feet behind the source's pale arc: retain their low-contrast
        # contours. Spatial limits exclude the nearby non-character sweep.
        protection=Image.new('L',(a.shape[1],a.shape[0]),0)
        pen=ImageDraw.Draw(protection)
        shift=max(0,source_frame-163)/9
        left=[(332,590),(380,596),(393,615),(395,638),(386,656),
              (372,663),(349,661),(332,651),(322,637),(320,621),(324,607)]
        right=[(521,610),(581,613),(576,645),(594,651),(606,666),
               (609,685),(597,693),(548,697),(526,691),(515,680),(517,663),(522,648)]
        for polygon in (left,right):
            pen.polygon([(x+3*shift,y+7*shift) for x,y in polygon],fill=255)
        seeds |= (np.asarray(protection)>0) & (lo<175)
    mask = filled(morph(morph(seeds,5,True),5))
    # Restore real negative spaces enclosed by an arm/waist. Large flat pale
    # holes are background; opening excludes tiny specular armour highlights.
    pale_hole=(lo>224)&(hi-lo<15)
    pale_hole=morph(morph(pale_hole,3),3,True)
    mask &= ~pale_hole
    core = morph(mask,5)
    known = core.copy()
    reference = a.copy()
    # Nearby reliable original foreground colours, propagated only in the
    # narrow contour band. Deep interior RGB is never substituted.
    for _ in range(7):
        new = known.copy()
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            neighbour = np.roll(known,(dy,dx),(0,1))
            take = ~new & neighbour
            shifted = np.roll(reference,(dy,dx),(0,1))
            reference[take] = shifted[take]
            new[take] = True
        known = new
    geometry = np.asarray(Image.fromarray(mask.astype(np.uint8)*255)
                          .filter(ImageFilter.GaussianBlur(.65))).astype(np.float32)/255
    yy = np.arange(a.shape[0],dtype=np.float32)[:,None]
    strength = float(np.interp(source_frame,*zip(*VEIL_KEYS)))
    lower_body = np.clip((yy-545)/55,0,1)
    # Local background in the sweep is darker than the two pale source plates.
    bg = np.broadcast_to(247 - 40*(strength/.72)*lower_body,a.shape[:2])[...,None]
    direction = bg-reference
    coverage = np.clip(((bg-a)*direction).sum(2)/(np.square(direction).sum(2)+1e-6),.02,1)
    band = ~core & (geometry>0) & known
    colour = np.where(band[...,None],(a-bg*(1-coverage[...,None]))/coverage[...,None],a)
    alpha = np.where(band,np.minimum(geometry,coverage),geometry)
    # Invert only the grey veil over lower fur/feet, on retained original
    # pixels. This cannot recover detail hidden in the source and is marked
    # approximate in README; no new foot or weapon texture is painted.
    # Dark/brown ankle detail is not covered by the sweep equally. Restrict
    # inversion to the newly pale observed pixels to avoid black ankle bands.
    veil = (strength*.80*lower_body*np.clip((a.mean(2)-95)/45,0,1)
            *np.clip((40-(hi-lo))/18,0,1))
    colour = (colour-220*veil[...,None])/(1-veil[...,None])
    result = np.rint(np.dstack([np.clip(colour,0,255),alpha*255])).astype(np.uint8)
    result[result[:,:,3]==0,:3]=0
    return Image.fromarray(result), mask

def fixed_canvas(im):
    # Pillow RGBa is premultiplied; resizing in this mode avoids pale/black
    # fringes. Every frame gets exactly this same affine transform.
    premul=im.convert('RGBa')
    tx,ty=FOOT[0]-SOURCE_FOOT[0]*SCALE,FOOT[1]-SOURCE_FOOT[1]*SCALE
    out=premul.transform(CANVAS,Image.Transform.AFFINE,
        (1/SCALE,0,-tx/SCALE,0,1/SCALE,-ty/SCALE),Image.Resampling.BICUBIC)
    return out.convert('RGBA')

def process_one(args):
    src,dst,index=args
    rgb=np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
    keyed,mask=matte(rgb,index)
    out=fixed_canvas(keyed)
    out.save(dst,optimize=True)
    bbox=out.getbbox()
    return dict(source_frame=index,file=Path(dst).name,sha256=sha(dst),
                source_decoded_sha256=sha(src),bbox=list(bbox),
                visible_pixels=int((np.asarray(out)[:,:,3]>25).sum()),
                source_matte_bbox=list(Image.fromarray(mask).getbbox()))

def run(command):
    p=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    if p.returncode: raise RuntimeError(p.stderr[-6000:])
    return p.stderr

def build(args):
    source=HERE/'source/bear-back-short-repaired-v1.mp4'
    assert sha(source)==SOURCE_SHA,'Approved source differs'
    for name in ('frames','audio','review','source'): (HERE/name).mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='bear-back-decode-') as tmp:
        decoded=Path(args.decoded_dir) if args.decoded_dir else Path(tmp)
        log=run([args.ffmpeg,'-hide_banner','-i',str(source),'-map','0:v:0',
                 '-vf','showinfo','-fps_mode','passthrough','-f','null','-'])
        (HERE/'source/video-showinfo.log').write_text(log)
        tb=re.search(r'config in time_base: (\d+)/(\d+)',log)
        num,den=map(int,tb.groups())
        timings=[(int(i),int(pts),int(dur)) for i,pts,dur in re.findall(
            r'n:\s*(\d+) pts:\s*(-?\d+) pts_time:[\d.-]+\s+duration:\s*(\d+)',log)]
        assert len(timings)==340 and [t[0] for t in timings]==list(range(340))
        if not args.decoded_dir:
            run([args.ffmpeg,'-hide_banner','-loglevel','error','-i',str(source),
                 '-map','0:v:0','-fps_mode','passthrough',str(decoded/'frame_%06d.png')])
        paths=sorted(decoded.glob('frame_*.png'))
        assert len(paths)==len(timings)
        indexes=args.sample if args.sample else list(range(1,len(paths)+1))
        jobs=[(str(paths[n-1]),str(HERE/'frames'/f'attack_{n:04d}.png'),n) for n in indexes]
        with ProcessPoolExecutor(max_workers=args.workers) as pool:
            result=list(pool.map(process_one,jobs))
        if args.sample:
            print(json.dumps({'sample_complete':indexes}));return
        for r,(i,pts,dur) in zip(result,timings):
            r.update(source_pts=pts,source_time_seconds=pts*num/den,
                     output_time_seconds=pts*num/den,duration_seconds=dur*num/den)
        end=(timings[-1][1]+timings[-1][2])*num/den
        alog=run([args.ffmpeg,'-y','-hide_banner','-i',str(source),'-map','0:a:0',
                  '-af',f'ashowinfo,atrim=end_sample={AUDIO_PRESENTED_SAMPLES}',
                  '-c:a','pcm_s16le',str(HERE/'audio/source-track.wav')])
        (HERE/'source/audio-ashowinfo.log').write_text(alog)
        audio_times=[(int(t),int(n)) for t,n in re.findall(r'pts:(\d+) pts_time:[\d.]+.*?nb_samples:(\d+)',alog)]
        with wave.open(str(HERE/'audio/source-track.wav')) as w:
            audio=dict(file='audio/source-track.wav',sample_rate=w.getframerate(),
                       channels=w.getnchannels(),sample_frames=w.getnframes(),
                       duration_seconds=w.getnframes()/w.getframerate(),
                       source_start_seconds=audio_times[0][0]/w.getframerate(),
                       added_leading_silence_samples=0,
                       decoded_sample_frames=sum(n for _,n in audio_times),
                       removed_aac_tail_padding_samples=sum(n for _,n in audio_times)-w.getnframes(),
                       sha256=sha(HERE/'audio/source-track.wav'))
        assert audio['source_start_seconds']==0
        manifest=dict(schema='board-bear-back-attack-v1',source_video='source/bear-back-short-repaired-v1.mp4',
            source_sha256=SOURCE_SHA,source_size=[960,960],source_time_base=[num,den],
            source_sign=1,source_back=True,canvas=list(CANVAS),foot=list(FOOT),
            source_foot=list(SOURCE_FOOT),global_scale=SCALE,display_scale=DISPLAY_SCALE,
            video_duration_seconds=end,loop_interval_seconds=.35,decoded_frame_count=len(result),
            unique_texture_count=len(set(r['sha256'] for r in result)),audio=audio,frames=result)
        (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        print(json.dumps({'frames':len(result),'video_duration':end,'audio':audio,'rest_bbox':result[0]['bbox']}))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--ffmpeg',default=shutil.which('ffmpeg') or 'ffmpeg')
    p.add_argument('--decoded-dir',help='Optional existing complete decoded PNG cache')
    p.add_argument('--workers',type=int,default=4)
    p.add_argument('--sample',nargs='+',type=int)
    build(p.parse_args())
