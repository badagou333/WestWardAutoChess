#!/bin/zsh
# Rebuild into a NEW directory, not inside the candidate; no review videos or images are generated.
# Usage: ./rebuild.zsh /absolute/path/to/new-output
# Optional C3_PYTHON, C3_FFMPEG, C3_VIDEO2D_SCRIPT. Exact bytes are version-dependent.
set -euo pipefail
pkg="${0:A:h}"
if (( $# != 1 )); then print -u2 'Usage: ./rebuild.zsh /absolute/path/to/new-output'; exit 2; fi
out="$1"
if [[ "$out" != /* || -e "$out" || -L "$out" ]]; then print -u2 'Output must be an absolute, nonexistent path'; exit 2; fi
py="${C3_PYTHON:-python3}"
ff="${C3_FFMPEG:-ffmpeg}"
skill="${C3_VIDEO2D_SCRIPT:-$HOME/.codex/skills/video2dsprite/scripts/video2dsprite.py}"
command -v "$py" >/dev/null || { print -u2 'Python executable not found'; exit 1; }
command -v "$ff" >/dev/null || { print -u2 'FFmpeg executable not found'; exit 1; }
[[ -f "$skill" ]] || { print -u2 'video2dsprite script missing; set C3_VIDEO2D_SCRIPT'; exit 1; }
"$py" -c 'import PIL,numpy,scipy' || { print -u2 'Requires Pillow, NumPy and SciPy'; exit 1; }
"$py" - "$pkg" "$out" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve()
if out==p or p in out.parents: raise SystemExit('Output must be outside candidate directory')
h=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
m=json.loads((p/'manifest.json').read_text()); f=p/m['original_frozen_manifest']
if h(f)!=m['original_frozen_manifest_sha256']: raise SystemExit('Frozen manifest hash mismatch')
for key in ('source_video','audio','original_tool_qa'):
 if h(p/m[key]['file'])!=m[key]['sha256']: raise SystemExit(key+' hash mismatch')
for x in m['frames']:
 if h(p/x['file'])!=x['sha256']: raise SystemExit(f"candidate frame {x['index']} hash mismatch")
print('Frozen candidate inputs verified')
PY
mkdir -p "${out:h}"
mkdir "$out"
mkdir -p "$out/work/raw" "$out/work/matte-input" "$out/logs" "$out/frames" "$out/audio"
print 'Decoding with FFmpeg showinfo fallback; no ffprobe inspection claimed.'
"$ff" -hide_banner -i "$pkg/source/attack-8490-fast-accepted.mp4" -map 0:v:0 -vf showinfo -fps_mode passthrough -start_number 0 "$out/work/raw/frame_%06d.png" > "$out/logs/ffmpeg-decode.log" 2>&1
"$py" "$pkg/scripts/matte_pale_background.py" --input "$out/work/raw" --output "$out/work/matte-input" --report "$out/logs/matte-regions.json" > "$out/logs/matte-build.log" 2>&1
# Original workflow's alpha passthrough; resulting QA may fail. Preserve it as-is.
"$py" "$skill" clean --raw-dir "$out/work/matte-input" --output-dir "$out/work/skill-clean" --key-mode none --pockets keep --despill-mode off --temporal-stability off --workers 2 > "$out/logs/skill-clean.log" 2>&1
"$py" - "$pkg" "$out" <<'PY'
from pathlib import Path
import hashlib,json,re,shutil,sys
p=Path(sys.argv[1]); out=Path(sys.argv[2]); m=json.loads((p/'manifest.json').read_text())
a=json.loads((p/'logs/timing-audit.json').read_text()); log=(out/'logs/ffmpeg-decode.log').read_text()
rows=re.findall(r'\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:\s*([\d.]+)\s+duration:\s*(\d+)',log)
if len(rows)!=98:raise SystemExit(f'Expected 98 decoded samples, got {len(rows)}')
h=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
for x,t,row in zip(m['frames'],a['frames'],rows):
 i=x['index']; n,pts,sec,dur=row
 if (int(n),int(pts),int(dur))!=(i,x['pts_ticks'],x['source_duration_ticks']) or t['pts_ticks']!=x['pts_ticks']:
  raise SystemExit(f'PTS or duration mismatch frame {i}')
 src=out/f'work/skill-clean/clean_{i:04d}.png'; dest=out/f'frames/frame_{i:06d}.png'
 if h(src)!=x['original_sha256']:raise SystemExit(f'Original candidate byte mismatch frame {i}')
 shutil.copyfile(src,dest)
print('Original 98 frame bytes, time and duration match recorded source')
PY
"$py" "$pkg/scripts/apply_local_mask.py" "$out/frames"
cp "$pkg/audio/feather-selected.wav" "$out/audio/"
"$py" - "$pkg" "$out" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);o=Path(sys.argv[2]);m=json.loads((p/'manifest.json').read_text());h=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
for f in m['frames']:
 q=o/f['file']
 if h(q)!=f['sha256']:raise SystemExit(f"Frozen mismatch frame {f['index']}")
if h(o/m['audio']['file'])!=m['audio']['sha256']:raise SystemExit('Selected audio mismatch')
qa=json.loads((o/'work/skill-clean/matte-report.json').read_text())
print('Frozen 98 frame hashes, PTS/durations and selected WAV match; generated matte QA report retained in work/skill-clean.')
print('Inspect generated QA report; this verification is not visual, runtime or audio acceptance.')
PY
print "Completed cold rebuild: $out"
