#!/usr/bin/env python3
"""Transparent matte for the approved C3 pale-background clip.
This is clip-specific, not a universal background remover. No generation.
"""
from pathlib import Path
import argparse, json, time
from PIL import Image
import numpy as np
from scipy import ndimage as ndi

def matte(img):
 rgb=np.asarray(img.convert('RGB'),dtype=np.float32)
 h,w=rgb.shape[:2]
 border=np.concatenate([rgb[-30:,:,:].reshape(-1,3),rgb[:,-30:,:].reshape(-1,3),
                        rgb[120:,:30,:].reshape(-1,3),rgb[:20,200:,:].reshape(-1,3)])
 bg=np.median(border,axis=0)
 d=np.sqrt(np.mean((rgb-bg)**2,axis=2))
 a=np.clip((d-6)/18,0,1)
 solid=d>24
 # Label is outside subject in this approved clip; original remains in source.
 solid[:110,:180]=False
 labels,n=ndi.label(solid)
 counts=np.bincount(labels.ravel())
 if len(counts)<2: raise ValueError('No subject component found')
 body=labels==(1+np.argmax(counts[1:]))
 holes=ndi.binary_fill_holes(body)&~body
 components,n=ndi.label(holes)
 slices=ndi.find_objects(components)
 chroma=rgb.max(axis=2)-rgb.min(axis=2)
 records=[]
 for i,sl in enumerate(slices,1):
  if sl is None:continue
  reg=components[sl]==i
  count=int(reg.sum())
  med=float(np.median(chroma[sl][reg]))
  keep=med>=12.0
  view=a[sl];view[reg]=1.0 if keep else 0.0
  if count>=100:
   records.append({'pixels':count,'median_rgb_range':round(med,2),
                   'decision':'keep_warm_colored' if keep else 'clear_neutral_uncertain',
                   'bbox':[sl[1].start,sl[0].start,sl[1].stop,sl[0].stop]})
 a[:110,:180]=0
 alpha_safe=np.maximum(a,0.1)
 band=(a>0)&(a<0.97)
 color=rgb.copy()
 color[band]=np.clip((rgb[band]-(1-a[band,None])*bg)/alpha_safe[band,None],0,255)
 color[a==0]=0
 rgba=np.dstack([color.astype(np.uint8),(a*255+0.5).astype(np.uint8)])
 return Image.fromarray(rgba,'RGBA'), {'estimated_background_rgb':bg.tolist(),
   'solid_component_pixels':int(body.sum()),'large_closed_regions':records,
   'zero_alpha_pixels':int((rgba[:,:,3]==0).sum()),'partial_alpha_pixels':int(((rgba[:,:,3]>0)&(rgba[:,:,3]<255)).sum())}

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--input',type=Path,required=True)
 parser.add_argument('--output',type=Path,required=True)
 parser.add_argument('--report',type=Path,required=True)
 args=parser.parse_args()
 if args.output.exists() and any(args.output.iterdir()):raise SystemExit('output directory is nonempty')
 args.output.mkdir(parents=True,exist_ok=True)
 files=sorted(args.input.glob('frame_*.png'))
 if len(files)!=98:raise SystemExit(f'Expected 98 frames, got {len(files)}')
 report=[]
 for index,path in enumerate(files):
  img=Image.open(path)
  if img.size!=(960,960):raise SystemExit(f'Unexpected size {path}: {img.size}')
  result,info=matte(img)
  result.save(args.output/path.name,compress_level=6)
  info['index']=index;info['file']=path.name;report.append(info)
  if index%10==0:print(f'matted {index+1}/98',flush=True)
 args.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print('matted 98/98',flush=True)
if __name__=='__main__':main()
