#!/usr/bin/env python3
"""Rebuild local trial from locked MOV plus immutable v2 PNGs; no synthesis."""
import argparse,hashlib,json,subprocess,tempfile,shutil,os
from pathlib import Path
import numpy as np
from scipy import ndimage
from PIL import Image,ImageFilter,ImageDraw
HERE=Path(__file__).resolve().parent
B=HERE.parent/'bear_lord_front_attack_v2'
S=HERE.parent/'bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def proc(n,raw,old):
 if not 38<=n<=51:return old,0
 a=np.asarray(raw.convert('RGB')).astype('float32');bg=np.median(a[800:900,100:200],axis=(0,1)); delta=(bg-a).mean(2)
 # FX is estimated as an existing gray veil on pale plate, not generated arcs.
 alpha=np.clip((delta-5)/max(1,float(bg.mean()-145)-5),0,.90)
 # Do not include watermark/outer background: spatial area follows source, no painted arc.
 yy,xx=np.mgrid[:960,:960];allowed=(xx>8)&(yy>135)&(yy<810)
 # Reproject opaque body in original source coordinates, exclude its immediate
 # neighbourhood from estimated FX; original actor including patched club remains on top.
 aold=old.getchannel('A').transform((960,960),Image.Transform.AFFINE,(.337662,0,8.169,0,.337662,-14.92185),Image.Resampling.BILINEAR)
 fg=np.asarray(aold)>16;dist=ndimage.distance_transform_edt(~fg);edge=np.clip((dist-4)/12,0,1)
 alpha*=allowed*edge
 # Only the FX layer at the original source's cut right edge is faded. The
 # actor is composited later and is never feathered. Source x < 960-W remains
 # exactly untouched. Width given in source pixels.
 W=int(os.environ.get('TRAIL_EDGE_WIDTH','24'))
 if 38<=n<=51 and W>0:
  t=np.clip((960-xx)/W,0,1)
  alpha*=t*t*(3-2*t)
 rgba=np.zeros((960,960,4),dtype='uint8');rgba[:,:,:3]=145;rgba[:,:,3]=np.rint(alpha*255).astype('uint8');rgba[rgba[:,:,3]==0,:3]=0
 im=Image.fromarray(rgba).convert('RGBa').transform((400,320),Image.Transform.AFFINE,(1/.337662,0,-8.169/.337662,0,1/.337662,14.92185/.337662),Image.Resampling.BICUBIC).convert('RGBA')
 out=Image.new('RGBA',(400,320));out.alpha_composite(im);out.alpha_composite(old)
 return out,int((np.asarray(im)[:,:,3]>5).sum())
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--sample',type=int,nargs='*');p.add_argument('--raw');p.add_argument('--ffmpeg',default=shutil.which('ffmpeg') or 'ffmpeg');a=p.parse_args();o=Path(a.output);(o/'frames').mkdir(parents=True,exist_ok=True);(o/'review').mkdir(exist_ok=True)
 assert sha(S)=='d37dffe785d83306c0f41f54b12348d0043f189bcf91251659816e291be548c0'
 oldm=json.loads((B/'manifest.json').read_text());records=[]
 with tempfile.TemporaryDirectory() as tmp:
  raw=Path(a.raw or tmp)
  if not a.raw:subprocess.run([a.ffmpeg,'-v','error','-i',str(S),'-map','0:v:0','-fps_mode','passthrough',str(raw/'frame_%03d.png')],check=True)
  assert [f.name for f in sorted(raw.glob('frame_*.png'))]==[f'frame_{n:03d}.png' for n in range(1,85)], 'Expected 84 decoded source frames'
  for n in (a.sample or range(1,85)):
   f=oldm['frames'][n-1];q=B/'frames'/f['file'];assert sha(q)==f['sha256'];old=Image.open(q).convert('RGBA');new,count=proc(n,Image.open(raw/f'frame_{n:03d}.png'),old);dst=o/'frames'/f['file'];new.save(dst,optimize=True)
   r=dict(f);r['sha256']=sha(dst);r['trail_alpha_pixels_over_5']=count;records.append(r)
  if a.sample:print('samples',len(records));return
  oldm['source_video']='../bear_lord_tail_trim_20261101/forehand-head-tail-lossless.mov';oldm['source_candidate']='../bear_lord_front_attack_v2';oldm['schema']='board-bear-front-trail-trial-v1';oldm['status']='draft_needs_visual_review';oldm['frames']=records;oldm['trail_method']='source gray veil behind unchanged v2 subject; frames38-51; source right-edge smoothstep width '+os.environ.get('TRAIL_EDGE_WIDTH','24')+' pixels on frames38-51 to preserve transitions; approximate unknown alpha/color'
  (o/'manifest.json').write_text(json.dumps(oldm,indent=2,ensure_ascii=False)+'\n');(o/'audio').mkdir(exist_ok=True);shutil.copyfile(B/'audio/source-track.wav',o/'audio/source-track.wav');assert sha(o/'audio/source-track.wav')==oldm['audio']['sha256']
 print('complete',len(records))
if __name__=='__main__':main()
