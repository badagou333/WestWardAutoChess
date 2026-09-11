"""Create a review GIF and sampled contact directly from the Godot comparison render."""
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parent
suffix = '-foxfire' if '--foxfire' in sys.argv else ''
paths = sorted((ROOT/('.capture/comparison'+suffix)).glob('[0-9][0-9][0-9].png'))
assert len(paths) == 96
frames = [Image.open(path).convert('RGB') for path in paths]
palette = frames[38].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
indexed[0].save(ROOT/('frame-comparison'+suffix+'.gif'), save_all=True, append_images=indexed[1:],
                duration=[40,40,50,40,40,40]*16, loop=0, optimize=True, disposal=1)
width,height = frames[0].size
contact = Image.new('RGB',(width*2,height*2))
for offset, sample in zip([(0,0),(width,0),(0,height),(width,height)], [30,34,36,40] if suffix else [8,14,38,43]):
    contact.paste(frames[sample],offset)
contact.save(ROOT/('frame-comparison'+suffix+'-contact.png'))
print('FRAME_COMPARISON_GIF_OK: 4 seconds, 24 fps'+suffix)
