#!/usr/bin/env python3
"""Check the standalone C3 resource bytes and metadata using only the stdlib.

The source candidate is optional in a cold copy. All pinned manifests, the 101
copied resources, 98 PNG records, and original WAV/PCM checks remain mandatory.
This does not run Godot, decode video, render images, or judge sight or hearing.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import struct
import sys
import wave

SOURCE_COMMIT = "a36cd562ee4f8876635b57c9136c4416357afe22"
CANDIDATE_REL = Path("godot-demo/art/candidates/c03_kingfisher_attack_v1")
RESOURCE_LIST_SHA = "eb2aecdb0766b89ca8d9d178c09db2c51126a06c65d0d2be7833017d0c10eef5"
MANIFEST_SHA = "fd1ae8323bae9bbc24cef60a68fa715ed5228474bb7e9d11dfd4b13617f98b98"
FROZEN_MANIFEST_SHA = "4d49afdbc42d29eb2bea3a6c071e8dc1a63ac11702c384d86ff102275b9f5d2b"
WAV_SHA = "d1310bdaa9ea6017c2bef9e9b159c73f9fa39e15f3d6e337b37250f65ca77cfb"
PCM_SHA = "47bb9d09f6d9dc084fcc301573d75e389612bb96b57e79f9ba7badcd331c9a95"
BOARD_SHA = "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6"
MEDIA_END_TICKS = 260250
TIME_BASE = Fraction(1, 90000)
MEDIA_END = MEDIA_END_TICKS * TIME_BASE
SCOPE = ("Resource bytes and metadata only; no Godot execution, pixel/video decoding, "
         "visual judgement, device listening, OS input or independent acceptance.")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(root: Path, name: str) -> Path:
    """Resolve only a project-relative POSIX file path, never a provenance path."""
    parts = name.split("/")
    if not name or "\\" in name or ":" in name or PurePosixPath(name).is_absolute():
        raise ValueError("not a local resource path: " + name)
    if any(part in {"", ".", ".."} for part in parts):
        raise ValueError("unsafe local resource path: " + name)
    path = root.joinpath(*parts).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("resource resolves outside its project: " + name)
    return path


class Verification:
    def __init__(self) -> None:
        self.checks = 0
        self.failures: list[str] = []

    def check(self, condition: bool, label: str) -> None:
        self.checks += 1
        if not condition:
            self.failures.append(label)

    def hash(self, path: Path, expected: str, label: str) -> None:
        self.check(path.is_file() and digest(path) == expected, label)


def check_png(ver: Verification, path: Path, size: tuple[int, int], *, rgba: bool) -> None:
    # Header inspection only: this is not pixel decoding or visual acceptance.
    with path.open("rb") as source:
        header = source.read(33)
    valid = (len(header) == 33 and header[:8] == b"\x89PNG\r\n\x1a\n"
             and header[8:12] == b"\x00\x00\x00\r" and header[12:16] == b"IHDR")
    ver.check(valid, path.name + " PNG header")
    if not valid:
        return
    width, height, depth, color = struct.unpack(">IIBB", header[16:26])
    ver.check((width, height) == size, path.name + " fixed canvas")
    if rgba:
        ver.check(depth == 8 and color == 6, path.name + " original RGBA8 header")


def verify(args: argparse.Namespace, ver: Verification) -> dict:
    project = args.project.resolve()
    listing_path = project / "provenance/resource-list.json"
    manifest_path = project / "art/c03/manifest.json"
    listing = json.loads(listing_path.read_text())
    manifest = json.loads(manifest_path.read_text())
    config = json.loads((project / "showcase.json").read_text())
    ver.hash(listing_path, RESOURCE_LIST_SHA, "original preparation resource-list bytes")
    ver.hash(manifest_path, MANIFEST_SHA, "original repository-mapped manifest bytes")
    ver.check(listing["schema"] == "c03-isolated-preparation-resource-list-v1"
              and listing["source_asset_commit"] == SOURCE_COMMIT
              and listing["manifest_sha256"] == MANIFEST_SHA
              and listing["frozen_original_manifest_sha256"] == FROZEN_MANIFEST_SHA,
              "resource-list provenance and manifest identities")
    ver.check(listing["record_count"] == 101 and listing["png_frames"] == 98
              and len(listing["files"]) == 101, "all 101 copied resource records")
    source_prefix = CANDIDATE_REL.as_posix()
    expected_sources = {
        "art/c03/manifest.json": source_prefix + "/manifest.json",
        "art/c03/audio/feather-selected.wav": source_prefix + "/audio/feather-selected.wav",
        "art/forest-board.png": "bear-forehand-showcase/art/forest-board.png",
        **{f"art/c03/frames/frame_{index:06d}.png": source_prefix + f"/frames/frame_{index:06d}.png"
           for index in range(98)},
    }
    records = {item["runtime_path"]: item for item in listing["files"]}
    ver.check(len(records) == 101 and set(records) == set(expected_sources),
              "resource-list paths are complete, unique and canonical")
    for name, source_name in expected_sources.items():
        item = records[name]
        path = local_path(project, name)
        ver.check(item["source_repository_path"] == source_name,
                  name + " relative repository provenance")
        ver.check(item["source_sha256"] == item["copied_sha256"] and item["byte_equal"] is True,
                  name + " pinned source/copy identity record")
        ver.hash(path, item["source_sha256"], name + " current original resource bytes")
        ver.check(path.stat().st_size == item["bytes"], name + " original resource length")

    expected_config = {
        "schema": "c03-single-showcase-v1",
        "assets": {"manifest": "art/c03/manifest.json", "manifest_sha256": MANIFEST_SHA,
                   "board": "art/forest-board.png", "board_sha256": BOARD_SHA},
        "presentation": {"world_foot": [720, 441], "display_scale": 0.21},
        "playback": {"media_end_ticks": MEDIA_END_TICKS, "terminal_index": 97,
                     "terminal_policy": "ended_static"},
        "audio": {"start_seconds": 0.405},
    }
    ver.check(config == expected_config,
              "single-direction trial configuration, fixed scale/foot, source end and suggested offset")
    ver.check(manifest["schema"] == "c3-frozen-repository-mapping-v1"
              and manifest["time_base"] == [1, 90000]
              and manifest["canvas"] == [960, 960]
              and manifest["foot_reference"] == [475, 760],
              "original source schema, time base, canvas and compositional foot reference")
    ver.check(math.isclose(manifest["source_video_media_end_seconds"], float(MEDIA_END),
                           rel_tol=0, abs_tol=1e-12)
              and manifest["final_sample_duration_ticks"] == 0,
              "exact source media end and zero-duration final sample")
    frames = manifest["frames"]
    ver.check(len(frames) == 98, "all 98 original manifest entries retained")
    next_tick = 0
    positive_holds: set[int] = set()
    for index, item in enumerate(frames):
        label = f"source index {index}"
        tick, hold = item["pts_ticks"], item["source_duration_ticks"]
        filename = f"frames/frame_{index:06d}.png"
        ver.check(type(tick) is int and type(hold) is int
                  and item["index"] == index and tick == next_tick,
                  label + " original integer index and contiguous PTS")
        ver.check(item["file"] == filename and item["sha256"] == records["art/c03/" + filename]["source_sha256"],
                  label + " canonical runtime path and pinned PNG identity")
        check_png(ver, local_path(project / "art/c03", filename), (960, 960), rgba=True)
        if index < 97:
            ver.check(hold > 0 and tick < MEDIA_END_TICKS,
                      label + " positive source duration before exact end")
            positive_holds.add(hold)
        else:
            ver.check(tick == MEDIA_END_TICKS and hold == 0,
                      "index97 remains zero duration at T; no invented final hold")
        if index:
            ver.check(tick > frames[index-1]["pts_ticks"], label + " strictly increasing source PTS")
        next_tick += hold
    ver.check(next_tick == MEDIA_END_TICKS and len(positive_holds) > 1,
              "nonuniform source durations sum to exact 260250 ticks")
    ver.check({path.name for path in (project / "art/c03/frames").glob("*.png")}
              == {f"frame_{index:06d}.png" for index in range(98)}, "exact runtime set of 98 source PNGs")

    audio = manifest["audio"]
    ver.check(audio["file"] == "audio/feather-selected.wav" and audio["sha256"] == WAV_SHA
              and audio["suggested_start_seconds"] == 0.405,
              "selected unchanged WAV and waveform-only suggested offset")
    wav_path = local_path(project / "art/c03", audio["file"])
    ver.hash(wav_path, WAV_SHA, "selected original WAV bytes")
    with wave.open(str(wav_path), "rb") as wav:
        params = (wav.getframerate(), wav.getnchannels(), wav.getsampwidth(), wav.getnframes(), wav.getcomptype())
        pcm = wav.readframes(wav.getnframes())
    ver.check(params == (44100, 2, 2, 44100, "NONE"), "original one-second 44.1kHz stereo 16-bit PCM metadata")
    ver.check(len(pcm) == 44100 * 4 and hashlib.sha256(pcm).hexdigest() == PCM_SHA,
              "all selected original PCM samples and channels")
    ver.check(Fraction(405, 1000) + Fraction(params[3], params[0]) < MEDIA_END,
              "candidate audio file tail precedes video T; no original video-audio tail assumption")
    board_path = project / "art/forest-board.png"
    ver.hash(board_path, BOARD_SHA, "approved unchanged forest board bytes")
    # The source board is 1672x941; 1440x810 is the presentation viewport.
    check_png(ver, board_path, (1672, 941), rgba=False)

    candidate = args.candidate.resolve() if args.candidate else project.parent / CANDIDATE_REL
    comparison = "absent; all pinned runtime/resource-list/PNG/WAV/PCM checks remained mandatory"
    if args.candidate is not None:
        ver.check(candidate.is_dir(), "explicitly requested source candidate exists")
    if candidate.is_dir():
        pairs = [(candidate / "manifest.json", manifest_path),
                 (candidate / "audio/feather-selected.wav", wav_path)]
        pairs += [(candidate / f"frames/frame_{index:06d}.png",
                   project / f"art/c03/frames/frame_{index:06d}.png") for index in range(98)]
        for source, runtime in pairs:
            ver.check(source.is_file() and source.read_bytes() == runtime.read_bytes(),
                      source.name + " candidate-to-runtime byte equality")
        comparison = "compared all 98 PNGs, mapped manifest and selected WAV byte for byte"
    board_source = project.parent / "bear-forehand-showcase/art/forest-board.png"
    board_comparison = "absent; pinned board SHA remained mandatory"
    if board_source.is_file():
        ver.check(board_source.read_bytes() == board_path.read_bytes(), "repository board-to-runtime byte equality")
        board_comparison = "compared repository board byte for byte"
    return {"project": str(project), "source_asset_commit": SOURCE_COMMIT,
            "resource_list_sha256": RESOURCE_LIST_SHA, "copied_resource_count": len(records),
            "source_manifest_entries": len(frames), "media_end_ticks": MEDIA_END_TICKS,
            "media_end_seconds": float(MEDIA_END), "final_sample_duration_ticks": 0,
            "candidate_comparison": comparison, "board_source_comparison": board_comparison,
            "audio_duration_seconds": params[3] / params[0],
            "scope": SCOPE}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--candidate", type=Path, help="optional explicit source candidate; missing explicit paths fail")
    parser.add_argument("--output", type=Path, help="absolute JSON result path")
    args = parser.parse_args()
    if args.output is not None and not args.output.is_absolute():
        parser.error("--output must be an absolute path")
    ver = Verification()
    details: dict = {}
    try:
        details = verify(args, ver)
    except (OSError, ValueError, TypeError, KeyError, IndexError, AttributeError, struct.error, wave.Error) as error:
        ver.check(False, f"{type(error).__name__}: {error}")
    report = {"schema": "c03-single-author-resource-checks-v1", "scope": SCOPE, **details,
              "checks": ver.checks, "failures": len(ver.failures), "failure_messages": ver.failures}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))
    return 1 if ver.failures else 0


if __name__ == "__main__":
    sys.exit(main())
