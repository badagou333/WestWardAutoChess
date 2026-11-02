#!/usr/bin/env python3
"""Reproduce the previously reviewed alpha-only masks for frames 30–32.
Operates only on an external rebuilt frames directory, never on packaged frames.
"""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from scipy.ndimage import binary_dilation, gaussian_filter

frames=Path(sys.argv[1])
regions={30:[(130,301),(335,305),(418,350),(418,395),(335,418),(235,417),(180,394),(145,358)],31:[(40,320),(318,310),(385,345),(384,430),(350,471),(275,485),(205,478),(145,448),(90,424),(50,385)],32:[(220,495),(288,501),(323,537),(305,575),(280,596),(226,588)]}
for i,region in regions.items():
 path=frames/f'frame_{i:06d}.png'
 im=Image.open(path).convert('RGBA'); a=np.array(im); old=a[:,:,3].astype(float)
 mask=Image.new('L',im.size); ImageDraw.Draw(mask).polygon(region,fill=255)
 mask=mask.filter(ImageFilter.GaussianBlur(9)); area=np.asarray(mask,dtype=float)/255
 hard=binary_dilation(old>=210,iterations=18); guard=gaussian_filter(hard.astype(float),sigma=5)
 change=area*(1-guard)*0.92
 a[:,:,3]=np.rint(old*(1-change)).astype('uint8')
 Image.fromarray(a).save(path)
