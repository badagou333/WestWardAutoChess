from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import json, shutil, hashlib

ROOT=Path(__file__).parent
OLD=ROOT.parent/'mountain_wolf'
im=Image.open(ROOT/'six-correction-poses.png').convert('RGBA')
w,h=im.size
seen=bytearray(1 if v>=16 else 0 for v in im.getchannel('A').tobytes())
parts=[]
for start in range(w*h):
    if not seen[start]:continue
    todo=[start];seen[start]=0;pts=[]
    x0=x1=start%w;y0=y1=start//w
    while todo:
        q=todo.pop();pts.append(q);x=q%w;y=q//w
        x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
        for n in ((q-1 if x else -1),(q+1 if x<w-1 else -1),q-w,q+w):
            if 0<=n<w*h and seen[n]:seen[n]=0;todo.append(n)
    if len(pts)>500:
        parts.append({'pts':pts,'bbox':[x0,y0,x1+1,y1+1]})
assert len(parts)==6,(len(parts),[p['bbox'] for p in parts])
parts.sort(key=lambda p:(int((p['bbox'][1]+p['bbox'][3])/2/(h/3)),p['bbox'][0]))
grounds=[(320,432),(936,433),(320,835),(936,835),(320,1180),(940,1180)]
scale=.20
normalized=[]
records=[]
qa=Image.new('RGB',(768,600),'#ebe6da');d=ImageDraw.Draw(qa)
for i,part in enumerate(parts):
    data=bytearray(w*h)
    for q in part['pts']:data[q]=255
    owner=Image.frombytes('L',(w,h),bytes(data)).filter(ImageFilter.MaxFilter(3))
    single=im.copy();single.putalpha(ImageChops.multiply(im.getchannel('A'),owner))
    box=single.getchannel('A').getbbox()
    assert box[0]>0 and box[1]>0 and box[2]<w and box[3]<h
    crop=single.crop(box);small=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
    ground=grounds[i];at=(round(128+(box[0]-ground[0])*scale),round(218+(box[1]-ground[1])*scale))
    assert at[0]>=0 and at[1]>=0 and at[0]+small.width<=256 and at[1]+small.height<=256
    frame=Image.new('RGBA',(256,256));frame.alpha_composite(small,at)
    frame.save(ROOT/f'correction-{i+1:02}.png');normalized.append(frame)
    records.append({'source_box':box,'ground':ground,'scale':scale,'source':'../six-correction-poses.png','alpha8_bbox':frame.getchannel('A').point(lambda v:255 if v>=8 else 0).getbbox()})
    x=(i%3)*256;y=(i//3)*300
    qa.paste(frame,(x,y),frame)
    d.text((x+8,y+270),f'{i+1}: '+('GAIT NOT ACCEPTED' if i<4 else 'DEATH ISOLATED'),fill='#333333')
qa.save(ROOT/'correction-alpha-review.png')
out=ROOT/'mountain_wolf';out.mkdir(exist_ok=True)
m=json.loads((OLD/'manifest.json').read_text())
frames=[]
for f in m['frames']:
    fid=f['id'];name=f['name']+'.png'
    if fid in (11,12):
        idx=fid-7;frame=normalized[idx]
        m['frames'][fid]={'id':fid,'name':f['name'],**records[idx]}
    else:
        frame=Image.open(OLD/name).convert('RGBA')
        assert frame.tobytes()==Image.open(OLD/name).convert('RGBA').tobytes()
        # Version2 adds one nesting level; retain references back to unchanged original inputs.
        if m['frames'][fid]['source'].startswith('../'):
            m['frames'][fid]['source']='../'+m['frames'][fid]['source']
    frame.save(out/name);frames.append(frame)
atlas=Image.new('RGBA',(3328,256))
for i,frame in enumerate(frames):atlas.alpha_composite(frame,(i*256,0))
atlas.save(out/'body-atlas.png')
m['status']='prototype_v2_death_isolation_only_gait_unresolved'
m['notes']=[n for n in m['notes'] if 'ownership boundary' not in n]
m['notes']+=['One bounded corrective generation: 4 new gait poses NOT ADOPTED; opposite support phase still not reliable.','Frames 11/12 replaced by independent complete silhouettes; no source x=1080 seam cut. Runtime death continuity still unverified.','Frames 0-10 byte-identical pixels to previous prototype; do not claim gait passed.']
(out/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
death=[]
for fid in (10,11,12):
    shot=Image.new('RGB',(512,280),'#28343e');draw=ImageDraw.Draw(shot)
    draw.text((10,8),f'Wolf v2 death preview, frame {fid}, 1x and 2/3',fill='#e8dfc9')
    shot.paste(frames[fid],(0,10),frames[fid])
    mini=frames[fid].resize((171,171),Image.Resampling.LANCZOS)
    shot.paste(mini,(310,83),mini);death.append(shot)
death[0].save(out/'death-playback.webp',save_all=True,append_images=death[1:],duration=[120,160,800],loop=0,lossless=True)
review=Image.new('RGB',(1024,560),'#28343e');draw=ImageDraw.Draw(review)
for row,src in enumerate((OLD,out)):
    for col,name in enumerate(('collapse.png','dead_rest.png')):
        frame=Image.open(src/name);x=col*512;y=row*280
        review.paste(frame,(x,y),frame)
        draw.text((x+260,y+180),('v1 provisional seam' if row==0 else 'v2 independent')+' '+name,fill='#e8dfc9')
review.save(ROOT/'death-v1-v2-review.png')
report={'sheet_size':im.size,'large_alpha_components':len(parts),'component_boxes':[p['bbox'] for p in parts],'source_death_horizontal_gap_alpha16':parts[5]['bbox'][0]-parts[4]['bbox'][2],'preserved_frame_ids':list(range(11)),'updated_frame_ids':[11,12],'gait_passed':False,'death_static_isolation_passed':True,'runtime_verified':False,'atlas_sha256':hashlib.sha256((out/'body-atlas.png').read_bytes()).hexdigest()}
for f in m['frames']:
    a=Image.open(out/(f['name']+'.png')).getchannel('A');box=a.getbbox()
    assert box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256
for i in range(11):
    name=m['frames'][i]['name']+'.png'
    assert Image.open(out/name).tobytes()==Image.open(OLD/name).tobytes()
(ROOT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report))
