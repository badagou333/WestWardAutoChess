"""Temporary deterministic sprite extraction/packing, not character repainting.
Original generated sheets are retained. No repository writes or GUI launch.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import json, hashlib

ROOT=Path(__file__).parent
NAMES=['idle_base','idle_breath','walk_a','walk_pass_a','walk_b','walk_pass_b','windup','accelerate','contact','recover','hit','collapse','dead_rest']

def components(im):
    w,h=im.size; raw=im.getchannel('A').tobytes()
    seen=bytearray(1 if v>=16 else 0 for v in raw)
    out=[]
    for start in range(w*h):
        if not seen[start]: continue
        todo=[start]; seen[start]=0; pixels=[]
        x0=x1=start%w; y0=y1=start//w
        while todo:
            q=todo.pop();pixels.append(q);x=q%w;y=q//w
            x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
            for n in ((q-1 if x else -1),(q+1 if x<w-1 else -1),q-w,q+w):
                if 0<=n<w*h and seen[n]: seen[n]=0;todo.append(n)
        if len(pixels)>250: out.append((pixels,[x0,y0,x1+1,y1+1]))
    return out

def extract(path,columns,split_wolf_death=False):
    im=Image.open(path).convert('RGBA');w,h=im.size; result={}
    for pixels,box in components(im):
        if split_wolf_death and box[0]>700 and box[1]>800 and box[2]>1400:
            groups=[(10,[q for q in pixels if q%w<1080]),(11,[q for q in pixels if q%w>=1080])]
        else:
            row=int((box[1]+box[3])/2/(h/(3 if columns==4 else 2)))
            col=min(columns-1,int((box[0]+box[2])/2/(w/columns)))
            groups=[(row*columns+col,pixels)]
        for key,pts in groups:
            data=bytearray(w*h)
            for q in pts: data[q]=255
            owned=Image.frombytes('L',(w,h),bytes(data)).filter(ImageFilter.MaxFilter(3))
            if split_wolf_death and key in (10,11):
                # Explicit ownership cut at the fused tail/muzzle seam; flagged provisional.
                d=ImageDraw.Draw(owned)
                d.rectangle((1080,0,w,h) if key==10 else (0,0,1079,h),fill=0)
            selected=im.copy();selected.putalpha(ImageChops.multiply(im.getchannel('A'),owned))
            bbox=selected.getchannel('A').getbbox()
            result[key]=(selected.crop(bbox),bbox)
    return result

def normalize(piece,box,ground,scale):
    sz=(round(piece.width*scale),round(piece.height*scale))
    resized=piece.resize(sz,Image.Resampling.LANCZOS)
    pos=(round(128+(box[0]-ground[0])*scale),round(218+(box[1]-ground[1])*scale))
    assert pos[0]>=0 and pos[1]>=0 and pos[0]+sz[0]<=256 and pos[1]+sz[1]<=256,(box,pos,sz)
    frame=Image.new('RGBA',(256,256));frame.alpha_composite(resized,pos)
    return frame

configs={
 'guard_monk':{'sheet':'guard-monk-keyposes.png','facing':'right','scale':.34,'ground':[(175,351),(550,354),(895,354),(1270,354),(180,692),(525,680),(894,683),(1235,681),(192,1038),(529,1037),(875,1032),(1245,1030)],'gait':'guard-monk-gait-keyposes.png','gait_scale':.185,'gait_ground':[(363,601),(975,608),(379,1203),(976,1208)],'windup':.20,'strike':.10,'recover':.24,'cycle':.50,'release':.235},
 'mountain_wolf':{'sheet':'mountain-wolf-keyposes.png','facing':'left','scale':.24,'ground':[(190,355),(543,351),(903,350),(1260,352),(188,684),(537,680),(897,681),(1248,676),(190,1010),(538,1008),(890,1001),(1260,1001)],'windup':.125,'strike':.10,'recover':.20,'cycle':.52,'release':.16},
}
for role,c in configs.items():
    out=ROOT/role;out.mkdir(exist_ok=True)
    parts=extract(ROOT/c['sheet'],4,role=='mountain_wolf')
    assert len(parts)==12,(role,len(parts))
    gait=extract(ROOT/c['gait'],2) if 'gait' in c else None
    old=ROOT/'baselines'/(role+'.png')
    frames=[Image.open(old).convert('RGBA').crop((0,0,256,256))]
    records=[{'id':0,'name':NAMES[0],'source':'../baselines/'+role+'.png','source_box':[0,0,256,256],'ground':[128,218],'scale':1}]
    for i in range(12):
        sheet=c['sheet']; ground=c['ground'][i];scale=c['scale'];piece,box=parts[i]
        if gait and 1<=i<=4:
            sheet=c['gait'];piece,box=gait[i-1];ground=c['gait_ground'][i-1];scale=c['gait_scale']
        frame=normalize(piece,box,ground,scale);frames.append(frame)
        records.append({'id':i+1,'name':NAMES[i+1],'source':'../'+sheet,'source_box':box,'ground':ground,'scale':scale,'bbox_alpha8':frame.getchannel('A').point(lambda v:255 if v>=8 else 0).getbbox()})
    atlas=Image.new('RGBA',(256*len(frames),256))
    for i,frame in enumerate(frames):
        frame.save(out/(NAMES[i]+'.png'));atlas.alpha_composite(frame,(256*i,0))
        a=frame.getchannel('A');assert a.getextrema()[0]==0
        assert not any(a.crop(box).getbbox() for box in [(0,0,256,1),(0,255,256,256),(0,0,1,256),(255,0,256,256)])
    atlas.save(out/'body-atlas.png')
    attack=[{'frame':6,'at':0},{'frame':7,'at':round(c['windup']*.78,4)},{'frame':8,'at':c['release']},{'frame':9,'at':round(c['windup']+c['strike']+.2*c['recover'],4)},{'frame':0,'at':round(c['windup']+c['strike']+.9*c['recover'],4)}]
    actions={'idle':{'body_frames':[0,1,0],'body_frame_seconds':[.55,.35,.55],'loop':True},'move':{'body_frames':[2,3,4,5],'body_frame_seconds':[c['cycle']/4]*4,'loop':True},'basic_attack':{'track':attack,'duration_seconds':round(c['windup']+c['strike']+c['recover'],4),'events':[{'name':'contact','at':c['release'],'once_per_attack_serial':True}]},'hit':{'body_frames':[10,0],'body_frame_seconds':[.12,.06],'hold_seconds':.18},'retreat':{'body_frames':[11,12],'body_frame_seconds':[.16,.19],'hold_seconds':.35,'fade_seconds':.30,'loop':False,'events':[{'name':'visual_death_start','at':0,'gameplay_damage_event':False}]}}
    manifest={'schema':'motion-sample-v1-requires-player-adapter','character':role,'status':'prototype_not_runtime_accepted','source_facing':c['facing'],'frame':{'width':256,'height':256,'foot_anchor':[128,218]},'atlases':{'body':'body-atlas.png'},'frames':records,'actions':actions,'baseline_presentation':{k:c[k] for k in ['windup','strike','recover','release','cycle']},'contact_socket_candidate':{'frame':8,'point':([199,153] if role=='guard_monk' else [92,184]),'space':'source frame pixels; subtract foot_anchor then mirror by gameplay_facing * source_sign','not_gameplay_hitbox':True},'layering':'single RGBA body; staff/paws not separate; no VFX','notes':['Do not use existing nine_sols_v1 selector unchanged: it ignores these tracks.','Disable old large whole-body reach/lean/bob; do not change gameplay reach/speed/attack interval.','Death pose does not implement permanent-death rules.']}
    if role=='mountain_wolf': manifest['notes']+=['Four-pose gait support-leg alternation remains provisional. Corrective gait sheet NOT USED: last tail touches outer edge.','Collapse/rest source silhouettes fuse; ownership boundary x=1080 is provisional and needs visual acceptance.']
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    contact=Image.new('RGB',(7*192,2*206),'#29343d');d=ImageDraw.Draw(contact)
    for i,fr in enumerate(frames):
        x=(i%7)*192;y=(i//7)*206
        s=fr.resize((192,192),Image.Resampling.LANCZOS);contact.paste(s,(x,y),s)
        d.line((x+8,y+164,x+184,y+164),fill='#59656c')
        d.text((x+5,y+184),f'{i} {NAMES[i]}',fill='#f1ead7')
    contact.save(out/'frame-review.png')
    # Lossless WebP playback proof: real changed frames, no whole-image wobble or interpolation.
    timeline=[]
    for state,ids,ds in [('idle',[0,1,0],[550,350,550]),('move',[2,3,4,5]*3,[round(c['cycle']*250)]*12),('attack',[6,7,8,9,0],[round(c['windup']*.78*1000),round((c['release']-c['windup']*.78)*1000),round((c['windup']+c['strike']+.2*c['recover']-c['release'])*1000),round(.7*c['recover']*1000),round(.1*c['recover']*1000)]),('hit',[10,0],[120,180]),('retreat',[11,12],[160,600])]:
        for fid,ms in zip(ids,ds):
            shot=Image.new('RGB',(512,300),'#29343d');dr=ImageDraw.Draw(shot)
            dr.text((12,12),f'{role} | {state} | frame {fid} | 1x & 2x/3',fill='#f1ead7')
            dr.line((0,238,511,238),fill='#667477')
            shot.paste(frames[fid],(0,20),frames[fid])
            small=frames[fid].resize((171,171),Image.Resampling.LANCZOS)
            shot.paste(small,(310,93),small)
            timeline.append((shot,max(20,ms)))
    timeline[0][0].save(out/'playback.webp',save_all=True,append_images=[x[0] for x in timeline[1:]],duration=[x[1] for x in timeline],loop=0,lossless=True)
    print(role, 'frames=',len(frames),'atlas=',atlas.size,'idle_bbox=',frames[0].getchannel('A').getbbox())
