#!/usr/bin/env python3
"""Rebuild the B4 herb boy attack candidate from the approved 8662 trim.

Usage (from any cwd):
  python -I build.py --out <new empty dir>          # cold rebuild into a fresh directory
  python -I build.py --out <dir> --compare <pkg>    # rebuild, then byte-compare frames/WAV with pkg manifest

Decodes every presented video frame with its real PTS (PyAV / FFmpeg libs), matte each frame with
scripts/matte_b04.py, crops all frames with ONE fixed rectangle (no scaling, no per-frame recentring),
and writes the original audio (edit-list range, 44.1 kHz stereo) as 16-bit PCM WAV. No regeneration,
repaint, speed change or audio processing beyond float->int16 conversion.
"""
import argparse, hashlib, json, sys, wave
from pathlib import Path

import av
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from matte_b04 import matte  # noqa: E402

REPO = HERE.parents[4]
INPUT_DIR = REPO / 'godot-demo/art/candidates/b04_herb_boy_trim_20261101'
TRIM = INPUT_DIR / 'B04-SE-attack-8662-trim.mp4'
SOURCE = INPUT_DIR / 'source-8662.mp4'
TRIM_SHA = '7a14c9b0df5bb14da5780be4757420a43c30763458866e085603f55c2945eae0'
SOURCE_SHA = '3f65c6a5b483a454324f4b38ff26df7fc3c9d9e0f9037078e62f882ff7e6d29e'
SOURCE_FRAME_OFFSET = 10          # trim frame 0 == source decoded frame 10 (0-based)
SOURCE_PTS_OFFSET = 6400          # 10/24 s in the 1/15360 time base
SOURCE_AUDIO_OFFSET = 18375       # samples, 44.1 kHz
MARGIN = 8
FOOT_ROWS = 12


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def decode_video(path):
    c = av.open(str(path))
    st = c.streams.video[0]
    tb = st.time_base
    frames = []
    for f in c.decode(st):
        frames.append((int(f.pts), f.to_ndarray(format='rgb24')))
    end = int(st.start_time or 0) + int(st.duration)
    c.close()
    return frames, tb, end


def decode_audio(path):
    c = av.open(str(path))
    st = c.streams.audio[0]
    chunks = [f.to_ndarray() for f in c.decode(st)]
    info = dict(rate=st.codec_context.sample_rate, channels=st.codec_context.channels,
                duration=int(st.duration), start=int(st.start_time or 0))
    c.close()
    return np.concatenate(chunks, axis=1), info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--compare', type=Path)
    ap.add_argument('--skip-source-check', action='store_true')
    args = ap.parse_args()
    out = args.out.resolve()
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f'refuse: {out} is not empty')
    assert sha(TRIM) == TRIM_SHA, 'trim mp4 hash mismatch'
    assert sha(SOURCE) == SOURCE_SHA, 'source mp4 hash mismatch'
    (out / 'frames').mkdir(parents=True)
    (out / 'audio').mkdir()

    frames, tb, video_end = decode_video(TRIM)
    if len(frames) != 84:
        raise SystemExit(f'expected 84 decoded frames, got {len(frames)}')
    pts = [p for p, _ in frames]
    assert pts == sorted(pts) and len(set(pts)) == len(pts), 'PTS not strictly increasing'
    distinct = all(not np.array_equal(frames[i][1], frames[i - 1][1]) for i in range(1, len(frames)))

    src_match = None
    if not args.skip_source_check:
        sframes, stb, _ = decode_video(SOURCE)
        smap = {p: (i, a) for i, (p, a) in enumerate(sframes)}
        src_match = []
        for i, (p, a) in enumerate(frames):
            j, sa = smap[p + SOURCE_PTS_OFFSET]
            assert j == i + SOURCE_FRAME_OFFSET and np.array_equal(a, sa), f'source mismatch at {i}'
            src_match.append(j)

    mattes, infos = [], []
    for i, (_, a) in enumerate(frames):
        rgba, info = matte(a)
        mattes.append(rgba)
        infos.append(info)
        if i % 12 == 0:
            print(f'matte {i + 1}/84', flush=True)

    union = np.zeros(mattes[0].shape[:2], bool)
    for m in mattes:
        union |= m[..., 3] > 0
    ys, xs = np.nonzero(union)
    H, W = union.shape
    x0, y0 = max(0, xs.min() - MARGIN), max(0, ys.min() - MARGIN)
    x1, y1 = min(W, xs.max() + 1 + MARGIN), min(H, ys.max() + 1 + MARGIN)
    edge_touch = {'left': bool(x0 == 0), 'top': bool(y0 == 0), 'right': bool(x1 == W), 'bottom': bool(y1 == H)}

    # foot anchor: frame 0 (idle), bottom FOOT_ROWS rows of opaque pixels
    a0 = mattes[0][..., 3] >= 128
    fy, fx = np.nonzero(a0)
    ymax = fy.max()
    sel = fy > ymax - FOOT_ROWS
    source_foot = [int(round(float(fx[sel].mean()))), int(ymax)]
    foot = [source_foot[0] - x0, source_foot[1] - y0]

    recs = []
    for i, m in enumerate(mattes):
        crop = m[y0:y1, x0:x1]
        name = f'b04_attack_{i:03d}.png'
        Image.fromarray(crop, 'RGBA').save(out / 'frames' / name, compress_level=9, optimize=False)
        al = crop[..., 3]
        yy, xx = np.nonzero(al)
        p = pts[i]
        nxt = pts[i + 1] if i + 1 < len(pts) else video_end
        recs.append({
            'index': i, 'file': f'frames/{name}', 'sha256': sha(out / 'frames' / name),
            'source_decoded_index': i + SOURCE_FRAME_OFFSET,
            'pts': p, 'time_s': round(p * float(tb), 6), 'duration_s': round((nxt - p) * float(tb), 6),
            'source_pts': p + SOURCE_PTS_OFFSET,
            'decoded_rgb_sha256': hashlib.sha256(frames[i][1].tobytes()).hexdigest(),
            'alpha_bbox': [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1],
            'bg_rgb': infos[i]['bg_rgb'], 'opaque_px': infos[i]['opaque_px'],
            'partial_px': infos[i]['partial_px'], 'glow_core_px': infos[i]['core_px'],
            'rim_px': infos[i]['rim_px'],
        })

    # audio: edit-list range of the trim == source samples [18375, 18375+154350)
    pcm, ainfo = decode_audio(TRIM)
    n = ainfo['duration']
    pcm = pcm[:, :n]
    spcm, _ = decode_audio(SOURCE)
    src_diff = float(np.abs(spcm[:, SOURCE_AUDIO_OFFSET:SOURCE_AUDIO_OFFSET + n] - pcm).max())
    i16 = np.clip(np.round(pcm * 32767.0), -32768, 32767).astype('<i2')
    wav_path = out / 'audio' / 'b04-attack-original.wav'
    with wave.open(str(wav_path), 'wb') as w:
        w.setnchannels(pcm.shape[0]); w.setsampwidth(2); w.setframerate(ainfo['rate'])
        w.writeframes(i16.T.copy().tobytes())
    mono = np.abs(pcm).max(axis=0)
    onset = int(np.argmax(mono >= 0.1))
    peak = int(np.argmax(mono))

    manifest = {
        'id': 'b04_herb_boy_attack_v1',
        'task': 'D-20261110-004 / D-20261102-003',
        'status': 'candidate (author-checked only; not runtime, independent or listening accepted)',
        'input': {'trim': 'godot-demo/art/candidates/b04_herb_boy_trim_20261101/B04-SE-attack-8662-trim.mp4',
                  'trim_sha256': TRIM_SHA,
                  'source': 'godot-demo/art/candidates/b04_herb_boy_trim_20261101/source-8662.mp4',
                  'source_sha256': SOURCE_SHA},
        'video': {'decoded_frames': len(frames), 'all_consecutive_frames_distinct': distinct,
                  'time_base': f'{tb.numerator}/{tb.denominator}', 'video_end_pts': video_end,
                  'video_duration_s': round(video_end * float(tb), 6),
                  'variable_frame_rate': bool(sorted(set(r['pts'] for r in recs)) != list(range(0, video_end, 640))),
                  'source_frame_range_0based': [SOURCE_FRAME_OFFSET, SOURCE_FRAME_OFFSET + len(frames) - 1],
                  'source_pixel_identical': src_match is not None},
        'canvas': {'size': [int(x1 - x0), int(y1 - y0)], 'source_size': [W, H],
                   'crop_rect_in_source': [int(x0), int(y0), int(x1), int(y1)], 'scale': 1.0,
                   'crop_touches_source_edge': edge_touch, 'margin_px': MARGIN},
        'foot': foot, 'source_foot': source_foot,
        'foot_note': f'frame 0 idle: mean x and max y of the lowest {FOOT_ROWS} rows with alpha>=128; '
                     'reference anchor only, not per-frame contact or verified cell occupancy',
        'alpha': 'straight (non-premultiplied) RGBA PNG',
        'audio': {'file': 'audio/b04-attack-original.wav', 'sha256': sha(wav_path),
                  'format': 'PCM s16le', 'sample_rate': ainfo['rate'], 'channels': int(pcm.shape[0]),
                  'samples': n, 'duration_s': round(n / ainfo['rate'], 6),
                  'offset_to_video_start_s': 0.0,
                  'source_sample_offset': SOURCE_AUDIO_OFFSET,
                  'max_abs_diff_vs_source_slice_float': src_diff,
                  'first_abs_ge_0.1_s': round(onset / ainfo['rate'], 4),
                  'peak_s': round(peak / ainfo['rate'], 4)},
        'frames': recs,
    }
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2, default=lambda o: o.item()) + '\n',
                                       encoding='utf-8', newline='\n')
    print('built', out, 'canvas', manifest['canvas']['size'], 'foot', foot, 'audio diff', src_diff)

    if args.compare:
        ref = json.loads((args.compare / 'manifest.json').read_text(encoding='utf-8'))
        bad = [r['file'] for r, q in zip(ref['frames'], recs) if r['sha256'] != q['sha256']]
        bad += [] if ref['audio']['sha256'] == manifest['audio']['sha256'] else ['audio']
        same_pts = [(r['pts'], r['duration_s']) for r in ref['frames']] == [(q['pts'], q['duration_s']) for q in recs]
        print('compare: mismatches', bad, 'pts/duration equal', same_pts)
        if bad or not same_pts:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
