#!/usr/bin/env python3
"""Assemble actual trial viewport PNGs with measured simulation timing (Pillow)."""
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

source, destination = map(Path, sys.argv[1:3])
report = json.loads((source / "capture.json").read_text())
assert report["failures"] == 0, "Do not deliver failed capture fixtures"
samples = report["samples"]
assert len(samples) == 180
assert {sample["frame"] for sample in samples} >= set(range(13))
for facing in (-1, 1):
    walking = [s for s in samples if s["pose"] == "move" and s["facing"] == facing]
    assert {s["frame"] for s in walking} == {2, 3, 4, 5}
    assert len(walking) >= 15, "At least one second / two walk cycles each way"
times = [s["simulation_time"] for s in samples]
gaps = [b - a for a, b in zip(times, times[1:])]
assert all(abs(g - 1 / 15) < 1e-6 or abs(g - 2 / 15) < 1e-6 for g in gaps)
images = [Image.open(source / f"frame-{i:03d}.png").convert("RGB") for i in range(180)]
assert all(im.size == (1280, 720) for im in images)
# Preserve every measured gap; never interpolate or conceal missing samples.
boundaries = [round((t - times[0]) * 1000) for t in times]
boundaries.append(round((times[-1] - times[0] + 1 / 15) * 1000))
durations = [b - a for a, b in zip(boundaries, boundaries[1:])]
images[0].save(destination, save_all=True, append_images=images[1:],
               duration=durations, loop=1, lossless=True, method=4)
with Image.open(destination) as clip:
    elapsed = 0
    for index in range(clip.n_frames):
        clip.seek(index)
        clip.load()
        elapsed += clip.info["duration"]
    assert clip.size == (1280, 720) and elapsed == sum(durations)
    print(f"Verified WebP: {clip.n_frames} frames; {elapsed} ms; {clip.size}")
report["requested_seconds"] = report["playback_seconds"]
report["playback_seconds"] = sum(durations) / 1000
report["assembled_playback"] = {
    "format": "WebP", "duration_ms": sum(durations), "nominal_fps": 15,
    "loop": 1, "lossless": True, "source_sample_count": 180,
    "long_sample_gaps": [{"after_index": i, "seconds": g}
                         for i, g in enumerate(gaps) if g > .08],
    "simulation_gap_min": min(gaps), "simulation_gap_max": max(gaps),
    "frame_counts": dict(Counter(s["frame"] for s in samples)),
}
destination.with_suffix(".json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n")
