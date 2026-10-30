#!/usr/bin/env python3
"""Source-only isolated wolf rebuild, archive verification and measured ROI audit.

Does not write character files. feet.json is treated as manual 2D ROI annotation,
never independent proof of anatomy, sole contact, 3D projection or gameplay.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image,ImageDraw,ImageFilter

ROOT = Path(__file__).resolve().parent.parent
WOLF = ROOT/"wolf"
BUILDER = ROOT/"tools/build_attack.py"
REPO = ROOT.parents[3]
sys.dont_write_bytecode = True


def filehash(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def rgba(path):
    with Image.open(path) as image:image.load();return np.asarray(image.convert("RGBA")).copy()
def polygon(points):
    image = Image.new("1",(448,448));ImageDraw.Draw(image).polygon([tuple(p) for p in points],fill=1)
    return np.asarray(image).copy()
def lossless(data):
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP"
    index = 12;found = False
    while index+8 <= len(data):
        name = data[index:index+4];size = int.from_bytes(data[index+4:index+8],"little")
        assert index+8+size <= len(data) and name != b"VP8 "
        found |= name == b"VP8L";index += 8+size+size%2
    return found
def equal(a,b):return bool(np.allclose(a,b,atol=1e-10,rtol=0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",default="tools/wolf_rebuild_integrity.json")
    args = parser.parse_args()
    output = (ROOT/args.output).resolve()
    assert output.is_relative_to((ROOT/"tools").resolve())
    cfg = json.loads((WOLF/"assembly_spec.json").read_text())
    assert cfg["canvas"] == [448,448] and cfg["anchor"] == [224,344]
    assert cfg["common_source_scale"] == cfg["character_display_scale"] == .5
    inputs = {Path(name) for name in ("rebuild.py","prepare_wolf.py","assembly_spec.json")}
    if (WOLF/"REVIEW_STATUS.json").is_file():inputs.add(Path("REVIEW_STATUS.json"))
    sources = []
    for direction in ("se","ne"):
        folder = WOLF/direction
        inputs.update((Path(direction)/"source/pack_spec.json",Path(direction)/"source/provenance.json"))
        provenance = json.loads((folder/"source/provenance.json").read_text())
        for entry in provenance["passes"]:
            path = folder/entry["file"];original = Path(entry["original_tool_png"])
            data = path.read_bytes();image = rgba(path)
            assert filehash(path) == entry["webp_sha256"]
            assert hashlib.sha256(image.tobytes()).hexdigest() == entry["rgba_pixel_sha256"]
            assert list(image.shape[1::-1]) == entry["size"] and lossless(data)
            assert original.is_file() and filehash(original) == entry["original_png_sha256"]
            assert np.array_equal(image,rgba(original)), "PNG/WebP differs including alpha-zero RGB"
            prompt = folder/entry["prompt"]
            assert prompt.is_file() and len(prompt.read_text().strip()) > 30
            inputs.update((path.relative_to(WOLF),prompt.relative_to(WOLF)))
            sources.append({"direction":direction,"id":entry["id"],"file":path.relative_to(WOLF).as_posix(),
                            "webp_sha256":filehash(path),"rgba_pixel_sha256":entry["rgba_pixel_sha256"],
                            "original_png":str(original),"original_png_sha256":filehash(original),
                            "whole_rgba_including_alpha_zero_exact":True,"lossless_webp":True,
                            "prompt_file":prompt.relative_to(WOLF).as_posix(),"prompt_sha256":filehash(prompt),
                            "current_assembly_source":entry["file"] == cfg["directions"][direction]["source"]})
        for reference in provenance.get("references",[]):
            assert filehash(REPO/reference["file"]) == reference["sha256"], "Direction reference hash changed"
    source_snapshot = {p.as_posix():filehash(WOLF/p) for p in sorted(inputs)}
    original_builder_hash = filehash(BUILDER)
    workspace = Path(tempfile.mkdtemp(prefix="diagonal-wolf-rebuild-"))
    copied = workspace/"candidates/diagonal_pixel_attack_v1/wolf"
    for name in sorted(inputs):
        target = copied/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(WOLF/name,target)
    copied_builder = workspace/"candidates/diagonal_pixel_attack_v1/tools/build_attack.py"
    copied_builder.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(BUILDER,copied_builder)
    for direction in ("se","ne"):
        assert not (copied/direction/"manifest.json").exists()
        assert not (copied/direction/"source/prepared_poses.webp").exists()
        assert not (copied/direction/"frames").exists()
    env = dict(os.environ);env["PYTHONDONTWRITEBYTECODE"] = "1"
    run = subprocess.run([sys.executable,str(copied/"rebuild.py")],cwd=workspace,env=env,
                         text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if run.returncode:raise RuntimeError(f"Wolf rebuild failed at {workspace}:\n{run.stdout}\n{run.stderr}")
    generated = sorted(path.relative_to(copied) for path in copied.rglob("*")
                       if path.is_file() and path.relative_to(copied) not in inputs)
    assert generated and not any("__pycache__" in path.parts for path in generated)
    files = [];counts = {"png":0,"webp":0,"gif":0,"json":0}
    for name in generated:
        original = WOLF/name;rebuilt = copied/name
        assert original.is_file() and filehash(original) == filehash(rebuilt), f"Authored/rebuilt bytes differ: {name}"
        item = {"file":name.as_posix(),"sha256":filehash(original),"bytes_identical":True}
        suffix = name.suffix.lower().lstrip(".")
        if suffix in counts:counts[suffix] += 1
        if suffix in ("png","webp"):
            assert np.array_equal(rgba(original),rgba(rebuilt));item["whole_rgba_identical"] = True
        if suffix == "gif":
            durations = []
            with Image.open(original) as a,Image.open(rebuilt) as b:
                assert a.n_frames == b.n_frames
                for index in range(a.n_frames):
                    a.seek(index);b.seek(index)
                    assert np.array_equal(np.asarray(a.convert("RGB")),np.asarray(b.convert("RGB")))
                    duration = int(a.info.get("duration",0));assert duration == int(b.info.get("duration",0)) > 0
                    durations.append(duration)
            item["decoded_rgb_and_durations_identical"] = True;item["durations_ms"] = durations;item["total_ms"] = sum(durations)
        files.append(item)
    library_spec = importlib.util.spec_from_file_location("wolf_independent_extraction",BUILDER)
    public = importlib.util.module_from_spec(library_spec);library_spec.loader.exec_module(public)
    mismatches,measured,mask_checks,manual_mean_differences = [],[],[],[]
    feet_snapshots = {}
    for direction in ("se","ne"):
        folder = WOLF/direction;entry = cfg["directions"][direction]
        manifest = json.loads((folder/"manifest.json").read_text())
        assert len(manifest["bodies"]) == 6 and len(manifest["renders"]) == 7
        assert manifest["previews"]["preview.gif"]["total_ms"] == 1170
        assert manifest["previews"]["preview_slow.gif"]["total_ms"] == 1990
        ready = rgba(folder/"frames/0.png")
        raw_source = Image.open(folder/entry["source"]).convert("RGBA")
        extracted = [public.extract(raw_source,pose,cfg["common_source_scale"],(448,448),(224,344))[0] for pose in entry["poses"]]
        base_raw = np.asarray(extracted[0])
        masks = Image.open(folder/"source/assembly_masks.png")
        with Image.open(folder/"atlas.png") as atlas:
            for index,body in enumerate(manifest["bodies"]):
                image = rgba(folder/body["file"])
                assert np.array_equal(np.asarray(atlas.crop((448*index,0,448*(index+1),448)).convert("RGBA")),image)
                assert set(np.unique(image[:,:,3])).issubset({0,255})
                assert not image[image[:,:,3] == 0].any()
                mask = np.zeros((448,448),bool)
                if index:
                    mask |= polygon(entry.get("upper_polygon_by_body",{}).get(str(index),entry["upper_polygon"]))
                    if str(index) in entry["near_foreleg_airborne_bodies"]:mask |= polygon(entry["near_foreleg_polygon"])
                    elif entry["extra_grounded_near_protection"]:mask &= ~polygon(entry["extra_grounded_near_protection"])
                    for protected in entry["protected_polygons"]+entry.get("protected_polygons_by_body",{}).get(str(index),[]):mask &= ~polygon(protected)
                unquantized = base_raw.copy()
                if index:
                    unquantized[mask] = np.asarray(extracted[index])[mask]
                    exclusions = list(entry.get("donor_exclusions_all",[]))+entry.get("donor_exclusions_by_body",{}).get(str(index),[])
                    if str(index) in entry["near_foreleg_airborne_bodies"]:exclusions += entry.get("donor_exclusions_airborne",[])
                    for points in exclusions:unquantized[polygon(points)&mask] = 0
                patch = entry.get("patches_by_body",{}).get(str(index))
                patch_pixels = 0
                if patch:
                    assert filehash(folder/patch["file"]) == patch["sha256"]
                    edit = np.asarray(Image.open(folder/patch["file"]).convert("RGBA").resize((448,448),Image.Resampling.NEAREST)).copy()
                    edit[:,:,3] = np.where(edit[:,:,3]>=128,255,0)
                    old_alpha,new_alpha = unquantized[:,:,3],edit[:,:,3]
                    old_inner = np.asarray(Image.fromarray(old_alpha).filter(ImageFilter.MinFilter(17)))>0
                    new_inner = np.asarray(Image.fromarray(new_alpha).filter(ImageFilter.MinFilter(17)))>0
                    edge = ((old_alpha>0)&~old_inner)|((new_alpha>0)&~new_inner)|((old_alpha>0)!=(new_alpha>0))
                    x0,y0,x1,y1 = patch["region"]
                    region = np.zeros((448,448),bool);region[y0:y1,x0:x1] = True
                    patch_mask = edge&region
                    unquantized[patch_mask] = edit[patch_mask];mask |= patch_mask
                    patch_pixels = int(patch_mask.sum())
                unquantized[unquantized[:,:,3] == 0] = 0
                preparation = json.loads((folder/"source/preparation_report.json").read_text())
                assert hashlib.sha256(unquantized.tobytes()).hexdigest() == preparation["poses"][index]["unquantized_pixel_sha256"]
                assert np.array_equal(np.asarray(extracted[index]),rgba(folder/f"source/debug/raw_{index}.png"))
                x,y = (index%3)*448,(index//3)*448
                assert np.array_equal(np.asarray(masks.crop((x,y,x+448,y+448)))>0,mask)
                assert np.array_equal(image[~mask],ready[~mask]), "Protected ready pixels changed outside explicit mask"
                mask_checks.append({"direction":direction,"body":str(index),"outside_mask_rgba_exact":True,
                                    "protected_pixels":int((~mask).sum()),"local_ai_edge_patch_pixels":patch_pixels,
                                    "unquantized_memory_reconstruction_exact":True})
        feet_path = folder/"feet.json";feet = json.loads(feet_path.read_text())
        feet_snapshots[direction] = filehash(feet_path)
        for frame in feet["frames"]:
            image = rgba(folder/"frames"/f'{frame["body"]}.png')
            for foot in frame["feet"]:
                x1,y1,x2,y2 = foot["foot_review_roi"]
                assert 0<=x1<x2<=448 and 0<=y1<y2<=448
                roi = image[y1:y2,x1:x2];ys,xs = np.where(roi[:,:,3]>0)
                bounds = None;low = None;span = None
                if len(xs):
                    bounds = [int(xs.min()+x1),int(ys.min()+y1),int(xs.max()+x1+1),int(ys.max()+y1+1)]
                    low = [float(xs[ys == ys.max()].mean()+x1),int(ys.max()+y1)]
                    row = xs[ys == ys.max()]+x1
                    span = [int(row.min()),int(row.max())]
                same = np.array_equal(roi,ready[y1:y2,x1:x2])
                item = {"direction":direction,"body":frame["body"],"foot":foot["id"],
                        "roi":foot["foot_review_roi"],"actual_roi_opaque_bounds":bounds,
                        "actual_roi_low_row_mean_x_and_y":low,"actual_same_ready_roi_rgba":bool(same),
                        "actual_roi_low_row_x_span":span,
                        "support_is_author_annotation":foot["support"],"geometric_sole_or_ground_proof":False}
                for field,actual in (("visible_review_bounds",bounds),):
                    declared = foot[field]
                    if (actual is None) != (declared is None) or (actual is not None and not equal(actual,declared)):
                        mismatches.append({"direction":direction,"body":frame["body"],"foot":foot["id"],"field":field,
                                           "declared":declared,"measured":actual})
                declared_low = foot.get("visible_low_proxy_px")
                # The author explicitly calls this a manual proxy, not a row
                # mean. Validate its visible row/envelope, and report a mean
                # delta separately instead of inventing a new data definition.
                proxy_valid = (declared_low is not None and low is not None
                               and declared_low[1] == low[1]
                               and span[0]-.5 <= declared_low[0] <= span[1]+.5)
                if not proxy_valid:
                    mismatches.append({"direction":direction,"body":frame["body"],"foot":foot["id"],
                                       "field":"visible_low_proxy_px","declared":declared_low,
                                       "measured_row_mean":low,"measured_row_span":span})
                elif not equal(declared_low,low):
                    manual_mean_differences.append({"direction":direction,"body":frame["body"],"foot":foot["id"],
                                                    "manual_proxy":declared_low,"measured_row_mean":low,
                                                    "inside_lowest_visible_row_span":True})
                declared_same = foot.get("same_ready_foot_roi_RGBA")
                if declared_same is not None and declared_same != same:
                    mismatches.append({"direction":direction,"body":frame["body"],"foot":foot["id"],
                                       "field":"same_ready_foot_roi_RGBA","declared":declared_same,"measured":bool(same)})
                for field in ("ground_projection","contact_proxy"):
                    if foot.get(field) is not None and (not proxy_valid or not equal(foot[field],declared_low)):
                        mismatches.append({"direction":direction,"body":frame["body"],"foot":foot["id"],"field":field,
                                           "declared":foot[field],"manual_visible_proxy":declared_low,
                                           "note":"This comparison validates a 2D ROI proxy only, not ground contact."})
                measured.append(item)
    for name,digest in source_snapshot.items():assert filehash(WOLF/name) == digest, f"Wolf input changed during audit: {name}"
    assert filehash(BUILDER) == original_builder_hash
    for direction,digest in feet_snapshots.items():assert filehash(WOLF/direction/"feet.json") == digest
    status_path = WOLF/"REVIEW_STATUS.json"
    inherited = json.loads(status_path.read_text()).get("status","under_review") if status_path.is_file() else "under_review"
    report = {"schema":"diagonal-wolf-independent-integrity-v1","asset_integrity":"pass",
              "visual_status":inherited,"visual_status_authority":"parent-maintained review status only",
              "visual_acceptance_awarded":False,"character_outputs_written":False,
              "temporary_workspace":str(workspace),"source_only_empty_output_rebuild":True,
              "all_generated_bytes_identical":True,"all_static_media_rgba_identical":True,
              "all_gif_rgb_and_timing_identical":True,"source_input_sha256":source_snapshot,
              "public_builder_sha256":original_builder_hash,"generated_file_count":len(files),"generated_counts":counts,
              "sources":sources,"all_original_png_webp_whole_rgba_exact":True,"files":files,
              "independent_assembly_mask_checks":mask_checks,
              "feet_reference_status":"current_as_manual_2d_roi_only" if not mismatches else "stale_manual_2d_roi_reference",
              "feet_mismatch_count":len(mismatches),"feet_mismatches":mismatches,"measured_feet":measured,
              "feet_reference_sha256":feet_snapshots,
              "manual_proxy_mean_difference_count":len(manual_mean_differences),
              "manual_proxy_mean_differences":manual_mean_differences,
              "foot_measurement_limits":"Opaque pixels inside author-selected ROIs. Includes any visible fur/body in that box; not anatomy segmentation, 3D sole, actual support or gameplay geometry.",
              "producer_stdout":run.stdout.strip(),"producer_stderr":run.stderr.strip(),
              "not_verified":["visual acceptance","human continuous playback","browser interaction","runtime integration"]}
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"asset_integrity":"pass","source_archives":len(sources),"generated_files":len(files),
                      "counts":counts,"feet_mismatches":len(mismatches),"visual_status":inherited,
                      "temporary_workspace":str(workspace)}))


if __name__ == "__main__":main()
