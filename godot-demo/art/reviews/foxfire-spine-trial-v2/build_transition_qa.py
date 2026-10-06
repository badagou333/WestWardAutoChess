"""Bake a reproducible visual mixer exercise; not production/runtime integration."""
import copy,json
from build_rig import ROOT,sample,smooth,FPS

def build_qa(data):
 qa=copy.deepcopy(data)
 fields={'rotate':{'value':0},'translate':{'x':0,'y':0},'scale':{'x':1,'y':1}}
 channels={b['name']:{c:[] for c in fields} for b in data['bones']}
 slots={s['name']:{'alpha':[]} for s in data['slots']}
 sequence=[];clock=0
 def sample_state(anim,t):
  a=data['animations'][anim];state={}
  duration={'idle':2,'move':1,'basic_attack':1.4}[anim]
  t=t%duration if anim in ['idle','move'] else min(t,duration)
  for b in channels:
   tracks=a.get('bones',{}).get(b,{})
   state[b]={c:{p:sample(tracks.get(c),t,p,d) for p,d in props.items()} for c,props in fields.items()}
  state['slots']={s['name']:sample(a.get('slots',{}).get(s['name'],{}).get('alpha'),t,'value',int(s.get('color','ffffffff')[-2:],16)/255) for s in data['slots']}
  return state
 def add(anim,start,duration,source=None):
  nonlocal clock
  sequence.append({'at':round(clock,6),'animation':anim,'start':start,'duration':duration,'mix_from':source})
  count=round(duration*FPS)
  for i in range(count+1):
   if clock and i==0:continue
   dt=duration*i/count;t=round(clock+dt,7);a=sample_state(anim,start+dt)
   if source:
    old=sample_state(source[0],source[1]+dt);w=smooth(dt/duration)
    for b in channels:
     for c,props in fields.items():
      for p in props:a[b][c][p]=old[b][c][p]*(1-w)+a[b][c][p]*w
    for slot in slots:a['slots'][slot]=old['slots'][slot]*(1-w)+a['slots'][slot]*w
   for b in channels:
    for c in fields:channels[b][c].append({'time':t,**{p:round(v,7) for p,v in a[b][c].items()}})
   for slot in slots:slots[slot]['alpha'].append({'time':t,'value':round(a['slots'][slot],7)})
  clock+=duration
 for phase in [.2,.4,.6,.8,1]:
  add('idle',0,.4)
  add('move',0,.2,('idle',.4))
  if phase>.2:add('move',.2,phase-.2)
  add('idle',0,.2,('move',phase))
  add('idle',.2,.4)
  add('basic_attack',0,.2,('idle',.6))
  add('basic_attack',.2,1.2)
  add('idle',0,.2,('basic_attack',1.4))
  # Finish idle cycle at its neutral pose before repeat.
  add('idle',.2,1.8)
 qa['animations']['qa_switches']={'bones':channels,'slots':slots}
 (ROOT/'foxfire-v2-qa.json').write_text(json.dumps(qa,ensure_ascii=False,separators=(',',':'))+'\n')
 (ROOT/'transition-sequence.json').write_text(json.dumps({'duration':clock,'mix_seconds':.2,'switches':20,'scope':'Baked local-transform mixer exercise; actual runtime mixer must be checked on integration','segments':sequence},indent=2)+'\n')
 return qa
if __name__=='__main__':build_qa(json.loads((ROOT/'foxfire-v2.json').read_text()))
