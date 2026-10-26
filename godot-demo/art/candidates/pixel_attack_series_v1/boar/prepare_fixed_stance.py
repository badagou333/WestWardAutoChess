#!/usr/bin/env python3
"""Reproduce registration and explicit fixed-lower-body component assembly.

Generated art is archived losslessly. This script only extracts one common scale,
reuses a declared lower-body component, and retains drawn foreground weapon parts.
It does not generate body motion or infer a background/automatic crop.
"""
from pathlib import Path
import hashlib
import json
import math
import types
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
TOOL = ROOT.parent / "tools/build_attack.py"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def engine():
    module = types.ModuleType("boar_public_engine")
    exec(compile(TOOL.read_text(), str(TOOL), "exec"), module.__dict__)
    return module

def polygon(points, size):
    mask = Image.new("1", size)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=1)
    return np.asarray(mask).copy()

def wrist_allowed_mask(policy, original):
    allowed = polygon(policy["target_polygon"], original.size)
    for points in policy["protect_polygons"].values():
        allowed &= ~polygon(points, original.size)
    return allowed & (np.asarray(original)[:, :, 3] == 255)

def wrist_clothing(images, policy):
    """Register existing contact-arm clothing while preserving the front grip."""
    before = {str(i):digest(image.tobytes()) for i,image in enumerate(images)}
    if before != policy["before_body_pixel_hashes"]:
        raise ValueError("Unpatched palette group changed before the bounded repair")
    index = int(policy["body"])
    original = np.asarray(images[index])
    donor = np.asarray(images[int(policy["donor_body"])])
    source_mask = polygon(policy["source_polygon"], images[index].size)
    allowed = wrist_allowed_mask(policy, images[index])
    yy,xx = np.indices(original.shape[:2])
    angle = math.radians(policy["rotate_ccw_degrees"])
    c,s = math.cos(angle),math.sin(angle)
    dx = (xx-policy["target_pivot"][0])/policy["scale"]
    dy = (yy-policy["target_pivot"][1])/policy["scale"]
    sx = np.rint(policy["source_pivot"][0]+c*dx-s*dy).astype(int)
    sy = np.rint(policy["source_pivot"][1]+s*dx+c*dy).astype(int)
    inside = (sx>=0)&(sx<original.shape[1])&(sy>=0)&(sy<original.shape[0])
    take = np.zeros(inside.shape,dtype=bool)
    take[inside] = source_mask[sy[inside],sx[inside]] & (donor[sy[inside],sx[inside],3]==255)
    take &= allowed
    finished = original.copy()
    finished[take] = donor[sy[take],sx[take]]
    assert np.array_equal(finished[~allowed],original[~allowed])
    assert np.array_equal(finished[:,:,3],original[:,:,3])
    images = list(images)
    images[index] = Image.fromarray(finished)
    changed = np.any(finished!=original,axis=2)
    ys,xs = np.where(changed)
    return images,{"policy":"source/wrist_patch_spec.json","body":str(index),
        "donor_body":policy["donor_body"],"palette_locked_before_local_copy":True,
        "before_body_pixel_hashes":before,
        "after_body_pixel_hashes":{str(i):digest(image.tobytes()) for i,image in enumerate(images)},
        "changed_rgba_pixels":int(changed.sum()),
        "change_bbox":[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],
        "outside_allowed_mask_rgba_exact":True,"all_alpha_exact":True,
        "fingers_palm_mace_axis_protected":True,
        "other_five_body_rgba_exact":all(digest(image.tobytes())==before[str(i)] for i,image in enumerate(images) if i!=index)}

def prepare(root=ROOT):
    data = json.loads((root / "source/registration_spec.json").read_text())
    provenance = json.loads((root / "source/provenance.json").read_text())
    public = engine()
    source, audit = public.read_image(root, provenance["source"] | {
        "expected_pixel_sha256": provenance["source"]["rgba_pixel_sha256"]})
    bodies, extraction = [], []
    size = tuple(data["canvas"])
    for pose in data["poses"]:
        image, report = public.extract(source, pose, data["shared_raw_scale"],
                                       size, tuple(data["waist_anchor"]))
        bodies.append(image)
        extraction.append(report | {"id":pose["id"],"name":pose["name"]})
    policy = data["fixed_lower_body"]
    common_mask = polygon(policy["polygon"], size)
    common = np.zeros_like(np.asarray(bodies[0]))
    common[common_mask] = np.asarray(bodies[0])[common_mask]
    result, changes = [], []
    for i, body in enumerate(bodies):
        original = np.asarray(body)
        if i == 0:
            finished = original.copy()
        else:
            finished = original.copy()
            finished[policy["cut_y"]:] = 0
            finished[common_mask] = common[common_mask]
            if str(i) in policy["foreground_from_original"]:
                retain = polygon(policy["foreground_from_original"][str(i)], size)
                # Transparent original pixels must not erase the common body.
                retain &= original[:, :, 3] == 255
                finished[retain] = original[retain]
        finished[finished[:, :, 3] == 0] = 0
        image = Image.fromarray(finished)
        result.append(image)
        changes.append({"id":str(i),"changed_rgba_pixels":int(np.count_nonzero(np.any(finished != original,axis=2))),
                        "registered_pixel_sha256":digest(body.tobytes()),
                        "prepared_pixel_sha256":digest(image.tobytes()),
                        "visible_bbox":list(image.getbbox())})
    wrist_report = None
    wrist_policy = root / "source/wrist_patch_spec.json"
    if wrist_policy.exists():
        # Lock the original group palette BEFORE this one clothing addition.
        # A subsequent public export sees at most96 exact colors, so it cannot
        # recolor five already accepted frames when the wrist pixels are added.
        result,_ = public.train_body_palette(result,96)
        result,wrist_report = wrist_clothing(result,json.loads(wrist_policy.read_text()))
    return result, {"raw_source":audit,"shared_raw_scale":data["shared_raw_scale"],
                    "waist_anchor":data["waist_anchor"],"extraction":extraction,
                    "lower_body_policy":policy,"poses":changes,
                    "poses_describe":"registered and lower-body assembly before palette mapping",
                    "wrist_patch":wrist_report}, bodies

def main():
    images, report, raw = prepare()
    sheet = Image.new("RGBA", (448*3,448*2))
    temp = ROOT / "source/prepared_bodies"
    temp.mkdir(parents=True, exist_ok=True)
    for i, (image, registered) in enumerate(zip(images,raw)):
        sheet.alpha_composite(image, ((i%3)*448,(i//3)*448))
        image.save(temp / f"{i}.png")
        registered.save(temp / f"raw_{i}.png")
    target = ROOT / "source/prepared_sheet.webp"
    sheet.save(target, lossless=True, exact=True, method=6)
    assert sheet.tobytes() == Image.open(target).convert("RGBA").tobytes()
    if report["wrist_patch"]:
        policy = json.loads((ROOT / "source/wrist_patch_spec.json").read_text())
        old = Image.open(ROOT / policy["baseline_body3_file"]).convert("RGBA")
        mask = wrist_allowed_mask(policy,old)
        mask_path = ROOT / policy["mask_file"]
        Image.fromarray((mask*255).astype(np.uint8)).save(mask_path)
        report["wrist_patch"]["mask_file_sha256"] = digest(mask_path.read_bytes())
    report["prepared_sheet"] = {"file":"source/prepared_sheet.webp","sha256":digest(target.read_bytes()),
        "rgba_pixel_sha256":digest(sheet.tobytes()),"size":list(sheet.size),"lossless":True,"webp_exact":True}
    report["scope"] = "Author preparation only; not independent pose/continuous/runtime acceptance."
    (ROOT / "source/preparation_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"bodies":len(images),"prepared_sheet":report["prepared_sheet"]}))

if __name__ == "__main__":
    main()
