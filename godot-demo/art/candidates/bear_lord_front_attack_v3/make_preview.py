from pathlib import Path
import argparse,json,subprocess,shutil
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parent
repo=p.parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--baseline-dir',type=Path,required=True);ap.add_argument('--output-dir',type=Path,required=True);ap.add_argument('--ffmpeg',default=shutil.which('ffmpeg') or 'ffmpeg');args=ap.parse_args()
r=args.baseline_dir;out=args.output_dir;out.mkdir(parents=True,exist_ok=True)
m=json.loads((p/'manifest.json').read_text());ff=args.ffmpeg;board=Image.open(repo/'bear-forehand-showcase/art/forest-board.png').convert('RGBA').resize((1440,810));overlay=Image.new('RGBA',board.size);d=ImageDraw.Draw(overlay);d.polygon([(720,405),(792,441),(720,477),(648,441)],fill=(112,186,148,36),outline=(169,219,177,255),width=2);d.ellipse((695,434,745,448),fill=(5,10,8,76));board.alpha_composite(overlay)
for mode in ('board','dark-light'):
 size=(800,344) if mode=='board' else (1600,344)
 cmd=[ff,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{size[0]}x{size[1]}','-r','240','-i','pipe:0','-i',str(p/'audio/source-track.wav'),'-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-t','3','-movflags','+faststart',str(out/f'{mode}-compare.mp4')];proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=subprocess.PIPE)
 for i,fr in enumerate(m['frames']):
  canvas=Image.new('RGB',size,'#26313c');ImageDraw.Draw(canvas).text((8,4),f'{i+1:02} original {i+10:02}  |  no edge fade / 24px source edge fade',fill='white')
  for col,base in enumerate((r,p)):
   im=Image.open(base/'frames'/fr['file']).convert('RGBA');tiny=im.convert('RGBa').resize((300,240),Image.Resampling.LANCZOS).convert('RGBA')
   if mode=='board':
    b=board.copy();b.alpha_composite(tiny,(587,281));canvas.paste(b.convert('RGB').crop((520,228,920,548)),(col*400,24))
   else:
    for k,bg in enumerate(('#172638','#eadfca')):
     b=Image.new('RGBA',(400,320),bg);b.alpha_composite(tiny,(50,40));canvas.paste(b.convert('RGB'),((col*2+k)*400,24))
  data=canvas.tobytes()
  for _ in range(fr['duration_ticks']//64):proc.stdin.write(data)
 proc.stdin.close();err=proc.stderr.read().decode();assert proc.wait()==0,err
print('normal-speed exact timestamp previews ready')
