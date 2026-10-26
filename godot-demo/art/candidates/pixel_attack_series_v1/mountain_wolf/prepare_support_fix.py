#!/usr/bin/env python3
"""Register imagegen foreleg repairs and preserve the audited body pixels.

The leg articulation comes from the stored imagegen artwork. Existing paw
cutouts are reused at the same world position to keep a planted support
identical across adjacent poses. No body is warped, rotated or interpolated.
"""
from pathlib import Path
from collections import deque
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
BASE = ROOT / 'history/before_foot_fix'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize(path, size, palette):
    raw = Image.open(path).convert('RGBA').resize(size, Image.Resampling.NEAREST)
    a = np.asarray(raw)
    mask = a[:, :, 3] >= 128
    values, inverse = np.unique(a[:, :, :3][mask], axis=0, return_inverse=True)
    centers = np.asarray(palette, dtype=np.int32)
    indices = []
    for start in range(0, len(values), 4096):
        delta = values[start:start+4096].astype(np.int32)[:, None, :] - centers[None, :, :]
        indices.extend(np.argmin(np.sum(delta * delta, axis=2), axis=1))
    out = np.zeros(a.shape, dtype=np.uint8)
    out[:, :, 3] = np.where(mask, 255, 0)
    out[:, :, :3][mask] = centers[np.asarray(indices, dtype=int)][inverse]
    return Image.fromarray(out)


def translated(image, offset):
    result = Image.new('RGBA', (448,448), (0,0,0,0))
    result.alpha_composite(image, offset)
    return result


def polygon(points):
    image = Image.new('L', (448,448), 0)
    ImageDraw.Draw(image).polygon(points, fill=255)
    return np.asarray(image) != 0


def copy_region(result, donor, box, offset=(0,0)):
    x0,y0,x1,y1 = box
    dx,dy = offset
    result[y0+dy:y1+dy,x0+dx:x1+dx] = np.asarray(donor)[y0:y1,x0:x1]


def main():
    manifest = json.loads((BASE/'manifest.json').read_text())
    palette = manifest['body_palette_rgb']
    bodies = {str(i): Image.open(BASE/'frames'/f'{i}.png').convert('RGBA') for i in range(6)}
    contact = normalize(ROOT/'source/contact_support_edit.webp', (448,448), palette)
    recoil = normalize(ROOT/'source/recoil_support_edit.webp', (89,116), palette)
    # Root registration is local to the newly illustrated leg regions.
    near = np.asarray(translated(contact, (-25,0)))
    far = np.asarray(translated(contact, (-10,0)))
    near_mask = polygon([(240,310),(251,307),(263,310),(276,318),(292,345),(303,369),(302,389),(240,389),(240,345)])
    far_mask = polygon([(302,309),(329,309),(343,335),(360,356),(364,389),(300,391),(296,345)])
    near_clear = polygon([(245,318),(282,317),(306,342),(349,366),(350,394),(237,394),(239,344)])
    far_clear = polygon([(309,308),(337,309),(374,339),(413,361),(417,396),(298,396),(297,343)])
    clear_mask = near_clear | far_clear
    original3 = np.asarray(bodies['3'])
    patched3 = original3.copy()
    patched3[clear_mask] = 0
    patched3[far_mask] = far[far_mask]
    patched3[near_mask] = near[near_mask]
    # Reuse the exact already-planted near forepaw from the preceding pose.
    near_paw_box = (244,350,300,388)
    patched3[350:388,244:302] = 0
    copy_region(patched3, bodies['2'], near_paw_box)
    # The far paw was airborne in pose2. It lands here, then remains fixed
    # through pose4; only the leg above it is newly articulated.
    far_paw_box = (286,350,344,387)
    far_paw_offset = (15,0)
    copy_region(patched3, bodies['4'], far_paw_box, far_paw_offset)
    mask3 = clear_mask | near_mask | far_mask
    mask3[350:388,244:302] = True
    mask3[350:387,301:359] = True
    original4 = np.asarray(bodies['4'])
    patched4 = original4.copy()
    mask4 = polygon([(273,315),(305,315),(326,340),(356,356),(363,389),(277,390),(270,350)])
    recoil_registered = np.asarray(translated(recoil, (267,278)))
    patched4[mask4] = recoil_registered[mask4]
    copy_region(patched4, bodies['4'], far_paw_box, far_paw_offset)
    mask4[350:387,301:359] = True
    if not np.array_equal(patched3[~mask3], original3[~mask3]):
        raise ValueError('Contact pose changed outside foreleg repair masks')
    if not np.array_equal(patched4[~mask4], original4[~mask4]):
        raise ValueError('Recoil pose changed outside foreleg repair masks')
    # The already illustrated airborne far foreleg supplies the final return
    # step. Ready/load/open poses remain completely unchanged.
    donor_open = bodies['2'].copy()
    original5 = np.asarray(bodies['5'])
    patched5 = original5.copy()
    clear5 = polygon([(280,286),(308,290),(339,328),(371,359),(376,394),(287,394),(273,332)])
    air5 = polygon([(276,287),(309,289),(337,308),(362,328),(368,359),(323,365),(296,340),(273,316)])
    mask5 = clear5 | air5
    patch_air5 = np.asarray(translated(donor_open, (-22,0)))
    patched5[mask5] = 0
    patched5[air5] = patch_air5[air5]
    modified = [('3',original3,patched3,mask3),('4',original4,patched4,mask4),
                ('5',original5,patched5,mask5)]
    removed_fragments = []
    for key,old,new,mask in modified:
        if not np.array_equal(new[~mask], old[~mask]):
            raise ValueError(f'Body {key} changed outside registered foreleg masks')
        visible = new[:,:,3] > 0
        connected = np.zeros(visible.shape, dtype=bool)
        queue = deque([(170,270)])
        connected[270,170] = True
        while queue:
            x,y = queue.popleft()
            for yy in range(max(0,y-1),min(448,y+2)):
                for xx in range(max(0,x-1),min(448,x+2)):
                    if visible[yy,xx] and not connected[yy,xx]:
                        connected[yy,xx] = True
                        queue.append((xx,yy))
        stray = visible & ~connected
        if np.any(stray):
            if int(stray.sum()) > 128 or np.any(stray & ~mask):
                raise ValueError(f'Body {key} has a detached anatomical part')
            yy,xx = np.where(stray)
            removed_fragments.append({'body':key,'pixels':int(stray.sum()),
                                      'bbox':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]})
            new[stray] = 0
        bodies[key] = Image.fromarray(new)
    out = ROOT/'source/support_fixed_bodies'
    out.mkdir(exist_ok=True)
    for key,image in bodies.items():
        image.save(out/f'{key}.png')
    for key,old,new,mask in modified:
        Image.fromarray(np.where(mask,255,0).astype(np.uint8)).save(ROOT/'source'/f'support_mask_{key}.png')
    sheet = Image.new('RGBA', (448*3,448*2), (0,0,0,0))
    for i in range(6):
        sheet.alpha_composite(bodies[str(i)], ((i%3)*448,(i//3)*448))
    path = ROOT/'source/support_fixed_448_sheet.webp'
    sheet.save(path, lossless=True, exact=True, method=6)
    if sheet.tobytes()!=Image.open(path).convert('RGBA').tobytes():
        raise ValueError('Prepared source WebP must retain all RGBA')
    report = {'date':'2026-10-26','changes':[], 'removed_edit_fragments':removed_fragments,
              'near_paw_planted_body_ids':['2','3'],
              'near_paw_exact_box':list(near_paw_box),
              'far_paw_airborne_body_ids':['2','5'],
              'far_paw_pose3_to4_exact_box':[301,350,359,387],
              'far_paw_donor_pose4_box':list(far_paw_box),
              'far_paw_registration':list(far_paw_offset),
              'contact_near_leg_registration':[-25,0],
              'contact_far_leg_registration':[-10,0],
              'recoil_leg_registration':[267,278],
              'prepared_source':{'file':'source/support_fixed_448_sheet.webp','sha256':digest(path),
                                 'rgba_pixel_sha256':hashlib.sha256(sheet.tobytes()).hexdigest(),
                                 'scale':1.0,'note':'existing448 body registration plane; no whole-body resampling'}}
    for key,old,new,mask in modified:
        new=np.asarray(bodies[key]);changed=np.any(old!=new,axis=2)
        y,x=np.where(changed)
        report['changes'].append({'body':key,'changed_pixels':int(changed.sum()),
                                  'changed_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)],
                                  'outside_mask_RGBA_exact':bool(np.array_equal(old[~mask],new[~mask]))})
    (ROOT/'source/support_fix_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':
    main()
