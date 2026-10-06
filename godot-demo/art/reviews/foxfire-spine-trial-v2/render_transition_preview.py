"""One representative switch exercise preview. External renderer, not Spine capture."""
import json
from PIL import Image,ImageDraw,ImageFont
from inspect_rig import ROOT,render
q=json.loads((ROOT/'foxfire-v2-qa.json').read_text())
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',14)
frames=[]
# First block is 4.6 seconds: idle -> move -> idle -> attack -> idle.
for i in range(115):
 t=i/25;im=render(q,'qa_switches',t,.25);bg=Image.new('RGB',im.size,'#ded8ca');bg.paste(im,(0,0),im)
 d=ImageDraw.Draw(bg);d.text((8,8),'EXTERNAL QA / 0.2s smooth mix',font=font,fill='#302a23')
 d.text((8,28),f'Idle / move / idle / attack / idle   {t:.2f}s',font=font,fill='#302a23');frames.append(bg)
frames[0].save(ROOT/'external-transitions.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)
