#!/usr/bin/env python3
"""Generate all-frame review pages and exact-grid 240fps offline previews.

240fps is a preview container time grid (64 source ticks), NOT new poses.
Runtime uses the 84 variable-duration entries directly.
"""
from pathlib import Path
import argparse, json, subprocess, tempfile, wave
import numpy as np
from PIL import Image, ImageDraw
import build

def pane(im,bg):
    out=Image.new('RGBA',im.size,bg);out.alpha_composite(im);return out.convert('RGB')

def main(args):
    root=Path(args.output);review=root/'review';m=json.loads((root/'manifest.json').read_text())
    repo=build.HERE.parents[3];boardpath=repo/'bear-forehand-showcase/art/forest-board.png'
    board=Image.open(boardpath).convert('RGBA').resize((1440,810),Image.Resampling.LANCZOS)
    layer=Image.new('RGBA',board.size);d=ImageDraw.Draw(layer)
    d.polygon([(720,405),(792,441),(720,477),(648,441)],fill=(112,186,148,36),outline=(169,219,177,255),width=2)
    d.ellipse((695,434,745,448),fill=(5,10,8,76));board.alpha_composite(layer)
    assert len(m['frames'])==84 and [f['original_source_frame'] for f in m['frames']]==list(range(10,94))
    pages={};metrics=[];previews=[];boardframes=[]
    for i,f in enumerate(m['frames']):
        im=Image.open(root/'frames'/f['file']).convert('RGBA');a=np.array(im)
        assert im.size==tuple(m['canvas']) and build.sha(root/'frames'/f['file'])==f['sha256']
        assert not(a[:4,:,3].any() or a[-4:,:,3].any() or a[:,:4,3].any() or a[:,-4:,3].any())
        assert f['duration_ticks']>0 and f['duration_ticks']%64==0
        if i<83: assert f['source_pts']+f['duration_ticks']==m['frames'][i+1]['source_pts']
        tiny=im.convert('RGBa').resize((300,240),Image.Resampling.LANCZOS).convert('RGBA')
        current=board.copy();current.alpha_composite(tiny,(587,281))
        panels=[pane(im,'#172638'),pane(im,'#eadfca'),current.convert('RGB').crop((520,228,920,548))]
        trip=Image.new('RGB',(1200,344),'#26313c')
        for j,p in enumerate(panels): trip.paste(p,(j*400,24))
        ImageDraw.Draw(trip).text((10,5),f'NEW {i+1:02} / ORIGINAL {i+10:02}   {f["source_pts"]}/15360 s | dark / light / board at display scale 0.75',fill='white')
        previews.append(trip);boardframes.append(current.convert('RGB'))
        for kind,p in zip(('dark','light','board'),panels):
            page=i//28;pos=i%28;key=(kind,page)
            if key not in pages: pages[key]=Image.new('RGB',(1600,2408),'#26313c')
            x=pos%4*400;y=pos//4*344
            pages[key].paste(p,(x,y+24));ImageDraw.Draw(pages[key]).text((x+5,y+5),f'{i+1:02} / orig {i+10:02} - {f["source_time_seconds"]:.6f}s',fill='white')
        metrics.append(dict(frame=i+1,bbox=im.getbbox(),visible_alpha_pixels=int((a[:,:,3]>25).sum()),
          solid_pixels=int((a[:,:,3]>250).sum()),partial_alpha_pixels=int(((a[:,:,3]>0)&(a[:,:,3]<255)).sum())))
    for (kind,page),sheet in pages.items():sheet.save(review/f'all-{kind}-{page+1:02}.jpg',quality=94)
    if not args.no_video:
        for name,images,size in [('all-frames-dark-light-board.mp4',previews,(1200,344)),('all-frames-board.mp4',boardframes,(1440,810))]:
            cmd=[args.ffmpeg,'-y','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{size[0]}x{size[1]}','-r','240','-i','pipe:0',
              '-i',str(root/'audio/source-track.wav'),'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-video_track_timescale','15360','-t','3','-movflags','+faststart',str(review/name)]
            proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=subprocess.PIPE)
            for frame,f in zip(images,m['frames']):
                data=frame.tobytes()
                for _ in range(f['duration_ticks']//64):proc.stdin.write(data)
            proc.stdin.close();err=proc.stderr.read().decode();assert proc.wait()==0,err
    raw=Path(args.decoded_dir)
    selected=[1,7,40,41,42,43,44,45,46,47,48,49,65,83,84]
    for page in range(5):
        sheet=Image.new('RGB',(1200,1032),'#26313c')
        for row,n in enumerate(selected[page*3:page*3+3]):
            src=build.fixed(Image.open(raw/f'frame_{n:03}.png').convert('RGBA'))
            out=Image.open(root/'frames'/f'attack_{n:04}.png')
            for col,p in enumerate((pane(src,'#eee'),pane(out,'#172638'),pane(out,'#eadfca'))):sheet.paste(p,(col*400,row*344+24))
            ImageDraw.Draw(sheet).text((8,row*344+5),f'NEW {n} / ORIGINAL {n+9}: cropped source | candidate dark | candidate light',fill='white')
        sheet.save(review/f'critical-source-dark-light-{page+1}.jpg',quality=95)
    # Direct same-source-frame alignment check. Original 16 => new 7 => old
    # runtime attack_01. Comparing first frames instead confounds source motion.
    old=Image.open(repo/'bear-forehand-showcase/art/attack/attack_01.png').convert('RGBA')
    new=Image.open(root/'frames/attack_0007.png').convert('RGBA')
    comp=Image.new('RGB',(800,344),'#26313c');comp.paste(pane(old,'#172638'),(0,24));comp.paste(pane(new,'#172638'),(400,24))
    ImageDraw.Draw(comp).text((6,4),'SAME ORIGINAL 16: current 20-frame runtime | new 84-frame candidate',fill='white');comp.save(review/'alignment-same-source-frame.jpg',quality=96)
    with wave.open(str(root/'audio/source-track.wav')) as w: pcm=w.readframes(w.getnframes());rate=w.getframerate()
    sourcepcm=subprocess.run([args.ffmpeg,'-v','error','-i',str(build.SOURCE),'-map','0:a:0','-f','s16le','-'],stdout=subprocess.PIPE,check=True).stdout
    assert pcm==sourcepcm
    assert build.sha(build.SOURCE)==m['source_sha256']
    qa=dict(frame_count=84,original_source_frames=[10,93],all_source_pts_preserved=True,all_png_hashes_match=True,
      outer_four_pixels_alpha_zero=True,source_audio_pcm_exact=True,audio_sample_rate=rate,audio_samples=len(pcm)//4,
      video_duration_ticks=46080,time_base=[1,15360],preview_fps=240,preview_repeats_only_to_represent_exact_vfr=True,
      board_sha256=build.sha(boardpath),canvas=m['canvas'],global_translation=m['global_translation'],
      first_frame_visible_height=(metrics[0]['bbox'][3]-metrics[0]['bbox'][1])*.75,metrics=metrics,
      visual_status='requires separate authored visual conclusion; numeric checks are not visual approval',runtime_status='not integrated')
    (review/'qa.json').write_text(json.dumps(qa,indent=2)+'\n')
    (review/'preview.html').write_text('''<!doctype html><meta charset="utf-8"><title>熊山君正面84帧候选</title>
<style>body{background:#172638;color:#eee;font:16px system-ui;margin:24px}video{width:100%;max-width:1440px}p{max-width:900px}</style>
<h1>熊山君正面 · 84帧候选</h1><p>已裁剪的3秒动作，原声同步。素材离线预览，尚未接入游戏。点击播放可连续循环；下方检查深浅底。</p>
<video controls loop preload="auto" src="all-frames-board.mp4"></video>
<video controls loop preload="auto" src="all-frames-dark-light-board.mp4"></video>''')
    print(json.dumps({k:v for k,v in qa.items() if k!='metrics'}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',default=str(build.HERE));p.add_argument('--ffmpeg',required=True)
    p.add_argument('--decoded-dir',required=True);p.add_argument('--no-video',action='store_true');main(p.parse_args())
