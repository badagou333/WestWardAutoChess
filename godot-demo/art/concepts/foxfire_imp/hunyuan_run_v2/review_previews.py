"""Assemble native renders for internal review; no AI image editing."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
BASE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--draft',action='store_true');args=p.parse_args()
folder=BASE/('drafts' if args.draft else 'preview_frames')
report=[]
for view in ['front','side']:
    paths=sorted(folder.glob(view+'-*.png'))
    imgs=[Image.open(f).convert('RGB') for f in paths]
    indices=list(range(len(imgs))) if args.draft else [0,3,5,8,10,13,15,18]
    sheet=Image.new('RGB',(1280,680),(25,29,36));draw=ImageDraw.Draw(sheet)
    for tile,i in enumerate(indices):
        x,y=(tile%4)*320,(tile//4)*340
        sheet.paste(imgs[i].resize((320,320)),(x,y+20))
        draw.text((x+12,y+4),paths[i].stem,fill='white')
    sheet.save((folder if args.draft else BASE)/(view+'-poses.jpg'),quality=92)
    if not args.draft:
        assert len(imgs)==20
        for slow in [False,True]:
            out=BASE/(f'run-{view}'+('-slow' if slow else '')+'.gif')
            durations=([60,70,70]*7)[:20] if slow else ([30,30,40]*7)[:20]
            imgs[0].save(out,save_all=True,append_images=imgs[1:],duration=durations,loop=0,disposal=2,optimize=False)
            with Image.open(out) as check:
                assert check.n_frames==20
                for j in range(20): check.seek(j);check.load()
            report.append({'path':out.name,'frames':20,'duration_ms':sum(durations),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
if report:
    (BASE/'preview-report.json').write_text(json.dumps({'source':'Native Blender renders of retargeted skinned animation','glb_sha256':hashlib.sha256((BASE/'foxfire-run.glb').read_bytes()).hexdigest(),'files':report},indent=2)+'\n')
