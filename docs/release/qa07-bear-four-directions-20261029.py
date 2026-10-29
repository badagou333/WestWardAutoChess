#!/usr/bin/env python3
"""Independent asset/provenance audit; never edits delivered assets.

Run with Python + Pillow/NumPy, --ffmpeg PATH, and optional --rebuild.
The rebuild runs in an isolated temporary directory, then checks all outputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import wave

import numpy as np
from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--ffmpeg', required=True)
    parser.add_argument('--rebuild', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.root
    base = root/'godot-demo/art/candidates/bear_lord_back_attack_v1'
    source = base/'source/bear-back-short-repaired-v1.mp4'
    m = json.loads((base/'manifest.json').read_text())
    failures = []
    checks = 0

    def check(ok, label):
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(label)

    check(digest(source) == '30ef7c2cf59580e9b257300cd884fda4fa10359490389f98553889cbe97c1682', 'approved source SHA')
    check(m['source_sha256'] == digest(source), 'manifest source SHA')
    check(m['source_back'] is True and m['source_sign'] == 1, 'back source direction')
    check(m['canvas'] == [384, 320] and m['foot'] == [177, 213], 'canvas and local foot')
    check(m['source_foot'] == [471, 711] and m['global_scale'] == .35, 'fixed source transform')
    check(m['display_scale'] == .75, 'display scale')
    p = subprocess.run([args.ffmpeg, '-hide_banner', '-i', str(source), '-map', '0:v:0',
                        '-vf', 'showinfo', '-fps_mode', 'passthrough', '-f', 'null', '-'],
                       capture_output=True, check=True)
    log = p.stderr.decode()
    times = [(int(i), int(t), int(d)) for i,t,d in re.findall(
        r'n:\s*(\d+) pts:\s*(-?\d+) pts_time:[\d.-]+\s+duration:\s*(\d+)', log)]
    tb = tuple(map(int, re.search(r'config in time_base: (\d+)/(\d+)', log).groups()))
    check(tb == (1, 12288) and len(times) == 340, 'independently decoded 340 frames and timebase')
    check(len(m['frames']) == 340 == m['decoded_frame_count'], 'complete manifest')
    check(len(list((base/'frames').glob('*.png'))) == 340, 'exact frame file set')
    hashes = []
    bboxes = []
    alpha_zero_rgb_max = 0
    for i, (entry, timing) in enumerate(zip(m['frames'], times)):
        index, pts, ticks = timing
        path = base/'frames'/entry['file']
        check(index == i and entry['source_frame'] == i+1 and entry['file'] == f'attack_{i+1:04d}.png', f'frame {i+1}: order')
        check(entry['source_pts'] == pts and abs(entry['source_time_seconds']-pts/12288) < 1e-12
              and abs(entry['output_time_seconds']-pts/12288) < 1e-12
              and abs(entry['duration_seconds']-ticks/12288) < 1e-12, f'frame {i+1}: original PTS/duration')
        hashes.append(digest(path))
        check(hashes[-1] == entry['sha256'], f'frame {i+1}: hash')
        im = Image.open(path)
        a = np.asarray(im)
        check(im.mode == 'RGBA' and im.size == (384, 320), f'frame {i+1}: RGBA canvas')
        check(bool(a[:,:,3].max()) and not any((a[0,:,3].any(),a[-1,:,3].any(),a[:,0,3].any(),a[:,-1,3].any())), f'frame {i+1}: nonempty, transparent borders')
        # Straight-alpha RGB at zero coverage is not a visible colour. Pillow's
        # integer unpremultiplication leaves small residuals; report, don't
        # impose a zero-RGB requirement that this asset contract never made.
        alpha_zero_rgb_max = max(alpha_zero_rgb_max, int(a[a[:,:,3] == 0,:3].max()))
        bboxes.append(im.getbbox())
        check(list(im.getbbox()) == entry['bbox'], f'frame {i+1}: actual bounds')
    check(len(set(hashes)) == m['unique_texture_count'] == 326, 'honest unique image count')
    video_end = (times[-1][1]+times[-1][2])/12288
    check(abs(video_end-m['video_duration_seconds']) < 1e-12, 'video exact end')
    audio_file = base/'audio/source-track.wav'
    with wave.open(str(audio_file)) as w:
        pcm = w.readframes(w.getnframes())
        audio = {'rate': w.getframerate(), 'channels': w.getnchannels(), 'width': w.getsampwidth(), 'samples': w.getnframes()}
    decoded = subprocess.run([args.ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', str(source),
                              '-map', '0:a:0', '-f', 's16le', '-c:a', 'pcm_s16le', '-'],
                             capture_output=True, check=True).stdout
    check(audio == {'rate':32000,'channels':2,'width':2,'samples':115968}, 'audio original format/effective length')
    check(pcm == decoded[:len(pcm)], 'PCM exactly equals approved video beginning; no replacement, mixing, reversal, or leading shift')
    tail = np.frombuffer(decoded[len(pcm):], dtype='<i2')
    check(len(decoded)//4 == 116736 and len(tail)//2 == 768 and int(np.abs(tail.astype(np.int32)).max()) <= 1, 'only near-silent AAC terminal padding removed')
    check(digest(audio_file) == m['audio']['sha256'] == 'f22f557d3a4eac26ea8055b4cfe363374361d602e7eaf0d49c9f0718fc3bd2d3', 'audio file hash')
    check(len(pcm)/128000 < video_end+.35, 'audio tail fits loop interval')
    unchanged = subprocess.run(['git', 'diff', '--name-only', '9e6089a954cf8ac4eb5064035b94cc1a5f113518', '--',
                                'bear-forehand-showcase/art/attack',
                                'bear-forehand-showcase/art/forest-board.png', 'bear-forehand-showcase/audio/source-track.wav'],
                               cwd=root, capture_output=True, text=True, check=True).stdout.strip()
    check(not unchanged, 'front 20 frames/manifest/audio/board (23 files) unchanged')
    runtime = root/'bear-forehand-showcase'
    check(all(digest(runtime/'art/back'/e['file']) == e['sha256'] for e in m['frames']), 'runtime exact copy of all 340 candidate PNGs')
    check((runtime/'art/back/manifest.json').read_bytes() == (base/'manifest.json').read_bytes(), 'runtime exact copy of candidate manifest')
    check((runtime/'audio/back-source-track.wav').read_bytes() == audio_file.read_bytes(), 'runtime exact copy of candidate audio')
    rebuild = None
    if args.rebuild:
        with tempfile.TemporaryDirectory(prefix='qa07-back-rebuild-') as tmp:
            target = Path(tmp)
            (target/'source').mkdir()
            shutil.copy2(base/'build.py', target/'build.py')
            shutil.copy2(source, target/'source'/source.name)
            import sys
            result = subprocess.run([sys.executable, str(target/'build.py'), '--ffmpeg', args.ffmpeg, '--workers', '2'],
                                    capture_output=True, text=True, check=True)
            actual = json.loads((target/'manifest.json').read_text())
            check(actual == m, 'clean full rebuild manifest equals delivered manifest')
            check(all(digest(target/'frames'/e['file']) == e['sha256'] for e in m['frames']), 'clean full rebuild all 340 PNGs byte identical')
            check(digest(target/'audio/source-track.wav') == digest(audio_file), 'clean full rebuild audio byte identical')
            rebuild = {'manifest_equal': actual == m, 'frames':340, 'audio_equal':digest(target/'audio/source-track.wav') == digest(audio_file)}
    report = {'checks': checks, 'failures':failures, 'approved_source_sha256':digest(source), 'frames':len(times),
              'unique_output_images':len(set(hashes)), 'video_end':video_end, 'audio':audio,
              'alpha_zero_rgb_max':alpha_zero_rgb_max,
              'full_rebuild':rebuild, 'baseline':'9e6089a954cf8ac4eb5064035b94cc1a5f113518',
              'front_asset_diff':unchanged,
              'limits':['Asset math/PCM checks do not certify aesthetic perfection or device listening.',
                        'Known source repair and source gray softness near frames 152–185 remain.',
                        '340 decoded frames do not imply 340 unique motion poses.']}
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
