#!/usr/bin/env python3
"""07 independent resource check for D-20261018-002.

Compares every runtime PNG byte-for-byte and decoded RGBA against the approved
05 candidate frames, and verifies the runtime manifest is complete and free of
the three rejected movement frames. Emits the expected decoded-asset table used
by qa_pack_assets.gd when running against the final PCK.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
DEMO = ROOT / "godot-demo"
RUNTIME = DEMO / "art/runtime/diamond_duel_v1"
CANDIDATE = DEMO / "art/candidates/rect_iso_duel_v1"
REJECTED = {"monk_ne_move_b", "wolf_se_move_b", "wolf_ne_move_b"}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rgba_sha(path: Path) -> tuple[str, tuple[int, int]]:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        return sha256_bytes(rgba.tobytes()), rgba.size


def main() -> int:
    output = Path("/tmp/qa07-duel-20261025/expected-assets.json")
    candidates = json.loads((CANDIDATE / "manifest.json").read_text())
    runtime = json.loads((RUNTIME / "manifest.json").read_text())
    failures: list[str] = []
    checks = 0

    def check(ok: bool, label: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(label)

    check(runtime.get("schema") == "diamond-duel-runtime-v1", "runtime schema")
    check(runtime.get("source_manifest") == "art/candidates/rect_iso_duel_v1/manifest.json", "source manifest path recorded")
    check(runtime.get("decision") == "D-20261018-002", "decision id recorded")
    check(runtime.get("design_cell", {}).get("width") == 192 and runtime.get("design_cell", {}).get("height") == 96, "design cell 192x96")
    check(len(runtime.get("frames", [])) == 17, "exactly seventeen runtime frames")
    check(set(runtime.get("excluded_frames", [])) == REJECTED, "excluded frame list equals the three rejected poses")
    actor_scale = {key: value.get("uniform_scale_to_design") for key, value in runtime.get("actors", {}).items()}
    check(actor_scale == {"monk": 0.34, "wolf": 0.34}, "one common 0.34 art scale for both actors")
    check(runtime.get("readiness") is not None, "candidate readiness snapshot retained as metadata")

    candidate_by_id = {frame["id"]: frame for frame in candidates["frames"]}
    check(set(candidate_by_id) - REJECTED == {frame["id"] for frame in runtime["frames"]}, "runtime frames are the candidate set minus the rejected three")
    check(len(list((RUNTIME / "frames").glob("*.png"))) == 17, "runtime frames directory holds exactly seventeen PNGs")
    check(not (RUNTIME / "frames" / "monk_ne_move_b.png").exists(), "rejected monk NE move_b is absent")
    check(not (RUNTIME / "frames" / "wolf_se_move_b.png").exists(), "rejected wolf SE move_b is absent")
    check(not (RUNTIME / "frames" / "wolf_ne_move_b.png").exists(), "rejected wolf NE move_b is absent")
    check((CANDIDATE / ".gdignore").exists(), "source candidate directory is .gdignore-isolated")

    expected_assets = []
    ids = set()
    for frame in runtime["frames"]:
        frame_id = frame["id"]
        check(frame_id not in ids, f"unique frame id {frame_id}")
        ids.add(frame_id)
        check(frame_id not in REJECTED, f"rejected id not in runtime {frame_id}")
        filename = frame["image"]
        runtime_path = RUNTIME / filename
        candidate_path = CANDIDATE / filename
        check(runtime_path.is_file(), f"runtime file exists {frame_id}")
        check(candidate_path.is_file(), f"candidate file exists {frame_id}")
        if not runtime_path.is_file() or not candidate_path.is_file():
            continue
        runtime_bytes = runtime_path.read_bytes()
        candidate_bytes = candidate_path.read_bytes()
        raw_sha = sha256_bytes(runtime_bytes)
        check(raw_sha == sha256_bytes(candidate_bytes), f"runtime PNG is byte-identical to candidate {frame_id}")
        check(frame.get("sha256") == sha256_bytes(candidate_bytes), f"manifest source sha matches candidate bytes {frame_id}")
        rg_sha, size = rgba_sha(runtime_path)
        cand_rg_sha, cand_size = rgba_sha(candidate_path)
        check(size == cand_size, f"decoded RGBA size equal {frame_id}")
        check(rg_sha == cand_rg_sha, f"decoded RGBA bytes equal source candidate {frame_id}")
        check(tuple(frame.get("image_size", [])) == size, f"manifest image size matches decoded PNG {frame_id}")
        check(abs(float(frame.get("uniform_scale_to_design", 0)) - 0.34) < 1e-12, f"fixed 0.34 scale metadata {frame_id}")
        source_frame = candidate_by_id.get(frame_id, {})
        for key in ("anchor_source", "body_bbox_source", "feet", "attack_contact_source", "issues"):
            check(frame.get(key) == source_frame.get(key), f"metadata copied unchanged from candidate: {key} {frame_id}")
        check(str(frame.get("source", "")).startswith("sources/"), f"source image recorded {frame_id}")
        expected_assets.append({"id": frame_id, "image": filename, "size": list(size), "rgba_sha": rg_sha,
                                "raw_sha": raw_sha, "source_raw_sha": sha256_bytes(candidate_bytes)})

    report = {"checks": checks, "failures": failures, "runtime_frames": len(runtime["frames"]),
              "candidate_frames": len(candidates["frames"]), "rejected": sorted(REJECTED),
              "assets": expected_assets}
    output.write_text(json.dumps(report, indent="\t"))
    print(f"QA07_ASSETS checks={checks} failures={len(failures)} frames={len(expected_assets)} out={output}")
    if failures:
        for failure in failures[:10]:
            print("FAIL", failure, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
