"""Diagnostic layout overlay only; does not alter the hand-painted source or game."""
from PIL import Image, ImageDraw
from pathlib import Path
ROOT=Path(__file__).resolve().parent
ART_ROOT=ROOT.parents[2]
im=Image.open(ROOT.parent/'board-courtyard.png').convert('RGBA').resize((1920,1080),Image.Resampling.LANCZOS)
overlay=Image.new('RGBA',im.size);d=ImageDraw.Draw(overlay)
d.rectangle((220,190,879,903),fill=(68,115,107,12))
d.rectangle((880,190,1539,903),fill=(137,72,55,9))
for col in range(13):d.line((220+col*110,190,220+col*110,904),fill=(54,56,47,105),width=2)
for row in range(8):d.line((220,190+row*102,1540,190+row*102),fill=(54,56,47,105),width=2)
d.rectangle((220,190,1540,904),outline=(176,151,94,255),width=3)
for y in range(190,904,18):d.line((880,y,880,min(y+9,904)),fill=(218,184,104,190),width=3)
# Sample Manhattan range, selected footprint. This is not gameplay state.
for row in range(7):
 for col in range(12):
  if abs(col-4)+abs(row-4)<=2:
   x=220+110*col;y=190+102*row;d.rectangle((x+3,y+3,x+107,y+99),fill=(117,166,182,22))
d.rectangle((660,598,770,700),outline=(246,207,113,255),width=3)
im=Image.alpha_composite(im,overlay)
ref=Image.open(ART_ROOT/'production/foxfire_imp/nine_sols_v1/source-clean.png').convert('RGBA')
sprite=ref.resize((round(ref.width*.085),round(ref.height*.085)),Image.Resampling.LANCZOS)
im.alpha_composite(sprite,(round(715-610*.085),round(649-1255*.085)))
d=ImageDraw.Draw(im)
d.rounded_rectangle((683,527,747,535),radius=2,fill='#252C27',outline='#D3C19A',width=1)
d.rectangle((685,529,745,533),fill='#90B883')
for box in ((18,145,200,905),(1560,160,1900,1010),(0,0,1920,92),(210,940,1545,1060)):
 d.rounded_rectangle(box,radius=6,fill=(36,40,34,235),outline='#766E56',width=1)
im.resize((1280,720),Image.Resampling.LANCZOS).convert('RGB').save(ROOT/'after-layout-overlay-720p.png')
# Captions are diagnostic, not baked into the candidate painting.
out=Image.open(ROOT/'after-layout-overlay-720p.png');d=ImageDraw.Draw(out)
d.text((18,20),'OFFLINE ART OVERLAY - NOT GAME INTEGRATION',fill='#F1E5CD')
d.text((1046,118),'UI SAFE AREA',fill='#F1E5CD')
d.text((155,640),'84 CELLS / LOGICAL GEOMETRY UNCHANGED',fill='#F1E5CD')
out.save(ROOT/'after-layout-overlay-720p.png')
print('Preview only: 1280x720, no source edits, no game changes.')
