"""Build a deterministic authored transition exercise and external review media."""
import copy
import hashlib
import json
import math
from pathlib import Path
from PIL import Image,ImageDraw
from build_rig import ROOT,CYCLE,DURATIONS,SPEED,FPS,sample
from render_preview import load_data,render,_font,_save_gif,BACKGROUND

def build_flow():
    data=json.loads((ROOT/'foxfire-v3.json').read_text())
    qa=copy.deepcopy(data)
    channels={'rotate':{'value':0},'translate':{'x':0,'y':0},'scale':{'x':1,'y':1}}
    bones={b['name']:{c:[] for c in channels} for b in data['bones']}
    slots={name:{'alpha':[]} for name in ['flame','projectile']}
    segments=[];clock=0;events=[]
    for iteration in range(2):
        sequence=[('idle',.4,True),('move_start',DURATIONS['move_start'],False),
                  ('move',CYCLE,False),('move',CYCLE,False),
                  ('move_stop',DURATIONS['move_stop'],False),('idle',.4,True),
                  ('basic_attack',1.4,False),('idle',.5,True)]
        for name,duration,hold in sequence:
            a=data['animations'][name]
            segments.append({'at':round(clock,7),'animation':name,'duration':duration,'hold_neutral':hold})
            times=set([i*duration/math.ceil(duration*FPS) for i in range(math.ceil(duration*FPS)+1)])
            if not hold:
                for tracks in a['bones'].values():
                    for keys in tracks.values():times.update(k.get('time',0) for k in keys)
                for e in a.get('events',[]):events.append({**e,'time':round(clock+e['time'],7)})
            for t in sorted(times):
                if clock>0 and t==0:continue
                at=round(clock+t,7);source_t=0 if hold else t
                for bone in bones:
                    for channel,props in channels.items():
                        keys=a['bones'].get(bone,{}).get(channel)
                        bones[bone][channel].append({'time':at,**{p:round(sample(keys,source_t,p,d),7) for p,d in props.items()}})
                for slot in slots:
                    keys=a.get('slots',{}).get(slot,{}).get('alpha')
                    slots[slot]['alpha'].append({'time':at,'value':sample(keys,source_t,'value',1 if slot=='flame' else 0)})
            clock+=duration
    qa['animations']['qa_flow']={'bones':bones,'slots':slots,'events':events}
    (ROOT/'foxfire-v3-qa.json').write_text(json.dumps(qa,ensure_ascii=False,separators=(',',':'))+'\n')
    meta={'duration':round(clock,7),'switches':12,
          'scope':'Two authored start/walk/stop/attack sequences; not a runtime crossfade or arbitrary interrupt test.',
          'segments':segments}
    (ROOT/'flow-sequence.json').write_text(json.dumps(meta,indent=2)+'\n')
    return qa,meta

def render_review(data,qa,meta):
    # One cached walk cycle also drives a displacement-on-fixed-ground view.
    count=28
    walk=[render(data,'move',CYCLE*i/count,.3) for i in range(count)]
    duration=CYCLE*3
    frames=[]
    for i in range(count*3):
        t=duration*i/(count*3)
        im=Image.new('RGB',(900,495),BACKGROUND);draw=ImageDraw.Draw(im)
        draw.text((20,14),'V3 / forward walk on fixed ground / EXTERNAL QA',fill='#302a23',font=_font(17))
        # These are perspective contact lanes, not a claim of a flat side camera.
        for y in [434,444]:
            draw.line((20,y,880,y),fill='#b4ad9b',width=1)
        for x in range(40,901,40):
            draw.line((x,420,x,470),fill='#c5bead',width=1)
        offset_x=350-round(SPEED*t*.3)
        im.paste(walk[i%count],(offset_x,50),walk[i%count])
        draw.text((20,475),'Ground is fixed. The walk restarts at the right edge after three cycles.',fill='#575044',font=_font(13))
        frames.append(im)
    _save_gif(frames,ROOT/'external-walk-ground.gif',duration)
    _save_gif([Image.alpha_composite(Image.new('RGBA',f.size,BACKGROUND),f).convert('RGB') for f in walk],ROOT/'external-move-slow.gif',CYCLE*2)
    # Render one sequence; QA input contains two repetitions (12 state changes).
    frames=[];half=meta['duration']/2;count=round(half*20)
    for i in range(count):
        t=half*i/count;im=render(qa,'qa_flow',t,.3)
        bg=Image.new('RGB',im.size,BACKGROUND);bg.paste(im,(0,0),im)
        segment=next(s for s in reversed(meta['segments']) if s['at']<=t)
        ImageDraw.Draw(bg).text((10,8),'EXTERNAL QA / '+segment['animation'],font=_font(),fill='#302a23')
        frames.append(bg)
    _save_gif(frames,ROOT/'external-flow.gif',half)
    (ROOT/'preview-input-sha256.txt').write_text(hashlib.sha256((ROOT/'foxfire-v3.json').read_bytes()).hexdigest()+'\n')

if __name__=='__main__':
    qa,meta=build_flow()
    render_review(load_data(ROOT/'foxfire-v3.json'),qa,meta)
    print('Rendered fixed-ground, slow-motion and authored transitions.',meta['duration'])
