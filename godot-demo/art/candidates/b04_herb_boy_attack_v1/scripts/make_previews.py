#!/usr/bin/env python3
"""Review evidence for the B4 candidate (not part of the byte-exact rebuild).

  python -I make_previews.py --pkg <candidate dir> --out <evidence dir> [--board <png>] [--scale 0.16]

Writes full 84-frame contact sheets on dark/light backgrounds, continuous previews at the real
per-frame PTS with the original WAV (dark, light, board at proposed piece size), and timing.json.
"""
import argparse, json, wave
from fractions import Fraction
from pathlib import Path

import av
import numpy as np
from PIL import Image, ImageDraw

DARK = (40, 44, 52)
LIGHT = (246, 246, 246)
VIEWPORT = (1440, 810)
BOARD_FOOT = (720, 441)  # bear-forehand-showcase world foot point on forest-board.png (1440x810)


def load(pkg):
    m = json.loads((pkg / 'manifest.json').read_text(encoding='utf-8'))
    frames = [np.asarray(Image.open(pkg / f['file']).convert('RGBA')) for f in m['frames']]
    return m, frames


def over(rgba, bg):
    a = rgba[..., 3:4].astype(np.float32) / 255
    return (rgba[..., :3] * a + np.asarray(bg, np.float32) * (1 - a) + 0.5).astype(np.uint8)


def sheet(m, frames, bg, path, cols=12, tw=216):
    h0, w0 = frames[0].shape[:2]
    th = int(round(tw * h0 / w0))
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGB', (cols * tw, rows * (th + 14)), (128, 128, 128))
    dr = ImageDraw.Draw(im)
    fx, fy = m['foot']
    for i, f in enumerate(frames):
        t = Image.fromarray(over(f, bg)).resize((tw, th), Image.LANCZOS)
        x, y = (i % cols) * tw, (i // cols) * (th + 14)
        im.paste(t, (x, y + 14))
        dr.text((x + 3, y + 1), f"{i} {m['frames'][i]['time_s']:.3f}s", fill=(255, 255, 0))
        cx, cy = x + fx * tw / w0, y + 14 + fy * th / h0
        dr.line([cx - 4, cy, cx + 4, cy], fill=(255, 0, 0)); dr.line([cx, cy - 4, cx, cy + 4], fill=(255, 0, 0))
    im.save(path, quality=88)


def read_wav(path):
    with wave.open(str(path)) as w:
        n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
        data = np.frombuffer(w.readframes(n), '<i2').reshape(-1, ch).T.copy()
    return data, sr


def encode(m, pkg, frame_imgs, path, size):
    """frame_imgs: list of RGB uint8 arrays (same size). Uses real PTS (1/15360 time base)."""
    pcm, sr = read_wav(pkg / m['audio']['file'])
    c = av.open(str(path), 'w')
    vs = c.add_stream('libx264', rate=Fraction(24, 1))
    vs.width, vs.height = size
    vs.pix_fmt = 'yuv420p'
    vs.time_base = Fraction(1, 15360)
    vs.options = {'crf': '20', 'preset': 'medium'}
    vs.codec_context.time_base = Fraction(1, 15360)
    as_ = c.add_stream('aac', rate=sr)
    as_.layout = 'stereo'
    for f, img in zip(m['frames'], frame_imgs):
        vf = av.VideoFrame.from_ndarray(img, format='rgb24')
        vf.pts = f['pts']
        vf.time_base = Fraction(1, 15360)
        for p in vs.encode(vf):
            c.mux(p)
    for p in vs.encode():
        c.mux(p)
    fr = as_.codec_context.frame_size or 1024
    flt = (pcm.astype(np.float32) / 32768.0)
    for s in range(0, flt.shape[1], fr):
        chunk = np.ascontiguousarray(flt[:, s:s + fr])
        af = av.AudioFrame.from_ndarray(chunk, format='fltp', layout='stereo')
        af.sample_rate = sr
        af.pts = s
        af.time_base = Fraction(1, sr)
        for p in as_.encode(af):
            c.mux(p)
    for p in as_.encode():
        c.mux(p)
    c.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--pkg', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--board', type=Path)
    ap.add_argument('--scale', type=float, default=0.16)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    m, frames = load(a.pkg)
    sheet(m, frames, DARK, a.out / 'all-frames-dark.jpg')
    sheet(m, frames, LIGHT, a.out / 'all-frames-light.jpg')
    h0, w0 = frames[0].shape[:2]
    half = (w0 // 2 // 2 * 2, h0 // 2 // 2 * 2)
    for name, bg in [('preview-dark.mp4', DARK), ('preview-light.mp4', LIGHT)]:
        imgs = [np.asarray(Image.fromarray(over(f, bg)).resize(half, Image.LANCZOS)) for f in frames]
        encode(m, a.pkg, imgs, a.out / name, half)
    if a.board:
        board = Image.open(a.board).convert('RGB')
        bw, bh = VIEWPORT  # showcase draws forest-board.png stretched to its 1440x810 viewport
        board = board.resize(VIEWPORT, Image.LANCZOS)
        fx, fy = m['foot']
        sw, sh = int(round(w0 * a.scale)), int(round(h0 * a.scale))
        ox, oy = int(round(BOARD_FOOT[0] - fx * a.scale)), int(round(BOARD_FOOT[1] - fy * a.scale))
        imgs, heights = [], []
        for f in frames:
            spr = Image.fromarray(f, 'RGBA').resize((sw, sh), Image.LANCZOS)
            b = board.copy(); b.paste(spr, (ox, oy), spr)
            imgs.append(np.asarray(b))
            al = np.asarray(spr)[..., 3] > 128
            ys = np.nonzero(al.any(axis=1))[0]
            heights.append(int(ys.max() - ys.min() + 1))
        encode(m, a.pkg, imgs, a.out / 'preview-board-actual-size.mp4', (bw, bh))
        # 2x crop stills around the piece for a few frames
        keys = [0, 20, 30, 33, 35, 40, 60, 83]
        crops = [Image.fromarray(imgs[k]).crop((BOARD_FOOT[0] - 160, BOARD_FOOT[1] - 160,
                                                 BOARD_FOOT[0] + 160, BOARD_FOOT[1] + 60)) for k in keys]
        st = Image.new('RGB', (crops[0].width * 4, crops[0].height * 2))
        for k, cimg in enumerate(crops):
            st.paste(cimg, ((k % 4) * cimg.width, (k // 4) * cimg.height))
        st.save(a.out / 'board-actual-size-keyframes.png')
        (a.out / 'board-preview.json').write_text(json.dumps({
            'board': 'bear-forehand-showcase/art/forest-board.png (read only, resized to viewport)', 'board_size': [bw, bh], 'world_foot': list(BOARD_FOOT),
            'proposed_total_scale_from_canvas': a.scale, 'sprite_size_px': [sw, sh],
            'visible_height_px_min_max': [min(heights), max(heights)],
            'keyframes_in_png': keys,
            'note': 'proposal for review only; bear reference is ~118 px visible height on this board'},
            ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('previews written to', a.out)


if __name__ == '__main__':
    main()
