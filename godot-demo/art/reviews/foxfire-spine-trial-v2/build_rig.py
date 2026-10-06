"""Author weighted leg rig and smooth, planted gait; no raster asset editing."""
import copy,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent/'foxfire-spine-trial-v1'
sys.path.insert(0,str(BASE))
from build_sample import pose,multiply,sample
LAYOUT=json.loads((BASE/'parts-layout.json').read_text())
LEGS={
 'leg_back':{'hip':(485,945),'knee':(400,1070),'ankle':(452,1180),'phase':0},
 'leg_front':{'hip':(605,945),'knee':(550,1080),'ankle':(620,1210),'phase':.5},
}
FPS=60
STRIDE=80
SPEED=160
LIFT=45
def point(p):return (p[0]-610,1255-p[1])
def angle(a,b):return math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
def distance(a,b):return math.hypot(b[0]-a[0],b[1]-a[1])
def local(m,p):
 a,b,c,d,x,y=m;det=a*d-b*c
 return ((d*(p[0]-x)-c*(p[1]-y))/det,(-b*(p[0]-x)+a*(p[1]-y))/det)
def smooth(x):return x*x*(3-2*x)
def foot_motion(t,phase):
 p=(t+phase)%1
 if p<=.5: x=STRIDE*2*p;y=0;roll=0
 else:
  u=(p-.5)*2
  # Cubic Hermite: match stance velocity at lift-off and touchdown.
  x=STRIDE*((2*u**3-3*u*u+1)+(u**3-2*u*u+u)+(u**3-u*u))
  y=LIFT*math.sin(math.pi*u)**2
  roll=-10*math.sin(2*math.pi*u)*math.sin(math.pi*u)
 return x-(STRIDE if phase else 0),y,roll
def solve(hip,ankle,l1,l2):
 dx,dy=ankle[0]-hip[0],ankle[1]-hip[1];d=math.hypot(dx,dy)
 assert abs(l1-l2)<d<l1+l2,(d,l1,l2)
 q=(l1*l1-l2*l2+d*d)/(2*d);h=math.sqrt(max(0,l1*l1-q*q))
 # Negative screen X knee bend (forward for this left-facing character).
 knee=(hip[0]+q*dx/d+h*dy/d,hip[1]+q*dy/d-h*dx/d)
 return knee
def leg_mesh(data,name):
 rec=LAYOUT[name];x,y,w,h=rec['target'];iw,ih=rec['pixels']
 # Rectangular grid; perimeter first, clockwise in UV space.
 nx,ny=4,12
 boundary=[(i,0) for i in range(nx+1)]+[(nx,j) for j in range(1,ny+1)]+[(i,ny) for i in range(nx-1,-1,-1)]+[(0,j) for j in range(ny-1,0,-1)]
 nodes=boundary+[(i,j) for j in range(1,ny) for i in range(1,nx)]
 ids={p:i for i,p in enumerate(nodes)};uvs=[];vertices=[];tri=[]
 bind=pose(data,'',0);indices={b['name']:i for i,b in enumerate(data['bones'])}
 knee=LEGS[name]['knee'][1];ankle=LEGS[name]['ankle'][1]
 for i,j in nodes:
  u,v=i/nx,j/ny;uvs.extend((u,v));px,py=x+w*u,y+h*v
  lower=smooth(max(0,min(1,(py-knee+100)/200)))
  foot=smooth(max(0,min(1,(py-ankle+100)/130)))
  weights=[(name,1-lower),(name+'_calf',lower*(1-foot)),(name+'_foot',lower*foot)]
  weights=[(n,w) for n,w in weights if w>1e-8]
  vertices.append(len(weights))
  for n,weight in weights:
   lx,ly=local(bind[n],point((px,py)))
   vertices.extend((indices[n],round(lx,7),round(ly,7),round(weight,9)))
 for j in range(ny):
  for i in range(nx):
   a,b,c,d=[ids[p] for p in [(i,j),(i+1,j),(i,j+1),(i+1,j+1)]]
   tri.extend((a,c,b,b,c,d))
 return {'type':'mesh','path':name,'uvs':uvs,'triangles':tri,'vertices':vertices,'hull':len(boundary),'width':iw,'height':ih}
def build():
 data=json.loads((BASE/'foxfire-external-4.3.json').read_text())
 data['skeleton']['images']='../foxfire-spine-trial-v1/images/'
 # Existing thigh bones keep their names; add child calf/foot bones.
 for name,leg in LEGS.items():
  hip,knee,ankle=map(point,(leg['hip'],leg['knee'],leg['ankle']))
  a1=angle(hip,knee);a2=angle(knee,ankle);l1=distance(hip,knee);l2=distance(knee,ankle)
  b=next(b for b in data['bones'] if b['name']==name)
  b.update(rotation=a1,length=l1)
  data['bones'].extend([
   {'name':name+'_calf','parent':name,'x':l1,'rotation':a2-a1,'length':l2},
   {'name':name+'_foot','parent':name+'_calf','x':l2,'rotation':-a2,'length':40}])
  leg.update(a1=a1,a2=a2,l1=l1,l2=l2)
 # Rig must be complete before weighted indices and inverse bind coordinates.
 for name in LEGS:data['skins'][0]['attachments'][name][name]=leg_mesh(data,name)
 move=data['animations']['move']['bones']
 for name,leg in LEGS.items():
  tracks={n:{'rotate':[]} for n in [name,name+'_calf',name+'_foot']}
  tracks[name]['translate']=[]
  for i in range(FPS+1):
   t=i/FPS;bob=5*math.sin(2*math.pi*t)**2
   hx,hy=point(leg['hip']);hip=(hx,hy+bob)
   ax,ay=point(leg['ankle']);dx,dy,roll=foot_motion(t,leg['phase']);ankle=(ax+dx,ay+dy)
   knee=solve(hip,ankle,leg['l1'],leg['l2']);a1=angle(hip,knee);a2=angle(knee,ankle)
   for n,v in [(name,a1-leg['a1']),(name+'_calf',(a2-a1)-(leg['a2']-leg['a1'])),(name+'_foot',roll-a2+leg['a2'])]:
    tracks[n]['rotate'].append({'time':round(t,7),'value':round(v,7)})
   tracks[name]['translate'].append({'time':round(t,7),'x':0,'y':round(bob,7)})
  move.update(tracks)
 move['torso']['translate']=[{'time':round(i/FPS,7),'x':0,'y':round(5*math.sin(2*math.pi*i/FPS)**2,7)} for i in range(FPS+1)]
 # Explicit zero keys prevent leg offsets carrying into idle/attack on a mixer.
 for anim in ['idle','basic_attack']:
  duration=2 if anim=='idle' else 1.4
  for name in LEGS:
   for bone in [name,name+'_calf',name+'_foot']:
    data['animations'][anim]['bones'][bone]={'rotate':[{'time':0,'value':0},{'time':duration,'value':0}]}
   data['animations'][anim]['bones'][name]['translate']=[{'time':0,'x':0,'y':0},{'time':duration,'x':0,'y':0}]
 # All animations key visible fire state; avoid residual projectile after switches.
 for anim in ['idle','move']:
  data['animations'][anim]['slots']={
   'flame':{'alpha':[{'time':0,'value':1}]},
   'projectile':{'alpha':[{'time':0,'value':0}]}}
 # Complete one gait cycle while accelerating/decelerating over 0.24 s.
 # Queue stop at the next cycle boundary; do not cut a planted foot mid-stride.
 ramp=.24;duration=1+ramp/2
 def start_phase(t):
  if t>=ramp:return t-ramp/2
  u=t/ramp
  return ramp*(u**3-.5*u**4)
 for name in ['move_start','move_stop']:
  tracks={}
  count=round(duration*FPS)
  for bone,channels in data['animations']['move']['bones'].items():
   tracks[bone]={}
   for channel,keys in channels.items():
    props={'rotate':['value'],'translate':['x','y'],'scale':['x','y']}[channel]
    tracks[bone][channel]=[]
    for i in range(count+1):
     t=duration*i/count
     phase=start_phase(t) if name=='move_start' else 1-start_phase(duration-t)
     value={'time':round(t,7)}
     value.update({p:round(sample(keys,max(0,min(1,phase)),p,1 if channel=='scale' else 0),7) for p in props})
     tracks[bone][channel].append(value)
  data['animations'][name]={'bones':tracks,'slots':copy.deepcopy(data['animations']['move']['slots'])}
 (ROOT/'foxfire-v2.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 return data
if __name__=='__main__':
 data=build();print('Authored',len(data['bones']),'bones, two weighted leg meshes')
