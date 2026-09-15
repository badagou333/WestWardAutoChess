"""Create a review GIF and sampled contact directly from the Godot comparison render."""
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parent
suffix = '-foxfire' if '--foxfire' in sys.argv else ''
if '--herbal' in sys.argv: suffix = '-herbal'
if '--sparrow' in sys.argv: suffix = '-sparrow'
if '--monk-walk' in sys.argv: suffix = '-monk-walk'
if '--monk-recovery' in sys.argv: suffix = '-monk-recovery'
if '--hunter-recovery' in sys.argv: suffix = '-hunter-recovery'
if '--bear-recovery' in sys.argv: suffix = '-bear-recovery'
paths = sorted((ROOT/('.capture/comparison'+suffix)).glob('[0-9][0-9][0-9].png'))
assert len(paths) == 96
frames = [Image.open(path).convert('RGB') for path in paths]
palette = frames[38].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
indexed[0].save(ROOT/('frame-comparison'+suffix+'.gif'), save_all=True, append_images=indexed[1:],
                duration=[40,40,50,40,40,40]*16, loop=0, optimize=True, disposal=1)
width,height = frames[0].size
contact = Image.new('RGB',(width*2,height*2))
samples = [44,48,52,57] if suffix == '-monk-recovery' else ([30,34,36,40] if suffix else [8,14,38,43])
if suffix == '-hunter-recovery': samples = [41,44,47,52]
if suffix == '-bear-recovery': samples = [53,59,64,72]
if suffix == '-herbal': samples = [35,44,53,60]
if suffix == '-sparrow': samples = [34,40,46,51]
if suffix == '-monk-walk': samples = [11,20,43,73]
for offset, sample in zip([(0,0),(width,0),(0,height),(width,height)], samples):
    contact.paste(frames[sample],offset)
contact.save(ROOT/('frame-comparison'+suffix+'-contact.png'))
print('FRAME_COMPARISON_GIF_OK: 4 seconds, 24 fps'+suffix)
