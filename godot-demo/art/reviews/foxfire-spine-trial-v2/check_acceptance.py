"""Independent acceptance regression: seams, mixer exercise, foot sole and media."""
import json,math,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from inspect_rig import ROOT,BASE,LEGS,mesh_points,pose,render
from build_rig import sample
D=json.loads((ROOT/'foxfire-v2.json').read_text());Q=json.loads((ROOT/'foxfire-v2-qa.json').read_text())
seq=json.loads((ROOT/'transition-sequence.json').read_text())
results=[];metrics={}
def check(name,value):results.append({'check':name,'passed':bool(value)})
for anim in D['animations']:
 check(anim+' identical in QA input',D['animations'][anim]==Q['animations'][anim])
for anim,duration in [('move_start',1.12),('move_stop',1.12),('qa_switches',seq['duration'])]:
 data=Q if anim=='qa_switches' else D
 a,b=pose(data,anim,0),pose(data,anim,duration)
 err=max(abs(x-y) for n in a for x,y in zip(a[n],b[n]));metrics[anim+'_seam_error']=err
 check(anim+' endpoint matches neutral',err<1e-5)
for leg in LEGS:
 att=D['skins'][0]['attachments'][leg][leg];ids=np.array(att['triangles']).reshape(-1,3)
 def area(p):
  u=p[ids[:,1]]-p[ids[:,0]];v=p[ids[:,2]]-p[ids[:,0]]
  return u[:,0]*v[:,1]-u[:,1]*v[:,0]
 rest=area(mesh_points(D,att,'',0));minratio=1;step=0;previous=None
 for t in np.linspace(0,seq['duration'],round(seq['duration']*60)+1):
  p=mesh_points(Q,att,'qa_switches',float(t));minratio=min(minratio,float(np.min(area(p)/rest)))
  if previous is not None:step=max(step,float(np.linalg.norm(p-previous,axis=1).max())*.085)
  previous=p
 metrics[leg+'_transition_min_area_ratio']=minratio;metrics[leg+'_transition_max_vertex_step_game_px']=step
 check(leg+' no foldover in twenty switches',minratio>.08)
 check(leg+' no discontinuity over 2 game pixels per 60Hz step',step<2)
 # Sole endpoints really follow the foot, not just the ankle pivot.
 sole=np.where(np.array(att['uvs']).reshape(-1,2)[:,1]==1)[0]
 lo,hi=(0,.5) if leg=='leg_back' else (.5,1)
 planted=[]
 for t in np.linspace(lo,hi,61):
  p=mesh_points(D,att,'move',float(t))[sole];p[:,0]-=160*t;planted.append(p)
 drift=float(np.ptp(planted,axis=0).max());metrics[leg+'_sole_stance_drift_source_px']=drift
 check(leg+' sole stays planted',drift<.1)
for anim,duration in [('idle',2000),('move',1000),('basic_attack',1400)]:
 im=Image.open(ROOT/f'external-{anim}.gif');ms=0
 for i in range(im.n_frames):im.seek(i);ms+=im.info['duration']
 check(anim+' preview exact duration',ms==duration)
for anim in ['idle','move']:
 slots=D['animations'][anim]['slots'];check(anim+' projectile explicitly hidden',slots['projectile']['alpha'][0]['value']==0)
# Upper-body attack remains strictly unchanged, including the prior ear clearance fix.
base=json.loads((BASE/'foxfire-external-4.3.json').read_text())
for name,tracks in base['animations']['basic_attack']['bones'].items():
 if name not in LEGS:check('attack unchanged '+name,tracks==D['animations']['basic_attack']['bones'][name])
check('attack slot alpha unchanged',base['animations']['basic_attack']['slots']==D['animations']['basic_attack']['slots'])
report={'status':'passed' if all(x['passed'] for x in results) else 'failed','checks':results,'metrics':metrics,'input_sha256':hashlib.sha256((ROOT/'foxfire-v2.json').read_bytes()).hexdigest()}
(ROOT/'acceptance-checks.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
# Native-scale sample plus enlarged adjacent view; never label as runtime capture.
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',15)
sheet=Image.new('RGB',(1200,600),'#dcd5c5');draw=ImageDraw.Draw(sheet)
for i,(anim,t) in enumerate([('idle',.5),('move',.25),('move',.75),('basic_attack',.3),('basic_attack',.6)]):
 im=render(D,anim,t,.085);sheet.paste(im,(i*240+35,40),im)
 big=render(D,anim,t,.2);sheet.paste(big,(i*240-45,180),big)
 draw.text((i*240+10,10),f'{anim} {t}s',font=font,fill='#302a23')
draw.text((20,550),'EXTERNAL QA / top: 0.085 source scale; bottom: enlarged. Not a game capture.',font=font,fill='#302a23')
sheet.save(ROOT/'qa-game-scale.png')
raise SystemExit(0 if report['status']=='passed' else 1)
