"""Encode real Godot viewport frames; no generated/invented animation frames."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--fps", type=int, default=15)
    parser.add_argument("--width", type=int, default=960)
    args = parser.parse_args()
    paths = sorted(args.frames.glob("frame-*.png"))
    if not paths:
        raise SystemExit("No captured frames")
    frames = []
    for path in paths:
        with Image.open(path) as original:
            rgb = original.convert("RGB")
            rgb.thumbnail((args.width, round(args.width * original.height / original.width)), Image.Resampling.LANCZOS)
            frames.append(rgb.copy())
    # One shared palette avoids frame-to-frame color pumping in a static environment.
    samples = [frames[round(i * (len(frames) - 1) / 7)] for i in range(8)]
    atlas = Image.new("RGB", (frames[0].width * 4, frames[0].height * 2))
    for i, frame in enumerate(samples):
        atlas.paste(frame, ((i % 4) * frame.width, (i // 4) * frame.height))
    palette = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    encoded = [f.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for f in frames]
    # GIF has a 10 ms clock: distribute rounding so 15 fps does not become 14.3 fps.
    duration = [(round((i + 1) * 100 / args.fps) - round(i * 100 / args.fps)) * 10 for i in range(len(frames))]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    encoded[0].save(args.output, save_all=True, append_images=encoded[1:], duration=duration, loop=0, optimize=False)
    sheet = Image.new("RGB", (1440, 250 * 4), "#142728")
    draw = ImageDraw.Draw(sheet)
    for i in range(12):
        index = round(i * (len(frames) - 1) / 11)
        thumb = frames[index].copy()
        thumb.thumbnail((480, 225), Image.Resampling.LANCZOS)
        x, y = (i % 3) * 480, (i // 3) * 250
        sheet.paste(thumb, (x, y))
        draw.text((x + 8, y + 230), f"{index / args.fps:.2f}s", fill="white")
    sheet.save(args.output.with_name(args.output.stem + "-contact.jpg"), quality=92)
    print(f"{len(frames)} real frames; {sum(duration)/1000:.2f}s; {args.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
