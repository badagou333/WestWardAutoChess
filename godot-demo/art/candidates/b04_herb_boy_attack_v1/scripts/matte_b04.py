"""B4 herb boy pale-background matte. Clip-specific (8662 trim), not a universal remover; no generation or repaint."""
import numpy as np
from scipy import ndimage as ndi

WATERMARK = (0, 0, 200, 100)  # x0,y0,x1,y1 of the "AI生成" label, outside the character
LO, HI = 5.0, 22.0


def bg_estimate(rgb):
    b = np.concatenate([rgb[-30:, :].reshape(-1, 3), rgb[:, -30:].reshape(-1, 3),
                        rgb[150:, :30].reshape(-1, 3), rgb[:20, 250:].reshape(-1, 3)])
    return np.median(b, axis=0)


def matte(rgb_u8, params=None):
    p = dict(lo=LO, hi=HI, min_comp=50, near=10, far=60, haze_sigma=2.0, green_min=6.0, rim=3.0)
    if params:
        p.update(params)
    rgb = rgb_u8.astype(np.float32)
    bg = bg_estimate(rgb)
    diff = rgb - bg
    d = np.sqrt((diff ** 2).mean(axis=2))
    a = np.clip((d - p['lo']) / (p['hi'] - p['lo']), 0, 1)
    x0, y0, x1, y1 = WATERMARK
    a[y0:y1, x0:x1] = 0
    solid = d > p['hi']
    solid[y0:y1, x0:x1] = False
    lab, _ = ndi.label(solid)
    cnt = np.bincount(lab.ravel())
    keep_ids = [k for k in range(1, len(cnt)) if cnt[k] >= p['min_comp']]
    keep = np.isin(lab, keep_ids)
    # green excess: glow light is green-dominant relative to the background
    gex = diff[..., 1] - 0.5 * (diff[..., 0] + diff[..., 2])
    lum = rgb.mean(axis=2) - bg.mean()
    dist = ndi.distance_transform_edt(~keep)
    # 1) glow cores: enclosed holes that are brighter than bg or green -> opaque
    filled = ndi.binary_fill_holes(keep)
    holes = filled & ~keep
    core = holes & ((lum > 4) | (gex > 6))
    core = ndi.binary_closing(core, iterations=1) & holes
    a = np.where(core, np.maximum(a, np.clip((np.maximum(lum, gex) - 2) / 8, 0, 1)), a)
    # 2) faint haze far from the body: smooth alpha, drop non-green specks
    faint = ((dist > p['near']) & ~filled) | (holes & ~core)
    smooth = ndi.gaussian_filter(a, p['haze_sigma'])
    gsm = ndi.gaussian_filter(gex, p['haze_sigma'])
    a = np.where(faint, smooth, a)
    a = np.where(faint & (gsm < p['green_min']), 0, a)
    a = np.where(dist > p['far'], np.where(gsm >= p['green_min'], a, 0), a)
    a[a < 1 / 255] = 0
    # un-mix background from partial pixels (straight alpha output)
    asafe = np.maximum(a, 0.05)[..., None]
    col = np.clip((rgb - (1 - a[..., None]) * bg) / asafe, 0, 255)
    # outline rim: partial pixels hugging the solid body take the nearest solid colour
    # (keeps soft alpha, removes pale background spill); glow haze is untouched
    _, (iy, ix) = ndi.distance_transform_edt(~keep, return_indices=True)
    rim = (a > 0) & (a < 0.98) & (dist <= p['rim']) & ~core & (gex <= 6)
    col[rim] = rgb[iy[rim], ix[rim]]
    col[a == 0] = 0
    alpha8 = np.round(a * 255).astype(np.uint8)
    rgba = np.dstack([np.round(col).astype(np.uint8), alpha8])
    info = {'bg_rgb': [float(v) for v in bg], 'solid_px': int(keep.sum()),
            'core_px': int(core.sum()), 'rim_px': int(rim.sum()), 'opaque_px': int((alpha8 == 255).sum()),
            'partial_px': int(((alpha8 > 0) & (alpha8 < 255)).sum())}
    return rgba, info
