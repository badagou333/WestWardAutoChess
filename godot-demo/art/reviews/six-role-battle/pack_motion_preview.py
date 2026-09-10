"""Pack the actual engine captures into a lightweight review animation."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent
paths = sorted((root / '.capture').glob('[0-9][0-9][0-9].png'))
assert len(paths) == 192, 'Run render_motion.gd at 1440x810 first'
frames = [Image.open(path).convert('RGB') for path in paths]
palette = frames[30].quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
indexed[0].save(root / 'motion-preview.gif', save_all=True, append_images=indexed[1:],
                duration=[40, 40, 50, 40, 40, 40] * 32, loop=0, optimize=True, disposal=1)
print('MOTION_GIF_OK: 192 frames, 8 seconds; game itself runs at display frame rate')
