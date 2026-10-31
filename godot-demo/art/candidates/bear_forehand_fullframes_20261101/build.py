#!/usr/bin/env python3
"""Exploratory conversion of all approved source frames, not visually accepted."""
import argparse, hashlib, importlib.util, json, re, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'bear_lord_video_attack_v1/forehand-7499-short-windup-v2.mp4'
MATTE = HERE.parent / 'bear_lord_back_attack_v1/build.py'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--ffmpeg', required=True); ap.add_argument('--output', required=True); args=ap.parse_args()
    out=Path(args.output); out.mkdir(parents=True, exist_ok=False); (out/'frames').mkdir()
    spec=importlib.util.spec_from_file_location('source_matte', MATTE); matte=importlib.util.module_from_spec(spec); spec.loader.exec_module(matte)
    with tempfile.TemporaryDirectory(prefix='bear-front-raw-') as raw:
        cmd=[args.ffmpeg,'-hide_banner','-i',str(SOURCE),'-vf','showinfo','-fps_mode','passthrough',str(Path(raw)/'frame_%03d.png')]
        result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,check=True)
        lines=re.findall(r'\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:([0-9.]+)',result.stderr)
        if len(lines)!=96 or [int(x[0]) for x in lines]!=list(range(96)): raise ValueError('expected 96 source PTS values')
        records=[]
        for j,(_,pts,t) in enumerate(lines,1):
            rgb=np.asarray(Image.open(Path(raw)/f'frame_{j:03d}.png').convert('RGB')).astype(np.float32)
            keyed,_=matte.matte(rgb,0) # No back-specific frame-keyed foot masks or veil.
            im=keyed.convert('RGBa').transform((384,320),Image.Transform.AFFINE,(1/.337662,0,-7/.337662,0,1/.337662,15/.337662),Image.Resampling.BICUBIC).convert('RGBA')
            target=out/'frames'/f'attack_{j:03d}.png'; im.save(target)
            records.append({'file':target.name,'source_frame_one_based':j,'source_pts':int(pts),'source_time_seconds':float(t),'sha256':sha(target)})
        result={'status':'draft_not_for_runtime','source_sha256':sha(SOURCE),'canvas':[384,320],'foot':[177,213],'source_sign':1,'source_back':False,'scale':.337662,'translation':[7,-15],'duration_seconds':3.5,'frames':records,'limitations':['shoulder_color_unresolved','source_frames_52_53_weapon_cropped','source_specific_matte_not_accepted','not_integrated']}
        (out/'manifest.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
if __name__=='__main__': main()
