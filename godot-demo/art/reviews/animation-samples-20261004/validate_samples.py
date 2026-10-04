from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib

root=Path(__file__).parent
report={'status':'static_package_checks_only','runtime_verified':False,'roles':{}}
qa=Image.new('RGB',(1024,600),'#ebe6da')
draw=ImageDraw.Draw(qa)
for row,role in enumerate(('guard_monk','mountain_wolf')):
    p=root/role;m=json.loads((p/'manifest.json').read_text())
    atlas=Image.open(p/'body-atlas.png');assert atlas.size==(3328,256)
    heights=[]
    for i,f in enumerate(m['frames']):
        im=Image.open(p/(f['name']+'.png'))
        assert im.mode=='RGBA' and im.size==(256,256)
        assert im.tobytes()==atlas.crop((i*256,0,(i+1)*256,256)).tobytes()
        a=im.getchannel('A');bb=a.point(lambda v:255 if v>=8 else 0).getbbox()
        assert bb and bb[0]>0 and bb[1]>0 and bb[2]<256 and bb[3]<256
        heights.append(bb[3]-bb[1])
    attack=m['actions']['basic_attack']
    assert len(attack['events'])==1
    assert attack['events'][0]['at']==m['baseline_presentation']['release']
    times=[f['at'] for f in attack['track']]
    assert times==sorted(times) and times[-1]<attack['duration_seconds']
    anim=Image.open(p/'playback.webp');assert anim.is_animated
    report['roles'][role]={'frames':13,'atlas':list(atlas.size),'alpha_border_check':True,'atlas_matches_frames':True,'visible_heights_design_px':heights,'attack_event_at':attack['events'][0]['at'],'webp_frames':anim.n_frames,'atlas_sha256':hashlib.sha256((p/'body-atlas.png').read_bytes()).hexdigest()}
    for col,fid in enumerate((0,5,8,12)):
        im=Image.open(p/(m['frames'][fid]['name']+'.png'))
        qa.paste(im,(col*256,row*300),im)
        draw.text((col*256+10,row*300+262),f'{role} {fid}',fill='#333333')
qa.save(root/'light-alpha-review.png')
(root/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
