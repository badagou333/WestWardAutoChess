"""D-20261110-005: verify every runtime asset of character-showcase byte for byte.

For each characters/<id>/character.json: manifest SHA-256 pin, every frame PNG
against its manifest sha256, the WAV pin, plus the shared board. No Godot, git
or network needed, so it also runs on a cold copy.
  python -I tools/verify_assets.py [--project DIR] [--output report.json]
"""
import argparse, hashlib, json, sys
from pathlib import Path

BOARD_SHA = "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"

def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", type=Path, default=Path(__file__).resolve().parent.parent)
    ap.add_argument("--output", type=Path)
    a = ap.parse_args()
    root = a.project
    failures, counts = [], {}
    def check(ok, label):
        if not ok: failures.append(label)
        return ok
    check(sha(root / "shared/forest-board.png") == BOARD_SHA, "shared board")
    index = json.loads((root / "characters/index.json").read_text(encoding="utf-8"))
    for entry in index["characters"]:
        cid = entry["id"]
        base = root / "characters" / cid
        cfg = json.loads((base / "character.json").read_text(encoding="utf-8"))
        n = 0
        for clip_id, clip in cfg["clips"].items():
            mpath = base / clip["manifest"]
            check(sha(mpath) == clip["manifest_sha256"], f"{cid}/{clip_id} manifest"); n += 1
            manifest = json.loads(mpath.read_text(encoding="utf-8"))
            for fr in manifest["frames"]:
                check(sha(mpath.parent / fr["file"]) == fr["sha256"], f"{cid}/{clip_id} {fr['file']}"); n += 1
            audio = base / clip["audio"] if "audio" in clip else mpath.parent / manifest["audio"]["file"]
            check(sha(audio) == clip["audio_sha256"], f"{cid}/{clip_id} audio"); n += 1
        counts[cid] = n
    report = {"schema": "character-showcase-asset-check-v1", "project": str(root), "files_checked": counts,
              "board_checked": True, "failures": len(failures), "failure_messages": failures}
    if a.output:
        a.output.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"assets: {sum(counts.values()) + 1} files checked, {len(failures)} failures {counts}")
    return 1 if failures else 0

if __name__ == "__main__":
    sys.exit(main())
