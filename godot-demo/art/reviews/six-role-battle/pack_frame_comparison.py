"""Create a review GIF and sampled contact directly from the Godot comparison render."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
paths = sorted((ROOT/'.capture/comparison').glob('[0-9][0-9][0-9].png'))
assert len(paths) == 96
frames = [Image.open(path).convert('RGB') for path in paths]
palette = frames[38].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
indexed[0].save(ROOT/'frame-comparison.gif', save_all=True, append_images=indexed[1:],
                duration=[40,40,50,40,40,40]*16, loop=0, optimize=True, disposal=1)
contact = Image.new('RGB',(1920,1600))
for offset, sample in zip([(0,0),(960,0),(0,800),(960,800)], [8,14,38,43]):
    contact.paste(frames[sample],offset)
contact.save(ROOT/'frame-comparison-contact.png')
print('FRAME_COMPARISON_GIF_OK: 4 seconds, 24 fps, 3 roles')
