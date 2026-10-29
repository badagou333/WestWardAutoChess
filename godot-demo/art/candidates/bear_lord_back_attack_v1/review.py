#!/usr/bin/env python3
"""All-frame dark/light/board review and structural checks, without AI tools."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import numpy as np
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[3]

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def review(ffmpeg):
    m=json.loads((HERE/'manifest.json').read_text())
    assert len(m['frames'])==m['decoded_frame_count']==340
    assert [f['source_frame'] for f in m['frames']]==list(range(1,341))
    assert [f['source_pts'] for f in m['frames']]==list(range(0,43520,128))
    assert all(abs(f['source_time_seconds']-i/96)<1e-12 and
               abs(f['duration_seconds']-1/96)<1e-12 for i,f in enumerate(m['frames']))
    assert abs(m['video_duration_seconds']-340/96)<1e-12
    board_path=REPO/'bear-forehand-showcase/art/forest-board.png'
    board=Image.open(board_path).convert('RGBA').resize((1440,810),Image.Resampling.LANCZOS)
    layer=Image.new('RGBA',board.size)
    d=ImageDraw.Draw(layer)
    d.polygon([(720,406),(789,441),(720,476),(651,441)],fill=(112,186,148,36),outline=(169,219,177,255),width=2)
    d.ellipse((695,434,745,448),fill=(5,10,8,76))
    board.alpha_composite(layer)
    commands=[]
    for name,size in [('all-frames-dark-light-board.mp4',(1152,352)),('all-frames-board.mp4',(1440,810))]:
        cmd=[ffmpeg,'-y','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24',
             '-s',f'{size[0]}x{size[1]}','-r','96','-i','pipe:0','-i',str(HERE/'audio/source-track.wav'),
             '-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac',
             '-movflags','+faststart',str(HERE/'review'/name)]
        commands.append(subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=subprocess.PIPE))
    pages={}
    metric=[]
    for i,f in enumerate(m['frames']):
        p=HERE/'frames'/f['file'];im=Image.open(p).convert('RGBA');a=np.asarray(im)
        assert im.size==tuple(m['canvas']) and im.getbbox() is not None
        assert sha(p)==f['sha256']
        assert not (a[0,:,3].any() or a[-1,:,3].any() or a[:,0,3].any() or a[:,-1,3].any())
        tiny=im.convert('RGBa').resize((288,240),Image.Resampling.LANCZOS).convert('RGBA')
        current=board.copy();current.alpha_composite(tiny,(587,281))
        panes=[]
        for colour in ('#152333','#eadfca'):
            pane=Image.new('RGBA',(384,320),colour);pane.alpha_composite(tiny,(59,53));panes.append(pane)
        panes.append(current.crop((528,228,912,548)))
        trip=Image.new('RGB',(1152,352),'#26313c');pen=ImageDraw.Draw(trip)
        for j,pane in enumerate(panes): trip.paste(pane.convert('RGB'),(j*384,32))
        pen.text((12,9),f'Source frame {f["source_frame"]} / {f["source_time_seconds"]:.6f}s   |   Dark / light / approved forest board   |   Actual display scale 0.75',fill='white')
        commands[0].stdin.write(trip.tobytes());commands[1].stdin.write(current.convert('RGB').tobytes())
        page=i//40;position=i%40
        for kind,pane in zip(('dark','light','board'),panes):
            key=(page,kind)
            if key not in pages: pages[key]=Image.new('RGB',(960,1376),'#26313c')
            thumb=pane.convert('RGB').resize((192,160),Image.Resampling.LANCZOS)
            x=position%5*192;y=position//5*172
            pages[key].paste(thumb,(x,y+12))
            ImageDraw.Draw(pages[key]).text((x+3,y),f'{i+1:03d}  {f["source_time_seconds"]:.3f}s','white')
        metric.append(dict(frame=i+1,bbox=im.getbbox(),alpha_pixels=int((a[:,:,3]>25).sum())))
    for p in commands:
        p.stdin.close();err=p.stderr.read().decode();code=p.wait()
        if code: raise RuntimeError(err)
    for (page,kind),sheet in pages.items(): sheet.save(HERE/'review'/f'all-{kind}-{page+1:02}.jpg',quality=91)
    selected=[152,157,161,165,169,173,177,181,185]
    with tempfile.TemporaryDirectory(prefix='bear-back-critical-') as tmp:
        selector='+'.join(f'eq(n\\,{n-1})' for n in selected)
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-i',str(HERE/m['source_video']),
            '-vf','select='+selector,'-fps_mode','passthrough',str(Path(tmp)/'source_%03d.png')],check=True)
        for page in range(3):
            sheet=Image.new('RGB',(1152,1008),'#26313c');pen=ImageDraw.Draw(sheet)
            for row in range(3):
                i=page*3+row;n=selected[i]
                raw=Image.open(Path(tmp)/f'source_{i+1:03d}.png').convert('RGBa')
                s=m['global_scale'];tx=m['foot'][0]-m['source_foot'][0]*s;ty=m['foot'][1]-m['source_foot'][1]*s
                raw=raw.transform(tuple(m['canvas']),Image.Transform.AFFINE,(1/s,0,-tx/s,0,1/s,-ty/s),Image.Resampling.BICUBIC).convert('RGBA')
                keyed=Image.open(HERE/'frames'/m['frames'][n-1]['file']).convert('RGBA')
                for col,(im,c) in enumerate(((raw,'#f0f0f0'),(keyed,'#152333'),(keyed,'#eadfca'))):
                    pane=Image.new('RGBA',tuple(m['canvas']),c);pane.alpha_composite(im)
                    sheet.paste(pane.convert('RGB'),(col*384,row*336+16))
                pen.text((5,row*336),f'Source {n} / {(n-1)/96:.6f}s   |   source / dark / light',fill='white')
            sheet.save(HERE/'review'/f'critical-source-dark-light-{page+1}.jpg',quality=95)
    source_bounds=[min(f['source_matte_bbox'][0] for f in m['frames']),min(f['source_matte_bbox'][1] for f in m['frames']),max(f['source_matte_bbox'][2] for f in m['frames']),max(f['source_matte_bbox'][3] for f in m['frames'])]
    qa=dict(decoded_frames=340,manifest_entries=len(m['frames']),all_png_hashes_match=True,
            timebase=m['source_time_base'],all_timestamps_preserved=True,
            all_alpha_borders_clear=True,source_subject_union_bbox=source_bounds,
            source_right_margin_pixels=960-source_bounds[2],canvas=m['canvas'],foot=m['foot'],
            transform='one global scale=0.35; source foot (471,711) -> canvas (177,213)',
            rest_visible_height_canvas=m['frames'][0]['bbox'][3]-m['frames'][0]['bbox'][1],
            rest_visible_height_at_game_scale=(m['frames'][0]['bbox'][3]-m['frames'][0]['bbox'][1])*.75,
            board_source=str(board_path.relative_to(REPO)),board_sha256=sha(board_path),
            video_duration_seconds=m['video_duration_seconds'],audio=m['audio'],frame_metrics=metric)
    (HERE/'review/qa.json').write_text(json.dumps(qa,indent=2)+'\n')
    print(json.dumps({k:v for k,v in qa.items() if k!='frame_metrics'}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--ffmpeg',default='ffmpeg');review(p.parse_args().ffmpeg)
