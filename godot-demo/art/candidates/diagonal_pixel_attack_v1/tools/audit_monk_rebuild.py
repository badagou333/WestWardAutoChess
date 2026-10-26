#!/usr/bin/env python3
"""Rebuild monk in an empty temporary output tree and compare every artifact.

Only archived generator inputs, explicit extraction configs and producer scripts
are copied. Existing character outputs are never copied or overwritten.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MONK = ROOT/"monk"
BUILDER = ROOT.parent/"pixel_attack_series_v1/tools/build_attack.py"


def filehash(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",default="tools/monk_rebuild_integrity.json")
    args = parser.parse_args()
    output = (ROOT/args.output).resolve()
    assert output.is_relative_to((ROOT/"tools").resolve())
    provenance_path = MONK/"source/provenance.json"
    provenance = json.loads(provenance_path.read_text())
    inputs = [Path(name) for name in ("rebuild.py","prepare_se.py","prepare_ne.py","finish_specs.py","REVIEW_STATUS.json",
                                     "source/se_extraction.json","source/ne_extraction.json","source/provenance.json")]
    for item in provenance["sources"]:
        inputs.extend((Path("source")/item["file"],Path("source")/item["prompt"]))
    inputs = sorted(set(inputs))
    source_snapshot = {name.as_posix():filehash(MONK/name) for name in inputs}
    original_builder_hash = filehash(BUILDER)
    workspace = Path(tempfile.mkdtemp(prefix="diagonal-monk-rebuild-"))
    copy_root = workspace/"candidates/diagonal_pixel_attack_v1/monk"
    for name in inputs:
        target = copy_root/name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(MONK/name,target)
    copy_builder = workspace/"candidates/pixel_attack_series_v1/tools/build_attack.py"
    copy_builder.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(BUILDER,copy_builder)
    for direction in ("se","ne"):
        (copy_root/direction).mkdir()
        assert not any((copy_root/direction).iterdir())
    assert not (copy_root/"source/se_prepared.webp").exists()
    assert not (copy_root/"source/ne_prepared.webp").exists()
    env = dict(os.environ);env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run([sys.executable,str(copy_root/"rebuild.py")],cwd=workspace,env=env,
                            text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"Isolated rebuild failed ({workspace}):\n{result.stdout}\n{result.stderr}")
    generated = sorted(path.relative_to(copy_root) for path in copy_root.rglob("*")
                       if path.is_file() and path.relative_to(copy_root) not in inputs)
    assert generated and not any("__pycache__" in path.parts for path in generated)
    files = []
    png_count = webp_count = gif_count = 0
    for name in generated:
        original = MONK/name;rebuilt = copy_root/name
        assert original.is_file(), f"New output missing from authored package: {name}"
        actual_hash = filehash(original);rebuilt_hash = filehash(rebuilt)
        assert actual_hash == rebuilt_hash, f"Authored/rebuilt bytes differ: {name}"
        item = {"file":name.as_posix(),"sha256":actual_hash,"bytes_identical":True}
        suffix = name.suffix.lower()
        if suffix in (".png",".webp"):
            with Image.open(original) as a,Image.open(rebuilt) as b:
                a.load();b.load()
                assert np.array_equal(np.asarray(a.convert("RGBA")),np.asarray(b.convert("RGBA")))
                item["rgba_identical"] = True;item["size"] = list(a.size)
                item["rgba_sha256"] = hashlib.sha256(a.convert("RGBA").tobytes()).hexdigest()
            png_count += suffix == ".png";webp_count += suffix == ".webp"
        elif suffix == ".gif":
            durations = []
            with Image.open(original) as a,Image.open(rebuilt) as b:
                assert a.n_frames == b.n_frames
                for index in range(a.n_frames):
                    a.seek(index);b.seek(index)
                    assert np.array_equal(np.asarray(a.convert("RGB")),np.asarray(b.convert("RGB")))
                    at = int(a.info.get("duration",0));bt = int(b.info.get("duration",0))
                    assert at == bt > 0;durations.append(at)
                item["decoded_rgb_and_durations_identical"] = True
                item["encoded_frames"] = a.n_frames;item["durations_ms"] = durations;item["total_ms"] = sum(durations)
            gif_count += 1
        files.append(item)
    for name,digest in source_snapshot.items():
        assert filehash(MONK/name) == digest, f"Source changed during isolated rebuild: {name}"
    assert filehash(BUILDER) == original_builder_hash
    for direction in ("se","ne"):
        m = json.loads((copy_root/direction/"manifest.json").read_text())
        required = {Path(direction)/record["file"] for record in m["bodies"]+m["renders"]}
        required.update(Path(direction)/record["file"] for record in m["layers"].values())
        required.update(Path(direction)/name for name in ("spec.json","manifest.json","structural_report.json",
                                                        "atlas.png","contact_sheet.png","preview.gif","preview_slow.gif"))
        assert required.issubset(set(generated)), "Outputs were not produced from the empty direction directory"
        assert len(m["bodies"]) == 6 and len(m["renders"]) == 9
        assert m["previews"]["preview.gif"]["total_ms"] == 1470
        assert m["previews"]["preview_slow.gif"]["total_ms"] == 2540
    inherited_review = json.loads((MONK/"REVIEW_STATUS.json").read_text())
    report = {"schema":"diagonal-monk-isolated-rebuild-v1","integrity":"pass","visual_status":inherited_review.get("status","under_review"),
              "visual_status_authority":"parent-maintained monk/REVIEW_STATUS.json; this audit does not award a visual pass",
              "visual_acceptance_awarded":False,"character_outputs_written":False,
              "method":"fresh temporary source-only tree, producer rebuild.py, full byte/RGBA/GIF comparison",
              "temporary_workspace":str(workspace),"original_builder_sha256":original_builder_hash,
              "direction_output_directories_started_empty":True,"prepared_sheets_absent_before_run":True,
              "source_inputs_unchanged":True,"source_input_sha256":source_snapshot,
              "generated_file_count":len(files),"png_count":png_count,"webp_count":webp_count,"gif_count":gif_count,
              "all_generated_bytes_identical":True,"all_static_media_rgba_identical":True,
              "all_gif_decoded_rgb_and_timing_identical":True,"files":files,
              "producer_stdout":result.stdout.strip(),"producer_stderr":result.stderr.strip(),
              "not_verified":["visual acceptance","human continuous playback","browser interaction","runtime integration"]}
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"integrity":"pass","generated_files":len(files),"png":png_count,"webp":webp_count,
                      "gif":gif_count,"all_bytes_and_pixels_match":True,"temporary_workspace":str(workspace)}))


if __name__ == "__main__":main()
