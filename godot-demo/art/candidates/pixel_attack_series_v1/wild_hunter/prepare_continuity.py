#!/usr/bin/env python3
"""Repair independent-review continuity findings without repainting anatomy.

Uses the saved imagegen empty-grip/tail patch only in a declared lower-body
mask, composites the existing generated arrow behind its holding paw, then
registers the planted front boot with a local nearest-pixel ankle taper.
The six full bodies are never height-fit, globally resized, or moved.
"""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
IDS = ["00_ready", "01_nock", "02_full_draw", "03_release", "04_reach_quiver", "05_extract_arrow"]
BOOT = (180, 390, 448, 405)
BOW_PATHS = {
    "00_ready": [(244, 326), (226, 350), (212, 373)],
    "01_nock": [(250, 315), (233, 348), (232, 374)],
    "02_full_draw": [(277, 319), (267, 344)],
    "03_release": [(271, 328), (267, 346)],
    "04_reach_quiver": [(247, 326), (225, 356), (214, 379)],
    "05_extract_arrow": [(269, 327), (247, 356), (230, 379)],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_webp(image, path):
    image.save(path, format="WEBP", lossless=True, exact=True, quality=100, method=6)
    assert np.array_equal(np.asarray(image), np.asarray(Image.open(path).convert("RGBA")))


def sole(image, rear=False):
    alpha = np.asarray(image)[:, :, 3]
    if rear:
        yy, xx = np.where(alpha[380:430, 40:180] >= 128)
        y = int(380 + yy.max())
        x = np.where(alpha[y - 2:y + 1, 40:180] >= 128)[1]
        return float(40 + x.mean()), y
    yy, xx = np.where(alpha[390:405, 180:] >= 128)
    return float(180 + xx.mean()), int(390 + yy.max())


def front_boot(image, dx, dy, body_id):
    old = np.asarray(image).copy()
    work = old.copy()
    # The lower bow tip overlaps the ankle in the source. Register that small
    # overlap as one painted unit; excluding an approximate bow stroke would
    # cut a transparent diagonal slit through the wrap. Grip/upper bow stay
    # completely outside this low-leg registration band.
    protect = np.zeros((448, 448), dtype=bool)
    source_mask = np.zeros((448, 448), dtype=bool)
    source_mask[348:407, 180:290] = True
    source_mask &= ~protect
    work[source_mask] = 0
    # Inverse nearest sampling avoids the empty scanlines a forward scatter
    # would create when the sole needs a one- or two-pixel vertical correction.
    for y in range(348, 410):
        if y <= 348:
            sy = y
        elif y >= 385 + dy:
            sy = y - dy
        else:
            rate = dy / 37
            sy = round((y + rate * 348) / (1 + rate))
        if not 0 <= sy < 448:
            continue
        fraction = max(0, min(1, (sy - 348) / 37))
        shift = round(dx * fraction)
        for x in range(150, 315):
            sx = x - shift
            if 0 <= sx < 448 and source_mask[sy, sx] and old[sy, sx, 3]:
                work[y, x] = old[sy, sx]
    keep = protect & (old[:, :, 3] > 0)
    work[keep] = old[keep]
    work[work[:, :, 3] == 0] = 0
    return Image.fromarray(work)


def projectile():
    image = Image.open(ROOT / "source/arrow_repair.webp").convert("RGBA")
    array = np.asarray(image).copy()
    array[:, :, 3] = np.where(array[:, :, 3] >= 128, 255, 0)
    array[array[:, :, 3] == 0] = 0
    image = Image.fromarray(array)
    image = image.crop(image.getchannel("A").getbbox())
    return image.resize((180, max(1, round(image.height * 180 / image.width))), Image.Resampling.NEAREST)


def main():
    baseline = Image.open(ROOT / "source/baseline_pose_strip.webp").convert("RGBA")
    bodies = [baseline.crop((i * 448, 0, (i + 1) * 448, 448)) for i in range(6)]
    before = [image.copy() for image in bodies]
    donor = Image.open(ROOT / "source/empty_grip_patch.webp").convert("RGBA")
    donor = donor.resize((896, 448), Image.Resampling.NEAREST).crop((0, 0, 448, 448))
    old_rear, donor_rear = sole(bodies[0], True), sole(donor, True)
    translation = (round(old_rear[0] - donor_rear[0]), old_rear[1] - donor_rear[1])
    registered = Image.new("RGBA", (448, 448), (0, 0, 0, 0))
    registered.alpha_composite(donor, translation)
    rgba = np.asarray(registered).copy()
    rgba[:, :, 3] = np.where(rgba[:, :, 3] >= 128, 255, 0)
    rgba[rgba[:, :, 3] == 0] = 0
    registered = Image.fromarray(rgba)
    mask_image = Image.new("L", (448, 448), 0)
    draw = ImageDraw.Draw(mask_image)
    draw.rectangle((35, 245, 330, 378), fill=255)
    # The donor bow bulges farther right than the old curve guide. Include
    # its complete upper silhouette, rather than clipping the wood mid-limb.
    draw.rectangle((224, 126, 340, 246), fill=255)
    draw.line([(266, 153), (277, 174), (284, 199), (283, 224),
               (271, 266), (253, 301), (245, 326), (226, 350), (212, 373)],
              fill=255, width=64)
    draw.line([(266, 154), (212, 373)], fill=255, width=52)
    mask = np.asarray(mask_image) > 0
    mask[380:, :] = False
    repaired = np.asarray(bodies[0]).copy()
    repaired[mask] = np.asarray(registered)[mask]
    # One same generated arrow is composited in front of clothing but behind
    # the original generated holding paw, rather than a second modeled arrow.
    base = Image.fromarray(repaired)
    arrow = projectile()
    tilted = arrow.rotate(-12, resample=Image.Resampling.NEAREST, expand=True)
    # The normalized template nock is at the center of its left edge.
    tail = (tilted.width / 2 - math.cos(math.radians(12)) * 90,
            tilted.height / 2 - math.sin(math.radians(12)) * 90)
    position = (round(110 - tail[0]), round(271 - tail[1]))
    base.alpha_composite(tilted, position)
    hand = np.zeros((448, 448), dtype=bool)
    hand[260:300, 115:159] = True
    hand &= repaired[:, :, 3] > 0
    composite = np.asarray(base).copy()
    composite[hand] = repaired[hand]
    composite[composite[:, :, 3] == 0] = 0
    bodies[0] = Image.fromarray(composite)
    mask_image.save(ROOT / "source/continuity_tail_hand_mask.png")
    target = sole(before[0])
    foot_records = []
    for index, body_id in enumerate(IDS):
        current = sole(bodies[index])
        dy = target[1] - current[1]
        vertical = front_boot(bodies[index], 0, dy, body_id)
        dx = round(target[0] - sole(vertical)[0])
        corrected = front_boot(bodies[index], dx, dy, body_id)
        foot_records.append({"id": body_id, "before": list(current),
                             "translation_at_sole": [dx, dy],
                             "after": list(sole(corrected)),
                             "maximum_taper_y": 385,
                             "ankle_taper_starts_y": 348,
                             "grip_and_upper_bow_unchanged": True,
                             "lower_bow_ankle_overlap_registered_together": True})
        bodies[index] = corrected
    strip = Image.new("RGBA", (448 * 6, 448), (0, 0, 0, 0))
    for index, image in enumerate(bodies):
        strip.alpha_composite(image, (448 * index, 0))
    strip_path = ROOT / "source/continuity_body_strip.webp"
    exact_webp(strip, strip_path)
    spec = json.loads((ROOT / "source/spec_before_continuity.json").read_text())
    spec["sources"] = {"registered": {"file": "source/continuity_body_strip.webp",
        "sha256": digest(strip_path), "expected_pixel_sha256": hashlib.sha256(strip.tobytes()).hexdigest(),
        "scale": 1.0}}
    spec["bodies"] = []
    for index, (body_id, image) in enumerate(zip(IDS, bodies)):
        yy, xx = np.where(np.asarray(image)[:, :, 3] >= 128)
        seed_index = int(len(xx) // 2)
        spec["bodies"].append({"id": body_id, "name": body_id,
            "source": "registered", "source_box": [448 * index, 0, 448 * (index + 1), 448],
            "source_anchor": [448 * index + 104, 399],
            "component_seeds": [[448 * index + int(xx[seed_index]), int(yy[seed_index])]]})
    for stage in spec["track"]:
        if stage["body"] == "06_lower_arrow":
            stage["body"] = "00_ready"
    # Same 180px arrow as the held replacement; only viewport layers move.
    for index, dx in enumerate((0, 80, 160, 240)):
        canvas = Image.new("RGBA", (448, 448), (0, 0, 0, 0))
        canvas.alpha_composite(arrow, (145 + dx, 231 - arrow.height // 2))
        path = ROOT / "source/arrow_layers" / f"flight_{index}.png"
        canvas.save(path)
        spec["layers"][f"flight_{index}"] = {"file": "source/arrow_layers/" + path.name,
            "order": "behind", "sha256": digest(path),
            "expected_pixel_sha256": hashlib.sha256(canvas.tobytes()).hexdigest()}
    spec["review_annotations"].update({
        "actual_pose_count": 6,
        "removed_pose": "06_lower_arrow: opposite-side tail and reversed short arrow; replaced by the single corrected ready",
        "normalized_source_scale": "1.0 exact 448px packaging; all upstream body geometry came from common .66 source extraction, no body height fitting",
        "carried_arrow": "one generated 180px template, ready points screen-right/down 12 degrees; overhead extraction points screen-right",
        "continuity_report": "source/continuity_report.json"})
    (ROOT / "spec.json").write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n")
    report = {"role": "author_local_continuity_repairs_not_independent_gate",
        "donor_used": "left panel of empty_grip_patch only",
        "donor_registration_translation": list(translation),
        "masked_ready_source_pixels": int(mask.sum()),
        "ready_hand_overlay_restored_pixels": int(hand.sum()),
        "tail_side": "screen_left_all_adopted_poses",
        "held_arrow_template_length_px": 180, "ready_arrow_angle_down_right_deg": 12,
        "ready_arrow_tail_target": [110, 271],
        "source_scale_upstream": .66, "packaging_scale": 1.0,
        "body_height_fitting": False, "front_sole_target": list(target),
        "front_boots": foot_records,
        "removed_original_pose": "06_lower_arrow",
        "remaining_body_count": 6,
        "registered_source_sha256": digest(strip_path)}
    (ROOT / "source/continuity_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    stale = ROOT / "frames/06_lower_arrow.png"
    if stale.exists():
        stale.unlink()
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
