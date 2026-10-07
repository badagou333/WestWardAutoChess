"""Author an independent v3 evaluation rig; does not save/export Spine Trial."""
import copy
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / 'foxfire-spine-trial-v1'
sys.path.insert(0, str(BASE))
from build_sample import pose, multiply, sample

FPS = 60
CYCLE = 1.12
STANCE = .62
STRIDE = 136.0
LIFT = 48.0
SPEED = STRIDE / (STANCE * CYCLE)
DURATIONS = {'idle': 2.4, 'move': CYCLE, 'basic_attack': 1.4,
             'move_start': .68, 'move_stop': .68}
ART_BOUNDS = (156, 35, 957, 1504)
LEG_ART = {'hip': (650, 70), 'knee': (440, 740), 'ankle': (600, 1240),
           'toe': (255, 1425), 'heel': (681, 1362), 'sole': (405, 1450)}
LEGS = {
    'leg_back': {'rect': (425, 911, 190, 312), 'phase': .5},
    'leg_front': {'rect': (428, 915, 207, 340), 'phase': 0},
}

def dump(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def point(p):
    return p[0] - 610, 1255 - p[1]

def angle(a, b):
    return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))

def distance(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])

def smooth(x):
    x = max(0, min(1, x))
    return x * x * (3 - 2 * x)

def local(m, p):
    a, b, c, d, x, y = m
    det = a * d - b * c
    return ((d * (p[0] - x) - c * (p[1] - y)) / det,
            (-b * (p[0] - x) + a * (p[1] - y)) / det)

def art_world(leg, p):
    x, y, w, h = leg['rect']
    x0, y0, x1, y1 = ART_BOUNDS
    return point((x + (p[0] - x0) / (x1 - x0) * w,
                  y + (p[1] - y0) / (y1 - y0) * h))

def solve(hip, ankle, l1, l2):
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = math.hypot(dx, dy)
    if not abs(l1 - l2) < d < l1 + l2:
        raise ValueError(('unreachable ankle', hip, ankle, d, l1 + l2))
    along = (l1*l1 - l2*l2 + d*d) / (2*d)
    height = math.sqrt(max(0, l1*l1 - along*along))
    return (hip[0] + along*dx/d + height*dy/d,
            hip[1] + along*dy/d - height*dx/d)

def foot_motion(t, phase=0):
    p = (t / CYCLE + phase) % 1
    if p <= STANCE:
        return -STRIDE/2 + STRIDE*p/STANCE, 0., 0.
    u = (p - STANCE) / (1 - STANCE)
    # Endpoint tangents match the constant-speed support phase.
    tangent = STRIDE * (1 - STANCE) / STANCE
    ease = 10*u**3 - 15*u**4 + 6*u**5
    x = STRIDE/2 + tangent*u - (STRIDE+tangent)*ease
    lift = 64*LIFT*u**3*(1-u)**3
    roll = 12*math.sin(2*math.pi*u)*math.sin(math.pi*u)**2
    return x, lift, roll

def make_mesh(data, texture, xnodes, ynodes, position, weights):
    """Texture UV grid, with explicit joint rows and a rigid, complete paw."""
    im = Image.open(ROOT/'images'/f'{texture}.png')
    nx, ny = len(xnodes)-1, len(ynodes)-1
    edge = ([(i, 0) for i in range(nx+1)] + [(nx, j) for j in range(1, ny+1)]
            + [(i, ny) for i in range(nx-1, -1, -1)] + [(0, j) for j in range(ny-1, 0, -1)])
    nodes = edge + [(i,j) for j in range(1,ny) for i in range(1,nx)]
    ids = {p:i for i,p in enumerate(nodes)}
    bind = pose(data, '', 0)
    indices = {b['name']:i for i,b in enumerate(data['bones'])}
    uv, vertices, triangles = [], [], []
    for i,j in nodes:
        x,y=xnodes[i],ynodes[j]
        uv.extend((x/im.width,y/im.height))
        ws=[(name,w) for name,w in weights(x,y) if w>1e-8]
        vertices.append(len(ws))
        for name,w in ws:
            lx,ly=local(bind[name],position(x,y))
            vertices.extend((indices[name],round(lx,7),round(ly,7),round(w,9)))
    for j in range(ny):
        for i in range(nx):
            a,b,c,d=[ids[p] for p in [(i,j),(i+1,j),(i,j+1),(i+1,j+1)]]
            triangles.extend((a,c,b,b,c,d))
    # Editor-only topology uses interleaved XY offsets, unlike triangle indices.
    # Preserve every authored triangle edge so import cannot lose internal edges.
    pairs=set()
    for a,b,c in zip(triangles[::3],triangles[1::3],triangles[2::3]):
        pairs.update(tuple(sorted(pair)) for pair in [(a,b),(b,c),(c,a)])
    edges=[index*2 for pair in sorted(pairs) for index in pair]
    return {'type':'mesh','path':texture,'uvs':uv,'triangles':triangles,
            'vertices':vertices,'hull':len(edge),'edges':edges,'width':im.width,'height':im.height}

def setup():
    # Byte copies of unchanged inputs; no raster transforms or repainting here.
    for src in (BASE/'images').glob('*.png'):
        if src.stem not in LEGS:
            shutil.copyfile(src, ROOT/'images'/src.name)
    data=json.loads((BASE/'foxfire-external-4.3.json').read_text())
    data['skeleton'].update(images='./images/',fps=60)
    pelvis=point((550,940))
    data['bones'].insert(1, {'name':'pelvis','parent':'root','x':pelvis[0],'y':pelvis[1],'length':40})
    for b in data['bones']:
        if b['name']=='torso':
            b['parent']='pelvis'; b['x']-=pelvis[0]; b['y']-=pelvis[1]
    for name,leg in LEGS.items():
        hip,knee,ankle=[art_world(leg,LEG_ART[p]) for p in ['hip','knee','ankle']]
        a1,a2=angle(hip,knee),angle(knee,ankle)
        l1,l2=distance(hip,knee),distance(knee,ankle)
        leg.update(hip=hip,knee=knee,ankle=ankle,a1=a1,a2=a2,l1=l1,l2=l2)
        b=next(b for b in data['bones'] if b['name']==name)
        b.update(parent='pelvis',x=hip[0]-pelvis[0],y=hip[1]-pelvis[1],rotation=a1,length=l1)
        data['bones'].extend([
            {'name':name+'_calf','parent':name,'x':l1,'rotation':a2-a1,'length':l2},
            {'name':name+'_foot','parent':name+'_calf','x':l2,'rotation':-a2,'length':45},
            {'name':name+'_knee','parent':name,'x':l1,'rotation':(a2-a1)/2,'length':50}])
    data['bones'].extend([
        {'name':'coat_hem','parent':'torso','x':30,'y':-190,'length':80},
        {'name':'tail_tip','parent':'tail','x':200,'y':-260,'length':100}])
    next(s for s in data['slots'] if s['name']=='leg_back')['color']='dadadaff'
    atts=data['skins'][0]['attachments']
    for name,leg in LEGS.items():
        def weights(x,y):
            lower=smooth((y-200)/1000)
            foot=smooth((y-700)/400)
            knee=4*lower*(1-lower)*.3
            return [(name,(1-foot)*(1-knee)*(1-lower)),
                    (name+'_calf',(1-foot)*(1-knee)*lower),
                    (name+'_knee',(1-foot)*knee),(name+'_foot',foot)]
        # Broad thigh/calf/knee blending retains the loose trouser shape; the
        # foot blend reaches 100% at texture y=1100 and owns the complete paw.
        atts[name][name]=make_mesh(data,'leg-left',
            [0,156,300,440,570,700,830,957,1014],
            [0,35,220,390,510,620,740,850,920,1000,1100,1240,1380,1504,1550],
            lambda x,y:art_world(leg,(x,y)),weights)
    # Cloth drape follows the pelvis with a small delayed hem response.
    layouts=json.loads((BASE/'parts-layout.json').read_text())
    for name,child,lo,hi in [('torso','coat_hem',650,1050),('tail','tail_tip',130,315)]:
        x,y,w,h=layouts[name]['target'];iw,ih=layouts[name]['pixels']
        atts[name][name]=make_mesh(data,name,
            [iw*i/6 for i in range(7)],[ih*j/12 for j in range(13)],
            lambda u,v,x=x,y=y,w=w,h=h,iw=iw,ih=ih:point((x+w*u/iw,y+h*v/ih)),
            lambda u,v,name=name,child=child,lo=lo,hi=hi:[(name,1-smooth((v-lo)/(hi-lo))),(child,smooth((v-lo)/(hi-lo)))])
    return data

def value(keys,t):
    for (ta,va),(tb,vb) in zip(keys,keys[1:]):
        if ta<=t<=tb:return va+(vb-va)*smooth((t-ta)/(tb-ta))
    return keys[0][1] if t<keys[0][0] else keys[-1][1]

def leg_state(leg, pelvis, foot_offset=(0,0,0)):
    hx,hy=leg['hip'];hip=(hx+pelvis[0],hy+pelvis[1])
    ax,ay=leg['ankle'];dx,dy,roll=foot_offset;ankle=(ax+dx,ay+dy)
    knee=solve(hip,ankle,leg['l1'],leg['l2'])
    a1,a2=angle(hip,knee),angle(knee,ankle)
    return (a1-leg['a1'],a2-a1-(leg['a2']-leg['a1']),roll-a2+leg['a2'])

def create_animations(data):
    base=copy.deepcopy(data['animations']['basic_attack'])
    data['animations']={}
    fields={'rotate':{'value':0},'translate':{'x':0,'y':0},'scale':{'x':1,'y':1}}
    def neutral():
        return {b['name']:{c:dict(v) for c,v in fields.items()} for b in data['bones']}
    def frame(anim,t):
        s=neutral();pel=(0.,0.)
        if anim=='idle':
            p=t/DURATIONS['idle'];w=math.sin(2*math.pi*p)
            # Whole body breathes slightly while the feet retain ground contact.
            pel=(0,1.5*w)
            s['torso']['rotate']['value']=.25*w
            s['head']['rotate']['value']=-.45*w
            s['tail']['rotate']['value']=1.5*math.sin(2*math.pi*p)
            s['tail_tip']['rotate']['value']=2*(math.sin(2*math.pi*p-.45)-math.sin(-.45))
            s['scarf']['rotate']['value']=.8*w
            s['coat_hem']['rotate']['value']=.25*w
            s['hand_cast']['rotate']['value']=.5*w
            s['flame']['scale']={'x':1+.018*w,'y':1-.022*w}
        elif anim=='move':
            p=t/CYCLE;w=math.sin(2*math.pi*p)
            pel=(2*w,-7*math.cos(4*math.pi*p))
            s['torso']['rotate']['value']=1.5+.6*w
            s['head']['rotate']['value']=-1.0-.75*w
            s['arm_cast']['rotate']['value']=-1.7*w
            s['hand_cast']['rotate']['value']=1.0*w
            s['arm_rest']['rotate']['value']=5.5*math.sin(2*math.pi*p-.2)
            s['hand_rest']['rotate']['value']=-2*math.sin(2*math.pi*p-.55)
            s['tail']['rotate']['value']=2.2*math.sin(2*math.pi*p-.5)
            s['tail_tip']['rotate']['value']=3.2*math.sin(2*math.pi*p-.95)
            s['scarf']['rotate']['value']=2.8*math.sin(2*math.pi*p-.65)
            s['coat_hem']['rotate']['value']=1.6*math.sin(2*math.pi*p-.4)
            s['flame']['rotate']['value']=-s['torso']['rotate']['value']+.7*w
            s['flame']['scale']={'x':1+.012*w,'y':1-.015*w}
        elif anim=='basic_attack':
            pel=(value([(0,0),(.3,9),(.48,-12),(.7,-3),(1.15,0),(1.4,0)],t),
                 value([(0,0),(.3,-5),(.48,-2),(.7,-1),(1.15,0),(1.4,0)],t))
            for n,tracks in base['bones'].items():
                if n in LEGS or n=='projectile':continue
                for c,keys in tracks.items():
                    for prop,default in fields[c].items():
                        s[n][c][prop]=value([(k.get('time',0),k.get(prop,default)) for k in keys],t)
            s['torso']['translate']={'x':0,'y':0}
            s['tail_tip']['rotate']['value']=value([(0,0),(.38,-2),(.73,3),(1.4,0)],t)
            s['coat_hem']['rotate']['value']=value([(0,0),(.33,-1),(.56,1.2),(1.4,0)],t)
        s['pelvis']['translate']={'x':pel[0],'y':pel[1]}
        for name,leg in LEGS.items():
            offset=foot_motion(t,leg['phase']) if anim=='move' else (0,0,0)
            angles=leg_state(leg,pel,offset)
            for n,r in zip([name,name+'_calf',name+'_foot'],angles):s[n]['rotate']['value']=r
            s[name+'_knee']['rotate']['value']=angles[1]/2
        return s
    def bake(anim,duration,fn):
        times=[round(i*duration/math.ceil(duration*FPS),7) for i in range(math.ceil(duration*FPS)+1)]
        if anim=='move':
            # Tiny contact neighborhoods preserve authored C2 timing despite
            # piecewise-linear imported keys; the main sampling remains 60 Hz.
            for contact in [0,CYCLE*.12,CYCLE*.5,CYCLE*STANCE,CYCLE]:
                times.extend(round(contact+dt,7) for dt in [-.002,-.001,0,.001,.002] if 0<=contact+dt<=duration)
        if anim=='basic_attack':times.extend([.3,.479,.48,.7,1.05,1.25])
        times=sorted(set(times))
        tracks={b['name']:{c:[] for c in fields} for b in data['bones']}
        for t in times:
            state=fn(t)
            for b in tracks:
                for c in fields:tracks[b][c].append({'time':t,**{p:round(v,7) for p,v in state[b][c].items()}})
        data['animations'][anim]={'bones':tracks,'slots':{
            'flame':{'alpha':[{'time':0,'value':1}]},
            'projectile':{'alpha':[{'time':0,'value':0}]}}}
    for anim in ['idle','move','basic_attack']:
        bake(anim,DURATIONS[anim],lambda t,anim=anim:frame(anim,t))
    attack=data['animations']['basic_attack']
    attack['slots']=base['slots'];attack['events']=base['events']
    # The fire actually originates at the newly authored hand at the release time.
    m=pose(data,'basic_attack',.48)['flame']
    b=next(b for b in data['bones'] if b['name']=='projectile')
    r=math.degrees(math.atan2(m[1],m[0]));sx=math.hypot(m[0],m[1]);sy=math.hypot(m[2],m[3])
    attack['bones']['projectile']={
        'rotate':[{'time':0,'value':0},{'time':.479,'value':r},{'time':.48,'value':r},{'time':.95,'value':r},{'time':1.4,'value':0}],
        'translate':[{'time':0,'x':0,'y':0},{'time':.479,'x':m[4]-b['x'],'y':m[5]-b['y']},{'time':.48,'x':m[4]-b['x'],'y':m[5]-b['y']},{'time':.95,'x':m[4]-b['x']-380,'y':m[5]-b['y']+35},{'time':1.4,'x':0,'y':0}],
        'scale':[{'time':0,'x':1,'y':1},{'time':.48,'x':sx,'y':sy},{'time':.95,'x':.85,'y':.85},{'time':1.4,'x':1,'y':1}]}
    # Explicit transitions: one foot moves at a time. They are preview paths,
    # with their own easing displacement contract, not arbitrary runtime blends.
    for anim in ['move_start','move_stop']:
        duration=DURATIONS[anim]
        def transition(t,anim=anim):
            u=t/duration
            if anim=='move_start':
                weight=smooth(u);a=frame('idle',0);b=frame('move',0)
            else:
                weight=smooth(u);a=frame('move',0);b=frame('idle',0)
            s=neutral()
            for n in s:
                for c in fields:
                    for p in fields[c]:s[n][c][p]=a[n][c][p]*(1-weight)+b[n][c][p]*weight
            pel=tuple(s['pelvis']['translate'][p] for p in ['x','y'])
            for i,(name,leg) in enumerate(LEGS.items()):
                # Back then front: no simultaneous skate from standing to stride.
                k=smooth((u-i*.5)*2)
                x,y,roll=foot_motion(0,leg['phase'])
                offset=(x*k,y*k,roll*k) if anim=='move_start' else (x*(1-k),y*(1-k),roll*(1-k))
                lift=20*math.sin(math.pi*max(0,min(1,(u-i*.5)*2)))**2
                offset=(offset[0],offset[1]+lift,offset[2])
                rr=leg_state(leg,pel,offset)
                for n,r in zip([name,name+'_calf',name+'_foot'],rr):s[n]['rotate']['value']=r
                s[name+'_knee']['rotate']['value']=rr[1]/2
            return s
        bake(anim,duration,transition)
    return data

def build():
    data=create_animations(setup())
    dump('foxfire-v3.json',data)
    dump('rig-notes.json',{'origin':'Externally authored input, not saved/exported from Spine Trial',
        'cycle_seconds':CYCLE,'stance_fraction':STANCE,'stride_source_px':STRIDE,
        'speed_source_px_per_second':SPEED,'lift_source_px':LIFT,'durations':DURATIONS,
        'legs':LEGS,'visible_landmarks_image_px':LEG_ART,'art_alpha_bounds':ART_BOUNDS,
        'art_sha256':hashlib.sha256((ROOT/'images/leg-left.png').read_bytes()).hexdigest(),
        'geometry_note':'Independent contact walk. Idle does not have to equal move[0]. Complete paw rigid below texture y=1100. Landmarks must be verified opaque.'})
    print('Authored v3:',len(data['bones']),'bones;',len(data['animations']),'animations')
    return data

if __name__=='__main__':build()
