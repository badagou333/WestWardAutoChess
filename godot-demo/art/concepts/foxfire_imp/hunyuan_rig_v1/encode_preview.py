"""Encode native Blender render frames as a 6-second GIF; no image generation."""
import hashlib
import json
from pathlib import Path

from PIL import Image

BASE = Path(__file__).resolve().parent
frames = sorted((BASE / "preview_frames").glob("frame-*.png"))
assert len(frames) == 49, f"Expected 49 frames, got {len(frames)}"
images = [Image.open(p).convert("RGB") for p in frames[:-1]]
assert all(i.size == (512, 512) for i in images)
output = BASE / "binding-preview.gif"
images[0].save(output, save_all=True, append_images=images[1:], duration=[120, 130] * 24,
               loop=0, disposal=2, optimize=False)
with Image.open(output) as check:
    assert check.n_frames == 48
    duration = 0
    for i in range(check.n_frames):
        check.seek(i)
        check.load()
        duration += check.info.get("duration", 0)
    report = {"file": output.name, "size": list(check.size), "frames": check.n_frames,
              "duration_ms": duration, "source": "Native Blender .blend renders; animated skinned model plus orbiting camera",
              "full_image_2d_warping": False, "game_animation": False,
              "rigged_glb_sha256": hashlib.sha256((BASE / "foxfire-rigged.glb").read_bytes()).hexdigest(),
              "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
(BASE / "preview-report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
