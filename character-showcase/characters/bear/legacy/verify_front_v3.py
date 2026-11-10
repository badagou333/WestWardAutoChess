#!/usr/bin/env python3
"""Deterministic v3 asset checks for D-20261102-002; no visual/audio judgement.

The runtime can be checked without the candidate directory (for a clean copy).
Pinned manifest/WAV/PCM hashes and every referenced PNG remain mandatory.
Use --ffmpeg for an additional fresh source-MOV audio decode and PCM comparison.
The preserved verify_front_v2.py checks the historical v2 runtime baseline only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import wave

FRONT_MANIFEST_SHA = "53f2cd27b2678282ae8e8fa905b4ce8e46cded2623a7b9384e1c870c3b3e2237"
FRONT_WAV_SHA = "aaaf61ca9f75ebb4f8c9657108ac0a47245f0ef00efa38bd6a95066803b9caf9"
FRONT_PCM_SHA = "7a2f42154eac131e6c940512574c485a3a89d009abf313d699462f4be0e56816"
BACK_PNG_TREE_SHA = "ecaeacc83a05840662acea2786312c36ba8d1dcd3e0dfd81d52af11aa83dc2b4"
PROTECTED = {
    "art/forest-board.png": "7b568eb54ad25d18efa7dab24adcce833a4528940fdd615ca053196cd6ad1ed6",
    "art/back/manifest.json": "57fcd1ef9657f283cbd2d4d9779fa7d7d8b62c110414691c8928f83a721d1399",
    "audio/back-source-track.wav": "f22f557d3a4eac26ea8055b4cfe363374361d602e7eaf0d49c9f0718fc3bd2d3",
    "showcase.tscn": "320e806adae6ca89585ec47a6f985bfa04c3c7380bacfed0fbffc4b8b634531c",
    "project.godot": "d3a248c5661aa32896f539be26857e7794854596b1a90c9a217f1db060e7a5dc",
    "showcase.gd": "7679071926a6b6467486f61670a6fd2810b9ca5ef12bce87f311a478c6fa7d7c",
    "launch.command": "89b19f48a831834386ab1a910b13d89233f288eb0b0d801e66b913fa0fd86d70",
    "clips.json": "703bc1e63fb74267d41a200bfaee8f55d872fb06bbac6c6195fe1b826d5fc07f",
}
SOURCE_SHA = "d37dffe785d83306c0f41f54b12348d0043f189bcf91251659816e291be548c0"
CANDIDATE_REL = Path("godot-demo/art/candidates/bear_lord_front_attack_v3")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Verification:
    def __init__(self) -> None:
        self.checks = 0
        self.failures: list[str] = []

    def check(self, condition: bool, label: str) -> None:
        self.checks += 1
        if not condition:
            self.failures.append(label)

    def equal_time(self, first: float, second: float, label: str) -> None:
        self.check(math.isclose(first, second, rel_tol=0, abs_tol=1e-12), label)

    def hash(self, path: Path, expected: str, label: str) -> None:
        self.check(path.is_file() and digest(path) == expected, label)


def read_pcm(path: Path) -> tuple[tuple[int, int, int, int, str], bytes]:
    with wave.open(str(path), "rb") as audio:
        params = (audio.getframerate(), audio.getnchannels(), audio.getsampwidth(),
                  audio.getnframes(), audio.getcomptype())
        return params, audio.readframes(audio.getnframes())


def check_png(ver: Verification, path: Path, expected_size: tuple[int, int]) -> None:
    header = path.read_bytes()[:33]
    ver.check(len(header) == 33 and header[:8] == b"\x89PNG\r\n\x1a\n"
              and header[12:16] == b"IHDR", str(path.name) + " valid PNG header")
    if len(header) == 33:
        width, height, depth, color = struct.unpack(">IIBB", header[16:26])
        ver.check((width, height) == expected_size and depth == 8 and color == 6,
                  str(path.name) + " fixed RGBA canvas")


def verify(args: argparse.Namespace, ver: Verification) -> dict:
    showcase = args.showcase.resolve()
    front_path = showcase / "art/attack/manifest.json"
    front = json.loads(front_path.read_text())
    config = json.loads((showcase / "clips.json").read_text())
    ver.hash(front_path, FRONT_MANIFEST_SHA, "front v3 authoritative manifest bytes")
    ver.check(config["schema"] == "bear-attack-showcase-v1"
              and set(config["clips"]) == {"front", "back"}, "same two-clip config")
    expected_settings = {
        "front": {"manifest": "art/attack/manifest.json", "audio": "audio/source-track.wav",
                  "video_duration_seconds": 3.0, "loop_interval_seconds": 0,
                  "display_scale": 0.75, "source_sign": 1},
        "back": {"manifest": "art/back/manifest.json", "audio": "audio/back-source-track.wav",
                 "video_duration_seconds": 3.5416666666666665, "loop_interval_seconds": 0.35,
                 "display_scale": 0.75, "source_sign": 1},
    }
    for clip_id, settings in expected_settings.items():
        ver.check(config["clips"][clip_id] == settings, clip_id + " exact clip settings")
    ver.check(front["schema"] == "board-bear-front-trail-trial-v1"
              and front["source_time_base"] == [1, 15360]
              and front["decoded_frame_count"] == 84
              and front["original_frame_range"] == [10, 93], "front v3 authoritative source range and timebase")
    ver.check(front["canvas"] == [400, 320] and front["foot"] == [177, 213]
              and front["display_scale"] == 0.75 and front["source_sign"] == 1
              and front["source_back"] is False, "front fixed geometry and source direction")
    frames = front["frames"]
    expected_names = {f"attack_{number:04d}.png" for number in range(1, 85)}
    ver.check(len(frames) == 84 and {item["file"] for item in frames} == expected_names,
              "all 84 consecutive numbered front frames")
    ver.check({path.name for path in front_path.parent.glob("*.png")} == expected_names,
              "runtime has exactly the 84 new PNGs and no old sparse frames")
    next_pts = 0
    durations = set()
    for number, item in enumerate(frames, 1):
        label = f"front {number}"
        ver.check(item["source_frame"] == number and item["original_source_frame"] == number + 9,
                  label + " original numbering")
        ver.check(item["source_pts"] == next_pts
                  and item["original_source_pts"] == next_pts + 5888,
                  label + " contiguous source PTS")
        ver.equal_time(item["source_time_seconds"], next_pts / 15360, label + " source time")
        ver.equal_time(item["output_time_seconds"], next_pts / 15360, label + " output time")
        ver.equal_time(item["duration_seconds"], item["duration_ticks"] / 15360, label + " source hold")
        path = front_path.parent / item["file"]
        ver.hash(path, item["sha256"], label + " original PNG bytes")
        check_png(ver, path, (400, 320))
        next_pts += item["duration_ticks"]
        durations.add(item["duration_ticks"])
    ver.check(next_pts == 46080 and durations == {128, 192, 512, 768},
              "nonuniform source durations cover exactly 3 seconds")
    ver.equal_time(frames[-1]["source_time_seconds"], 2.95, "last front frame starts at 2.95")
    ver.equal_time(frames[-1]["duration_seconds"], 0.05, "last front frame holds through 3.0")
    for number in (43, 44):
        item = frames[number - 1]
        ver.check(item["file"] == f"attack_{number:04d}.png"
                  and item["original_source_frame"] == number + 9
                  and item["repair"]["donor"] == 45, f"repaired frame {number} is present without skipping")
    front_audio = showcase / "audio/source-track.wav"
    ver.hash(front_audio, FRONT_WAV_SHA, "front original WAV bytes")
    params, pcm = read_pcm(front_audio)
    ver.check(params == (44100, 2, 2, 132280, "NONE"), "front original PCM parameters")
    ver.check(hashlib.sha256(pcm).hexdigest() == FRONT_PCM_SHA and len(pcm) == 529120,
              "front all original PCM sample bytes, stereo order unchanged")
    ver.check(0 < 3.0 - 132280 / 44100 < 0.001,
              "front sub-millisecond audio tail before zero-gap loop")

    for relative, expected in PROTECTED.items():
        ver.hash(showcase / relative, expected, "protected original " + relative)
    back = json.loads((showcase / "art/back/manifest.json").read_text())
    ver.check(len(back["frames"]) == 340 and back["unique_texture_count"] == 326
              and back["canvas"] == [384, 320] and back["foot"] == [177, 213],
              "back geometry and 340 source times retained")
    for index, item in enumerate(back["frames"]):
        ver.equal_time(item["source_time_seconds"], index / 96, f"back time {index + 1}")
        ver.hash(showcase / "art/back" / item["file"], item["sha256"],
                 f"back referenced PNG {index + 1} retained")
    back_files = sorted((showcase / "art/back").glob("*.png"))
    tree = hashlib.sha256()
    for path in back_files:
        tree.update((path.name + "\0" + digest(path) + "\n").encode())
    ver.check(len(back_files) == 340 and tree.hexdigest() == BACK_PNG_TREE_SHA,
              "all 340 back PNG files retained, including nonreferenced duplicates")
    back_params, back_pcm = read_pcm(showcase / "audio/back-source-track.wav")
    ver.check(back_params == (32000, 2, 2, 115968, "NONE")
              and hashlib.sha256(back_pcm).hexdigest()
              == "4a3c508d7c9aff8825ad2d87c0bf4b7c823a16439dbeb2a273fdfd43a99e2289",
              "back original PCM retained")

    candidate = args.candidate.resolve() if args.candidate else showcase.parent / CANDIDATE_REL
    candidate_status = "absent; pinned runtime checks remained mandatory"
    if args.candidate or candidate.is_dir():
        ver.check(candidate.is_dir(), "requested candidate directory exists")
        ver.hash(candidate / "manifest.json", FRONT_MANIFEST_SHA, "candidate v3 authoritative manifest bytes")
        ver.check((candidate / "manifest.json").read_bytes() == front_path.read_bytes(),
                  "runtime manifest copied byte for byte from candidate")
        for item in frames:
            ver.check((candidate / "frames" / item["file"]).read_bytes()
                      == (front_path.parent / item["file"]).read_bytes(),
                      item["file"] + " copied byte for byte from candidate")
        candidate_audio = candidate / "audio/source-track.wav"
        ver.check(candidate_audio.read_bytes() == front_audio.read_bytes(),
                  "runtime WAV copied byte for byte from candidate")
        ver.check(read_pcm(candidate_audio) == (params, pcm), "runtime PCM equals candidate PCM")
        candidate_status = "passed"

    decode_status = "not requested; this is not a cold MOV reconstruction"
    if args.ffmpeg:
        source = args.source.resolve() if args.source else candidate / front["source_video"]
        ver.hash(source, SOURCE_SHA, "source MOV authoritative bytes")
        decoded = subprocess.run(
            [str(args.ffmpeg), "-v", "error", "-i", str(source), "-map", "0:a:0",
             "-acodec", "pcm_s16le", "-f", "s16le", "-"],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ).stdout
        ver.check(decoded == pcm, "fresh source MOV audio decode equals every runtime PCM byte")
        decode_status = "passed"
    return {
        "showcase": str(showcase), "front_frames": len(frames),
        "back_source_times": len(back["frames"]), "candidate_comparison": candidate_status,
        "source_audio_decode": decode_status,
        "scope": "author deterministic checks; no image quality, device listening, OS input or independent acceptance",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--showcase", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--candidate", type=Path,
                        help="optional candidate directory; defaults to the repository candidate when present")
    parser.add_argument("--ffmpeg", type=Path, help="optional executable for fresh source-MOV audio decoding")
    parser.add_argument("--source", type=Path, help="source MOV override for --ffmpeg")
    parser.add_argument("--output", type=Path, help="absolute JSON report path")
    args = parser.parse_args()
    if args.output is not None and not args.output.is_absolute():
        parser.error("--output must be an absolute path")
    ver = Verification()
    details: dict = {}
    try:
        details = verify(args, ver)
    except (OSError, ValueError, KeyError, TypeError, IndexError, wave.Error,
            subprocess.CalledProcessError, struct.error) as error:
        ver.check(False, f"{type(error).__name__}: {error}")
    report = {"schema": "bear-front-v3-author-asset-checks", **details,
              "checks": ver.checks, "failures": len(ver.failures), "failure_messages": ver.failures}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))
    return 1 if ver.failures else 0


if __name__ == "__main__":
    sys.exit(main())
