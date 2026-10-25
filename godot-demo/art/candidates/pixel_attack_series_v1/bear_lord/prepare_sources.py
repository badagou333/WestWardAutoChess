#!/usr/bin/env python3
"""Rebuild masked, imagegen-painted limb corrections; never edits game files."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save_exact(image, path):
    image.save(path, lossless=True, exact=True)
    restored = Image.open(path).convert('RGBA')
    assert restored.tobytes() == image.convert('RGBA').tobytes()
    return {'file': str(path.relative_to(ROOT)), 'sha256': sha(path.read_bytes()),
            'rgba_pixel_sha256': sha(restored.tobytes()), 'lossless_rgba_exact': True}


def patch(base, name, source_box, pad, polygon, registration=(0, 0)):
    """Register a newly drawn crop at a declared point and copy only its mask."""
    original = np.array(base).copy()
    edit = Image.open(ROOT / 'source' / f'{name}_edit.webp').convert('RGBA')
    edit = edit.resize((300, 300), Image.Resampling.NEAREST)
    registered = Image.new('RGBA', (300, 300))
    registered.alpha_composite(edit, tuple(registration))
    mask = Image.new('L', (300, 300))
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    left, top, right, bottom = source_box
    offset = (left - pad[0], top - pad[1])
    full_mask = Image.new('L', base.size)
    full_mask.paste(mask, offset)
    layer = Image.new('RGBA', base.size)
    layer.alpha_composite(registered, offset)
    chosen = np.array(full_mask) > 0
    result = original.copy()
    result[chosen] = np.array(layer)[chosen]
    outside = np.array_equal(result[~chosen], original[~chosen])
    assert outside
    changed = np.any(result != original, axis=2)
    ys, xs = np.nonzero(changed)
    report = {'edit': name, 'source_crop': source_box, 'input_pad': pad,
              'normalize_canvas': [300, 300], 'resampling': 'nearest',
              'registration': list(registration), 'mask_polygon': polygon,
              'mask_outside_source_crop': bool(np.any(np.array(mask)[:pad[1]])),
              'changed_rgba_pixels': int(changed.sum()),
              'changed_bbox': [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)],
              'outside_mask_rgba_exact': outside}
    return Image.fromarray(result), report


def main():
    base = Image.open(ROOT / 'source' / 'sheet_base.webp').convert('RGBA')
    image = base.copy()
    reports = []
    hand_shape = [[70,80],[118,35],[164,42],[182,96],[164,137],
                  [207,147],[251,179],[257,225],[243,257],[200,263],
                  [140,250],[110,215],[95,179],[84,140]]
    image, result = patch(image, 'ready_hand', [140,90,350,335], [45,27], hand_shape, (8,-9))
    reports.append(result)
    load_shape = [[73,71],[115,43],[159,39],[181,91],[165,131],
                  [205,146],[254,183],[257,222],[238,258],[193,264],
                  [140,248],[109,214],[91,174],[82,126]]
    image, result = patch(image, 'load_hand', [620,35,830,300], [45,17], load_shape)
    reports.append(result)
    recovery_hand_shape = [[20,95],[67,95],[121,125],[183,146],
                           [207,177],[203,210],[147,216],[91,202],[30,180]]
    image, result = patch(image, 'recovery_grip', [630,610,890,830], [20,40], recovery_hand_shape)
    reports.append(result)
    # Recovery is genuinely repainted with a flexed leg. Its new drawing has
    # a lifted sole; only registration at the thigh determines attachment.
    recovery_leg_shape = [[69,91],[131,105],[179,139],[224,179],
                          [253,227],[253,264],[110,264],[77,222],[68,166]]
    image, result = patch(image, 'recover_front', [830,825,992,1008], [69,58], recovery_leg_shape)
    reports.append(result)
    step_shape = [[79,81],[126,87],[172,117],[219,164],[239,207],
                  [239,261],[93,261],[73,220],[65,164]]
    # Match the ready front-toe ground contact during the coil. The same
    # newly drawn flexed leg then unweights before its inward placement.
    image, result = patch(image, 'step_front', [850,355,992,539], [79,58], step_shape, (24,4))
    result['purpose'] = 'Coil planted toe registered to ready; not an animation-time shoe translation.'
    reports.append(result)
    main_record = save_exact(image, ROOT / 'source' / 'sheet_prepared.webp')
    # One additional real leg pose, over the unchanged loaded body, creates
    # a readable inward step before the front foot lands for the downswing.
    step_image, result = patch(image, 'step_front', [850,355,992,539], [79,58], step_shape, (-12,-12))
    reports.append(result)
    step_record = save_exact(step_image, ROOT / 'source' / 'sheet_step.webp')
    result = {'schema': 'bear-lord-masked-source-preparation-v1',
              'base_source': 'source/sheet_base.webp',
              'base_rgba_sha256': sha(base.tobytes()),
              'patches': reports, 'outputs': [main_record, step_record],
              'whole_body_transform': False,
              'new_art': 'All changed limbs were redrawn by built-in image_gen; fixed crop normalization and declared limb registration only.'}
    (ROOT / 'source' / 'preparation_report.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'patches': len(reports), 'outputs': result['outputs']}, indent=2))


if __name__ == '__main__':
    main()
