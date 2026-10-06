"""Independent weighted-mesh inspection and regression checks (not Spine output)."""
import json,math,copy
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from build_rig import ROOT,BASE,LAYOUT,LEGS,pose,multiply,foot_motion,point,SPEED
from build_sample import render as region_render

def mesh_points(data,att,anim,t):
 mats=pose(data,anim,t);names=[b['name'] for b in data['bones']]
 result=[];values=iter(att['vertices'])
 for _ in range(len(att['uvs'])//2):
  x=y=0
  for _ in range(int(next(values))):
   idx,lx,ly,w=[next(values) for _ in range(4)]
   a,b,c,d,tx,ty=mats[names[int(idx)]]
   x+=(a*lx+c*ly+tx)*w;y+=(b*lx+d*ly+ty)*w
  result.append((x,y))
 return np.array(result)

def render(data,anim,t,scale=.4):
 canvas=region_render(data,anim,t,scale,only_slots={'tail','scarf'})
 for name in LEGS:
  att=data['skins'][0]['attachments'][name][name]
  im=Image.open(BASE/f'images/{name}.png').convert('RGBA')
  pts=mesh_points(data,att,anim,t)*[scale,-scale]+[850*scale,1320*scale]
  uv=np.array(att['uvs']).reshape(-1,2)*[im.width,im.height]
  layer=Image.new('RGBA',canvas.size)
  for ids in np.array(att['triangles']).reshape(-1,3):
   dst=pts[ids];src=uv[ids]
   x0,y0=np.floor(dst.min(axis=0)).astype(int);x1,y1=np.ceil(dst.max(axis=0)).astype(int)+1
   if x1<=x0 or y1<=y0:continue
   mat=np.column_stack([dst-[x0,y0],np.ones(3)])
   if abs(np.linalg.det(mat))<1e-6:continue
   inv=np.linalg.solve(mat,src)
   patch=im.transform((x1-x0,y1-y0),Image.Transform.AFFINE,tuple(inv[:,0])+tuple(inv[:,1]),Image.Resampling.BICUBIC)
   mask=Image.new('L',patch.size);ImageDraw.Draw(mask).polygon([tuple(v) for v in dst-[x0,y0]],fill=255)
   # Copy triangles into a common layer so shared edges do not double-alpha.
   layer.paste(patch,(x0,y0),mask)
  canvas.alpha_composite(layer)
 others={s['name'] for s in data['slots']}-set(LEGS)-{'tail','scarf'}
 canvas.alpha_composite(region_render(data,anim,t,scale,only_slots=others))
 return canvas

def checks(data):
 results=[];metrics={}
 def check(n,v):results.append({'check':n,'passed':bool(v)})
 base=json.loads((BASE/'foxfire-external-4.3.json').read_text())
 check('head and upper body attachments unchanged',all(data['skins'][0]['attachments'][s]==a for s,a in base['skins'][0]['attachments'].items() if s not in LEGS))
 check('attack event timing unchanged',data['animations']['basic_attack']['events']==base['animations']['basic_attack']['events'])
 seen=set()
 for b in data['bones']:
  check('parent-first unique bone '+b['name'],b['name'] not in seen and ('parent' not in b or b['parent'] in seen));seen.add(b['name'])
 for anim,duration in [('idle',2),('move',1),('basic_attack',1.4)]:
  a,b=pose(data,anim,0),pose(data,anim,duration)
  err=max(abs(x-y) for n in a for x,y in zip(a[n],b[n]))
  metrics[anim+'_seam_matrix_error']=err
  check(anim+' exact loop/return pose',err<1e-5)
 idle=pose(data,'idle',0);move=pose(data,'move',0)
 err=max(abs(x-y) for n in idle for x,y in zip(idle[n],move[n]))
 metrics['idle_move_start_error']=err;check('idle/move boundary all bones match',err<1e-5)
 for name,leg in LEGS.items():
  att=data['skins'][0]['attachments'][name][name]
  pts=mesh_points(data,att,'',0);uv=np.array(att['uvs']).reshape(-1,2)
  x,y,w,h=LAYOUT[name]['target']
  expected=uv*[w,-h]+[x-610,1255-y]
  err=float(np.max(np.abs(pts-expected)))
  metrics[name+'_bind_error']=err;check(name+' bind shape preserves original art',err<1e-5)
  # Stable foot in translating reference frame, excluding lift-off boundary.
  lo,hi=(0,.5) if not leg['phase'] else (.5,1)
  feet=[]
  for i in range(121):
   t=lo+(hi-lo)*i/121
   m=pose(data,'move',t)[name+'_foot'];feet.append((m[4]-SPEED*t,m[5]))
  spread=np.ptp(feet,axis=0);metrics[name+'_stance_spread_source_px']=spread.tolist()
  check(name+' planted foot drift below 0.1 source pixel',float(spread.max())<.1)
  k=data['animations']['move']['bones'][name+'_calf']['rotate']
  rom=max(v['value'] for v in k)-min(v['value'] for v in k)
  metrics[name+'_knee_range_deg']=rom;check(name+' articulated knee exceeds 15 degrees',rom>15)
  ids=np.array(att['triangles']).reshape(-1,3)
  def areas(p):
   u=p[ids[:,1]]-p[ids[:,0]];v=p[ids[:,2]]-p[ids[:,0]]
   return u[:,0]*v[:,1]-u[:,1]*v[:,0]
  rest=areas(pts);ratio=1
  for i in range(121):ratio=min(ratio,float(np.min(areas(mesh_points(data,att,'move',i/120))/rest)))
  metrics[name+'_min_triangle_area_ratio']=ratio
  check(name+' no mesh foldover through walk',ratio>.08)
 report={'status':'passed' if all(r['passed'] for r in results) else 'failed','scope':'Independent geometry QA, not native capture or final visual acceptance','checks':results,'metrics':metrics}
 (ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(report['status'],len(results),'checks');print(json.dumps(metrics,indent=2))
 return report

def previews(data):
 font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',16)
 sheet=Image.new('RGB',(1600,700),'#ded8ca');draw=ImageDraw.Draw(sheet)
 for i,t in enumerate([0,.125,.25,.375,.5,.625,.75,.875]):
  im=render(data,'move',t,.17);sheet.paste(im,(i*200-30,20),im)
  draw.text((i*200+10,10),f'move {t:.3f}s',fill='#302a23',font=font)
  # Joint inspection at larger size, from the actual weighted renderer.
  detail=render(data,'move',t,.6).crop((320,520,630,820));detail.thumbnail((195,240))
  sheet.paste(detail,(i*200,360),detail)
 draw.text((20,660),'EXTERNAL WEIGHTED-MESH QA — not a Spine capture',fill='#302a23',font=font)
 sheet.save(ROOT/'qa-walk-contact.png')
 for anim,duration in [('idle',2),('move',1),('basic_attack',1.4)]:
  frames=[]
  for i in range(round(duration*25)):
   im=render(data,anim,i/25,.35);bg=Image.new('RGB',im.size,'#ded8ca');bg.paste(im,(0,0),im)
   ImageDraw.Draw(bg).text((10,8),'EXTERNAL QA / '+anim,fill='#302a23',font=font);frames.append(bg)
  frames[0].save(ROOT/f'external-{anim}.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)

if __name__=='__main__':
 data=json.loads((ROOT/'foxfire-v2.json').read_text());report=checks(data)
 previews(data)
 raise SystemExit(0 if report['status']=='passed' else 1)
