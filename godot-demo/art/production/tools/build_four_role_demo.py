"""Reproducible, source-preserving Demo pose extraction. User authorized local processing.

Coordinates are hand-reviewed source-image annotations, never equal-grid cuts.
Original drawings remain unchanged. Matte thresholds are deliberately explicit.
"""
from pathlib import Path
import json, hashlib
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ART = Path(__file__).resolve().parents[2]
ROLES = {
 'wild_hunter': {'name':'山野猎户','version':2,'height':136,'frames':[
  ['idle',[35,75,385,480],[213,469],[[35,75],[385,75],[385,446],[296,446],[295,475],[248,475],[245,450],[174,450],[174,468],[119,468],[117,447],[35,447]]],
  ['move',[383,102,700,470],[550,461],[[383,102],[700,102],[700,431],[492,431],[492,468],[443,468],[443,436],[383,436]]],
  ['attack_prepare',[727,105,1151,462],[886,453],[[727,105],[1151,105],[1151,436],[1021,436],[1021,460],[967,460],[961,435],[796,435],[791,454],[737,454],[727,436]]],
  ['attack_impact',[1081,110,1532,465],[1234,453],[[1147,111],[1404,111],[1420,275],[1530,301],[1494,343],[1380,327],[1372,420],[1171,441],[1170,458],[1119,458],[1116,430],[1081,416],[1081,350]]],
  ['hit',[793,522,1134,895],[969,885],[[793,522],[1134,522],[1134,866],[1081,866],[1081,892],[1028,892],[1027,867],[859,867],[850,892],[806,892],[805,868],[793,868]]],
  ['retreat',[1126,607,1455,905],[1300,887],[[1126,607],[1455,607],[1455,870],[1425,870],[1425,885],[1366,885],[1389,897],[1310,898],[1240,889],[1164,888],[1126,871]]]
 ],'effects':[['attack_trail','attack_impact',[1370,270,1528,415],[[1494,270],[1528,273],[1528,350],[1370,415],[1370,400],[1457,349],[1501,337],[1510,311],[1494,288]]]]},
 'herbal_spirit_child': {'name':'药灵童子','version':2,'height':142,'frames':[
  ['idle',[95,77,383,476],[232,465],[[95,77],[383,77],[383,446],[307,446],[307,474],[269,474],[266,450],[237,450],[237,465],[180,465],[180,448],[159,448],[159,465],[143,465],[135,414],[95,410]]],
  ['move',[432,91,776,471],[584,461],[[432,91],[776,91],[776,435],[701,435],[685,461],[655,461],[650,442],[553,442],[553,466],[505,455],[494,439],[515,434],[508,398],[432,398]]],
  ['attack',[787,101,1111,465],[945,454],[[787,101],[1040,101],[1040,191],[1111,191],[1111,256],[1070,266],[1070,438],[1047,438],[1047,460],[996,460],[991,437],[896,437],[891,460],[842,460],[839,438],[787,438]]],
  ['hit',[815,532,1178,881],[1053,870],[[815,532],[1154,532],[1178,823],[1150,850],[1148,878],[1075,878],[1042,864],[988,872],[973,872],[962,845],[897,845],[868,725],[815,651]]],
  ['retreat',[1232,538,1570,885],[1400,873],[[1232,538],[1570,538],[1570,859],[1532,879],[1280,879],[1265,854],[1232,842]]]
 ],'effects':[
  ['idle_mist','idle',[79,191,124,256]],
  ['basic_projectile','attack',[1110,183,1218,254]],
  ['retreat_mist','retreat',[1240,782,1280,846]]
 ]},
 'sparrow_spirit': {'name':'山雀精','version':2,'height':120,'frames':[
  ['idle',[50,42,343,444],[217,431]],
  ['move',[401,76,822,435],[628,426]],
  ['attack_prepare',[865,88,1195,434],[1020,421]],
  ['attack_impact',[1206,86,1530,435],[1360,424],[[1206,86],[1480,86],[1495,229],[1530,285],[1504,327],[1460,330],[1452,402],[1241,435],[1206,397]]],
  ['hit',[1318,499,1671,827],[1450,818],[[1318,499],[1671,499],[1671,780],[1438,817],[1438,824],[1372,824],[1372,807],[1379,790],[1318,746]]],
  ['retreat',[21,531,326,832],[185,821],[[21,531],[326,531],[326,817],[275,817],[275,826],[228,826],[228,815],[177,815],[177,829],[128,829],[126,817],[21,817]]]
 ],'effects':[['basic_projectile','attack_impact',[1515,210,1711,282]]]},
 'bear_lord': {'name':'熊山君','version':1,'height':164,'frames':[
  ['idle',[43,92,334,460],[196,449],[[43,92],[334,92],[334,423],[292,423],[292,457],[227,457],[225,433],[176,433],[174,443],[93,443],[93,421],[43,421]]],
  ['move',[341,128,713,461],[523,450],[[341,128],[713,128],[713,416],[601,416],[594,454],[505,456],[496,443],[463,437],[463,420],[403,420],[397,438],[344,433],[341,413]]],
  ['attack',[711,132,1130,450],[881,440],[[711,132],[1010,132],[1020,248],[1128,267],[1129,334],[1031,339],[1041,421],[1025,445],[940,445],[937,426],[807,426],[804,445],[722,445],[711,425]]],
  ['hit',[791,555,1110,888],[953,875],[[820,603],[854,617],[899,587],[956,555],[1086,566],[1110,613],[1100,781],[1031,878],[982,881],[977,854],[942,882],[896,882],[883,859],[846,850],[803,830],[791,809],[797,757],[808,705],[805,674]]],
  ['retreat',[1156,611,1520,890],[1334,878],[[1156,611],[1520,611],[1520,862],[1484,877],[1190,884],[1180,859],[1156,859]]]
 ],'effects':[['attack_dust','attack',[1102,186,1183,396],[[1102,186],[1183,186],[1183,396],[1128,374],[1128,338],[1145,325],[1145,269],[1114,245]]]]}
}

def poly_mask(size,points,offset):
    im=Image.new('L',size); ImageDraw.Draw(im).polygon([(x-offset[0],y-offset[1]) for x,y in points],fill=255)
    return np.asarray(im)>0

def largest_component(mask):
    remaining=mask.copy();best=[];height,width=mask.shape
    for sy,sx in zip(*np.where(mask)):
        if not remaining[sy,sx]:continue
        component=[];todo=deque([(int(sy),int(sx))]);remaining[sy,sx]=False
        while todo:
            y,x=todo.popleft();component.append((y,x))
            for dy,dx in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]:
                ny,nx=y+dy,x+dx
                if 0<=ny<height and 0<=nx<width and remaining[ny,nx]:
                    remaining[ny,nx]=False;todo.append((ny,nx))
        if len(component)>len(best):best=component
    result=np.zeros_like(mask)
    if best:
        yy,xx=zip(*best);result[yy,xx]=True
    return result

def matte(source,box,polygon=None,effect=False,pivot=None):
    im=source.crop(box).convert('RGB'); a=np.array(im); f=a.astype(float)
    spread=f.max(2)-f.min(2); light=f.mean(2)
    # Neutral light paper is separable from the dark ink and warm/cool painted areas.
    mask=(light<170)|(spread>27)
    if effect:
        mask=(light<185)|(spread>21)
    if polygon:mask &= poly_mask(im.size,polygon,box)
    if not effect:
        if pivot:
            ground=np.arange(im.height)[:,None]+box[1]>=pivot[1]-23
            mask &= ~(ground & (light>95) & (spread<50))
        mask=largest_component(mask)
    # No fill-holes operation: enclosed paper gaps must remain transparent.
    rgba=np.dstack([a,np.where(mask,255,0).astype('uint8')]);rgba[~mask,:3]=0
    return Image.fromarray(rgba)

def font(size):
    for p in ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/simhei.ttf']:
        if Path(p).exists():return ImageFont.truetype(p,size)
    return ImageFont.load_default()

def place(im,box,pivot,scale):
    new_size=(max(1,round(im.width*scale)),max(1,round(im.height*scale)))
    small=im.resize(new_size,Image.Resampling.LANCZOS)
    xy=(round(128-(pivot[0]-box[0])*scale),round(218-(pivot[1]-box[1])*scale))
    out=Image.new('RGBA',(256,256));out.alpha_composite(small,xy)
    return out,xy

def run():
    index=[]
    for key,role in ROLES.items():
        src=ART/'concepts'/key/f'{key}_action_keypose_sheet_v{role["version"]}.png'
        source=Image.open(src).convert('RGB');dest=ART/'production'/key/'demo_v1';dest.mkdir(parents=True,exist_ok=True)
        prepared=[]
        for name,box,pivot,*poly in role['frames']:
            im=matte(source,box,poly[0] if poly else None,pivot=pivot)
            prepared.append((name,box,pivot,im))
        idle_bbox=prepared[0][3].getbbox();scale=role['height']/(idle_bbox[3]-idle_bbox[1])
        count=len(prepared);atlas=Image.new('RGBA',(256*count,256));vfx_atlas=Image.new('RGBA',atlas.size)
        manifest={'version':1,'character':key,'status':'demo_pose_sample_pending_engine_validation','source':str(src.relative_to(ART.parent)).replace('\\','/'),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'frame':{'width':256,'height':256,'foot_anchor':[128,218],'display_scale':1},'source_scale':scale,'anchor_method':'Hand-annotated body ground projection; not whole-image bounding-box center','atlases':{'body':f'{key}_demo_body_atlas_v1.png','vfx':f'{key}_demo_vfx_atlas_v1.png','columns':count,'rows':1},'frames':[],'standalone_vfx':{},'actions':{},'known_limitations':['Pose switching only, no continuous in-between animation or engine battle integration.','Weapons remain part of body poses; not a skeletal cutout rig.','Per-character annotation and neutral-paper matte require visual review, not a reusable automatic acceptance test.']}
        for i,(name,box,pivot,im) in enumerate(prepared):
            frame,xy=place(im,box,pivot,scale);file=f'{key}_{name}_body_v1.png';frame.save(dest/file);atlas.paste(frame,(256*i,0))
            a=np.array(frame)[:,:,3];ys,xs=np.where(a>=26)
            bbox=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
            manifest['frames'].append({'index':i,'name':name,'body':True,'file':file,'source_box':box,'source_ground_anchor':pivot,'source_body_polygon':role['frames'][i][3] if len(role['frames'][i])>3 else None,'target_bbox_alpha_10_percent':bbox,'aligned_vfx':False})
        for effect,action,box,*poly in role['effects']:
            im=matte(source,box,poly[0] if poly else None,effect=True)
            pos=next(i for i,f in enumerate(role['frames']) if f[0]==action);pivot=role['frames'][pos][2]
            aligned,_=place(im,box,pivot,scale);fname=f'{key}_{effect}_aligned_v1.png';aligned.save(dest/fname)
            previous=vfx_atlas.crop((pos*256,0,(pos+1)*256,256));previous.alpha_composite(aligned);vfx_atlas.paste(previous,(pos*256,0))
            # Compact effect retains the display size, never stretches to fill the 64-pixel cell.
            small=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.LANCZOS)
            bbox=small.getbbox();small=small.crop(bbox)
            compact_size=64 if max(small.size)<=56 else 128
            compact=Image.new('RGBA',(compact_size,compact_size));compact.alpha_composite(small,((compact_size-small.width)//2,(compact_size-small.height)//2))
            compact_file=f'{key}_{effect}_v1.png';compact.save(dest/compact_file)
            manifest['frames'][pos]['aligned_vfx']=True
            manifest['standalone_vfx'][effect]={'file':compact_file,'size':[compact_size,compact_size],'anchor':[compact_size//2,compact_size//2],'aligned_file':fname,'source_box':box,'aligned_center_trial':[round(128+(box[0]+(box[2]-box[0])/2-pivot[0])*scale),round(218+(box[1]+(box[3]-box[1])/2-pivot[1])*scale)]}
        atlas.save(dest/manifest['atlases']['body']);vfx_atlas.save(dest/manifest['atlases']['vfx'])
        ids={f['name']:f['index'] for f in manifest['frames']}
        manifest['actions']={'idle':{'body_frames':[ids['idle']],'loop':True},'move':{'body_frames':[ids['move']],'runtime_bob_pixels':2,'loop':True},'basic_attack':{'body_frames':[ids[x] for x in ['attack_prepare','attack_impact','attack'] if x in ids],'body_frame_seconds':[.12,.12] if 'attack_prepare' in ids else [.24],'return_to':'idle'},'hit':{'body_frames':[ids['hit']],'hold_seconds':.18,'return_to':'idle'},'retreat':{'body_frames':[ids['retreat']],'hold_seconds':.45,'fade_seconds':.25}}
        role_notes={
            'wild_hunter':'The drawn blade shape varies between poses; only detached slash trails are separated. No bow or summoned companion is included.',
            'herbal_spirit_child':'Only the basic green projectile and small idle/retreat wisps are provided; neutral-background matting can simplify very pale smoke edges.',
            'sparrow_spirit':'Single wind blade is a Demo placeholder, not confirmation of final skill semantics; detached projectile is separate from the retained wing silhouette.',
            'bear_lord':'Owner-approved Demo recoil, unstable club grip and overlapping shoulder impact strokes remain as drawn; no pose redesign.'
        }
        manifest['known_limitations'].append(role_notes[key])
        if 'basic_projectile' in manifest['standalone_vfx']:manifest['actions']['basic_attack'].update({'spawn_vfx':'basic_projectile','projectile_seconds_trial':.20,'disable_aligned_projectile_on_spawn':True})
        else:
            attack_frame=ids.get('attack_impact',ids.get('attack'))
            if manifest['frames'][attack_frame]['aligned_vfx']:manifest['actions']['basic_attack']['vfx_frames']=[attack_frame]
        for action in ['idle','retreat']:
            if manifest['frames'][ids[action]]['aligned_vfx']:manifest['actions'][action]['vfx_frames']=[ids[action]]
        (dest/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        # Dark and light contact rows; no inferred redraw of source details.
        contact=Image.new('RGB',(256*count,584),'#17232d');draw=ImageDraw.Draw(contact)
        draw.rectangle((0,292,256*count,584),fill='#eadfc8')
        for i,entry in enumerate(manifest['frames']):
            fr=atlas.crop((i*256,0,(i+1)*256,256));fx=vfx_atlas.crop((i*256,0,(i+1)*256,256));fr.alpha_composite(fx)
            for y in [28,320]:
                contact.paste(fr,(i*256,y),fr);draw.line((i*256+119,y+218,i*256+137,y+218),fill='#35abb5');draw.line((i*256+128,y+209,i*256+128,y+227),fill='#35abb5')
            draw.text((i*256+12,6),entry['name'],font=font(16),fill='#edf1f5')
        contact.save(dest/f'{key}_demo_review_v1.png')
        index.append({'character':key,'name':role['name'],'frames':count,'scale':scale,'manifest':str((dest/'manifest.json').relative_to(ART)).replace('\\','/')})
    out=ART/'reviews'/'four-role-demo';out.mkdir(exist_ok=True)
    (out/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(index,ensure_ascii=False))

if __name__=='__main__':run()
