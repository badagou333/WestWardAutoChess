#!/usr/bin/env python3
"""Read-only memory rebuild of monk SE protected legs and NE source assignment.

Does not execute prepare_se.py, the character finisher or any writer. Reports
only go under this batch tools/. --original-root enables PNG/WebP full-RGBA
comparison, including invisible RGB; no directories are searched implicitly.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
MONK = ROOT/"monk"
entry = importlib.util.spec_from_file_location("monk_preparation_memory_builder",ROOT/"tools/build_attack.py")
builder = importlib.util.module_from_spec(entry);entry.loader.exec_module(builder)


def digest(data):return hashlib.sha256(data).hexdigest()
def file_hash(path):return digest(path.read_bytes())
def pixels(path):
    with Image.open(path) as image:
        image.load();return image.convert("RGBA").copy()


def lossless_webp(data):
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    offset = 12;found = False
    while offset+8 <= len(data):
        name = data[offset:offset+4]
        length = int.from_bytes(data[offset+4:offset+8],"little")
        assert offset+8+length <= len(data)
        assert name != b"VP8 ", "Lossy VP8 payload found"
        found |= name == b"VP8L"
        offset += 8+length+(length%2)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-root",type=Path)
    parser.add_argument("--output",default="tools/monk_preparation_integrity.json")
    args = parser.parse_args()
    destination = (ROOT/args.output).resolve()
    assert destination.is_relative_to((ROOT/"tools").resolve())
    prep_path = MONK/"source/se_extraction.json"
    raw = json.loads(prep_path.read_text())
    assert raw["canvas"] == [448,448] and raw["anchor"] == [224,344]
    assert all(source["scale"] == .6 for source in raw["sources"].values())
    raw_assets = builder.build_assets(raw,MONK/"se")
    originals = [body.copy() for body in raw_assets["bodies"]]
    base = originals[0]
    generated = pixels(MONK/"source/se_fixed_legs.webp")
    edited = generated.resize((448,448),Image.Resampling.NEAREST)
    rgba = np.asarray(edited).copy()
    rgba[:,:,3] = np.where(rgba[:,:,3] >= 128,255,0)
    rgba[rgba[:,:,3] == 0] = 0
    edited = Image.fromarray(rgba)
    protect = Image.new("L",(448,448));draw = ImageDraw.Draw(protect)
    draw.polygon([(112,273),(205,273),(205,344),(112,344)],fill=255)
    draw.polygon([(244,286),(334,286),(334,373),(244,373)],fill=255)
    fore = Image.new("L",(448,448));draw = ImageDraw.Draw(fore)
    draw.polygon([(288,266),(313,264),(325,289),(398,337),(393,365),(309,306),(288,293)],fill=255)
    foreground = np.asarray(fore).copy();foreground[rgba[:,:,3] == 0] = 0
    fore = Image.fromarray(foreground)
    expected = Image.composite(base,edited,protect)
    expected = Image.composite(edited,expected,fore)
    mask = (np.asarray(protect)>0)&(foreground==0)
    assert np.array_equal(np.asarray(expected)[mask],np.asarray(base)[mask])
    assert np.array_equal(np.asarray(Image.open(MONK/"source/se_protected_lower_body.png")),np.asarray(protect))
    assert np.array_equal(np.asarray(Image.open(MONK/"source/se_edited_foreground.png")),foreground)
    assert np.array_equal(np.asarray(pixels(MONK/"source/se_impact_prepared.png")),np.asarray(expected))
    originals[3] = expected
    sheet = Image.new("RGBA",(1344,896))
    for index,body in enumerate(originals):sheet.paste(body,((index%3)*448,(index//3)*448))
    saved = pixels(MONK/"source/se_prepared.webp")
    assert np.array_equal(np.asarray(sheet),np.asarray(saved)), "Prepared sheet differs from independent memory reconstruction"
    metadata = json.loads((MONK/"source/se_preparation.json").read_text())
    assert metadata["prepared_sha256"] == file_hash(MONK/"source/se_prepared.webp")
    assert metadata["prepared_rgba_sha256"] == digest(sheet.tobytes())
    assert metadata["protected_pixels"] == int(mask.sum())
    # The second shared palette application must still map identical protected
    # ready/impact pixels identically, including the entire alpha silhouette.
    ready = np.asarray(pixels(MONK/"se/frames/0.png"))
    impact = np.asarray(pixels(MONK/"se/frames/3.png"))
    assert np.array_equal(ready[mask],impact[mask]), "Final SE3 protected RGBA differs from final ready"
    leg_report = []
    for name,box in (("screen_left_ready_leg",(112,273,206,345)),("screen_right_ready_leg",(244,286,335,374))):
        region = np.zeros((448,448),bool);x1,y1,x2,y2 = box;region[y1:y2,x1:x2] = True
        region &= mask
        opaque = region&(ready[:,:,3] == 255)
        ys,xs = np.where(opaque)
        leg_report.append({"id":name,"explicit_protected_mask_pixels":int(region.sum()),
                           "ready_opaque_pixels":int(opaque.sum()),"ready_vs_impact_rgba_exact":True,
                           "opaque_bounds":[int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]})
    se_spec = json.loads((MONK/"se/spec.json").read_text())
    assert set(se_spec["sources"]) == {"prepared"} and se_spec["sources"]["prepared"]["scale"] == 1
    assert all(body["source"] == "prepared" for body in se_spec["bodies"])
    se_assets = builder.build_assets(se_spec,MONK/"se")
    for index,body in enumerate(se_assets["bodies"]):
        assert np.array_equal(np.asarray(body),np.asarray(pixels(MONK/f"se/frames/{index}.png")))
    for entry,image in zip(json.loads((MONK/"se/manifest.json").read_text())["renders"],se_assets["renders"]):
        assert np.array_equal(np.asarray(image),np.asarray(pixels(MONK/"se"/entry["file"])))
    ne_raw = json.loads((MONK/"source/ne_extraction.json").read_text())
    assert all(source["scale"] == .6 for source in ne_raw["sources"].values())
    assert [body["id"] for body in ne_raw["bodies"] if body["source"] == "tail_repair"] == ["4"]
    assert ne_raw["bodies"][3]["source"] == "repair"
    assert all(ne_raw["bodies"][index]["source"] == "main" for index in (0,1,2,5))
    ne_base = builder.build_assets(ne_raw,MONK/"ne")["bodies"]
    ne_bodies = [body.copy() for body in ne_base]
    removal = pixels(MONK/"source/ne_no_rear.webp")
    shaft = np.asarray(pixels(MONK/"source/staff_component.webp")).copy()
    shaft[:,:,3] = np.where(shaft[:,:,3] >= 128,255,0)
    shaft[:,1000:,3] = 0;shaft[shaft[:,:,3] == 0] = 0
    shaft = Image.fromarray(shaft)
    settings = {
        0:([85,220,185,294],[[340,184.5],[355,177.5]],100),
        3:([82,206,195,275],[[360,185],[390,174]],100),
        4:([77,201,195,277],[[340,175.5],[360,167.5]],95),
        5:([82,220,197,313],[[325,188],[350,176]],103)}
    ne_repairs = []
    for index,(bounds,axis,tipx) in settings.items():
        edited,_ = builder.extract(removal,ne_raw["bodies"][index],.6,(448,448),(224,344))
        removal_mask = Image.new("L",(448,448));ImageDraw.Draw(removal_mask).rectangle(bounds,fill=255)
        repaired = Image.composite(edited,ne_base[index],removal_mask)
        (x1,y1),(x2,y2) = axis
        slope = (y2-y1)/(x2-x1);intercept = y1-slope*x1;tipy = slope*tipx+intercept
        angle = math.atan(slope);c = math.cos(angle);sn = math.sin(angle);scale = .165
        inverse = (c/scale,sn/scale,74-(c*tipx+sn*tipy)/scale,
                   -sn/scale,c/scale,359.5-(-sn*tipx+c*tipy)/scale)
        rear = shaft.transform((448,448),Image.Transform.AFFINE,inverse,resample=Image.Resampling.NEAREST)
        ne_bodies[index] = Image.alpha_composite(rear,repaired)
        assert np.array_equal(np.asarray(Image.open(MONK/f"source/ne_rear_removal_mask_{index}.png")),np.asarray(removal_mask))
        assert np.array_equal(np.asarray(pixels(MONK/f"source/ne_rear_layer_{index}.png")),np.asarray(rear))
        old = np.asarray(ne_base[index]);new = np.asarray(ne_bodies[index])
        unchanged = (np.asarray(removal_mask)==0)&(old[:,:,3]==255)
        assert np.array_equal(old[unchanged],new[unchanged])
        assert np.array_equal(old[320:],new[320:]), "NE lower legs/feet changed during equipment assembly"
        ne_repairs.append({"body":index,"unmasked_opaque_pixels_preserved":int(unchanged.sum()),
                           "below_y320_full_rgba_exact":True,"front_axis":axis,
                           "rear_layer_inverse_affine":list(inverse),"equipment_scale":scale})
    ne_sheet = Image.new("RGBA",(1344,896))
    for index,body in enumerate(ne_bodies):ne_sheet.paste(body,((index%3)*448,(index//3)*448))
    assert np.array_equal(np.asarray(ne_sheet),np.asarray(pixels(MONK/"source/ne_prepared.webp")))
    for index in (1,2):
        assert np.array_equal(np.asarray(ne_bodies[index]),np.asarray(ne_base[index]))
    ne_spec = json.loads((MONK/"ne/spec.json").read_text())
    assert ne_spec["canvas"] == [448,448] and ne_spec["anchor"] == [224,344]
    assert set(ne_spec["sources"]) == {"prepared"} and ne_spec["sources"]["prepared"]["scale"] == 1
    assert all(body["source"] == "prepared" for body in ne_spec["bodies"])
    ne_assets = builder.build_assets(ne_spec,MONK/"ne")
    for index,body in enumerate(ne_assets["bodies"]):
        assert np.array_equal(np.asarray(body),np.asarray(pixels(MONK/f"ne/frames/{index}.png")))
    ne_manifest = json.loads((MONK/"ne/manifest.json").read_text())
    for entry,image in zip(ne_manifest["renders"],ne_assets["renders"]):
        assert np.array_equal(np.asarray(image),np.asarray(pixels(MONK/"ne"/entry["file"])))
    provenance = json.loads((MONK/"source/provenance.json").read_text())
    sources = []
    for item in provenance["sources"]:
        path = MONK/"source"/item["file"]
        data = path.read_bytes();image = pixels(path)
        assert file_hash(path) == item["sha256"] and digest(image.tobytes()) == item["rgba_sha256"]
        assert list(image.size) == item["size"] and lossless_webp(data)
        prompt = MONK/"source"/item["prompt"]
        assert prompt.is_file() and len(prompt.read_text().strip()) > 30
        original = None
        if args.original_root:
            original_path = args.original_root/item["original_generated_filename"]
            assert original_path.is_file(), original_path
            assert file_hash(original_path) == item["original_png_sha256"]
            assert np.array_equal(np.asarray(pixels(original_path)),np.asarray(image)), "PNG/WebP differs including alpha-zero RGB"
            original = {"path":str(original_path),"original_png_sha256_matches":True,
                        "whole_rgba_including_alpha_zero_exact":True}
        sources.append({"name":item.get("name",path.stem),"file":item["file"],"sha256":file_hash(path),
                        "rgba_sha256":digest(image.tobytes()),"lossless_webp_payload":True,
                        "prompt_file_exists":True,"original_png_comparison":original})
    assert len(sources) == len(provenance["sources"])
    inherited_path = MONK/"REVIEW_STATUS.json"
    inherited = json.loads(inherited_path.read_text()) if inherited_path.is_file() else {}
    report = {"schema":"monk-diagonal-preparation-independent-v1","integrity":"pass",
              "visual_status":inherited.get("status","under_review"),
              "visual_status_authority":"parent-maintained monk/REVIEW_STATUS.json; this audit does not award a visual pass",
              "visual_acceptance_awarded":False,"prepare_se_executed":False,"character_outputs_written":False,
              "method":"independent mask/composite reconstruction in memory plus shared decoder/palette renderer in memory",
              "se_original_sampling_scale":.6,"se_prepared_sampling_scale":1,
              "se_prepared_whole_rgba_memory_rebuild_exact":True,"protected_ready_impact_rgba_exact":True,
              "protected_pixel_count":int(mask.sum()),"protected_opaque_ready_pixel_count":int((mask&(ready[:,:,3]==255)).sum()),
              "legs":leg_report,"se_all_6_bodies_and_all_stages_memory_rebuild_exact":True,
              "ne_all_6_bodies_and_all_stages_memory_rebuild_exact":True,"ne_raw_tail_repair_only_body_ids":["4"],
              "ne_original_sampling_scale":.6,"ne_prepared_sampling_scale":1,"ne_anchor":[224,344],
              "ne_prepared_whole_rgba_memory_rebuild_exact":True,"ne_prepared_1_2_full_rgba_preserved":True,
              "ne_rear_repairs":ne_repairs,"source_archives":sources,
              "monk_manifest_sha256":{d:file_hash(MONK/d/"manifest.json") for d in ("se","ne")},
              "full_rebuild_script_executed":False,
              "limits":"No prepare/finish writer executed; final full rebuild and visual gate remain separate. Original PNG equality is only established when original_root is supplied."}
    destination.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"integrity":"pass","protected_pixels":int(mask.sum()),
                      "se_ne_body_and_stage_memory_rebuild_exact":True,
                      "original_pngs_compared":bool(args.original_root),"visual_acceptance_awarded":False}))


if __name__ == "__main__":main()
