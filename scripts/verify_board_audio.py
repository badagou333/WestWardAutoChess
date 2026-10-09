#!/usr/bin/env python3
"""Verify D006 selected WAV copies and the exact noncommercial hunter exception.

This is an offline material check, NOT game-event, listening or PCK acceptance.
Default commercial mode deliberately rejects this specific noncommercial set.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import wave
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SOURCE_REL = "godot-demo/audio/candidates/selected-20261009"
RUNTIME_REL = "godot-demo/audio/runtime/board-selected-20261009"
PROFILE = "board-selected-noncommercial-20261009"
HUNTER = "hunter_launch_02_noncommercial"
# Pinned selected files, not a generic allow-list of CC BY-NC licenses.
# id: (filename, complete WAV sha256, frames, channels, individual license)
PINS = {
    "monk_bear_whack": ("monk_bear_whack.wav", "56502597d09207bc3b4acc3f866ef685eb5a4306852e2f16b89889cc666d4fde", 19459, 2, "CC0 1.0"),
    "wolf_attack_full": ("wolf_attack_full.wav", "087c1e90d04801ad1d732df2e8b2df45efda00c54362e0e29ea34db3ad0026f2", 106531, 2, "CC BY 3.0"),
    "boar_attack_full": ("boar_attack_full.wav", "73258a27856e1b5453e4bbec55555b9fc574b1d522c74ec9c1ac157283fe56c3", 17052, 2, "CC0 1.0"),
    "sparrow_attack": ("sparrow_attack_first.wav", "32f3ba8d0c0f48572f5d410202e53add1e675934ec0d2f0a52f11f34f86ee995", 22491, 2, "CC0 1.0"),
    "rat_attack": ("rat_attack_second.wav", "7b1461f9f572778ab1b58bb5d746b50775087b74abbc160d53620121cc012f94", 8820, 2, "CC BY 3.0"),
    "healer_new": ("healer_new_full.wav", "3a40ab16654b2be18d4888976833984b6f13057897b11c643aec001f7fa2c894", 39900, 2, "CC0 1.0"),
    "foxfire_A": ("foxfire_A_faithful.wav", "aa30009e92190a69ec99a404f047b453606a8f6e79e5a0f4fe3de495a900a7db", 25137, 1, "CC BY 4.0"),
    "hunter_launch_02_noncommercial": ("hunter_launch_02.wav", "6936dbe90b719c90d1dfa8900fc1736ca1bda035b767931d00e67e94027ac9a7", 5732, 2, "CC BY-NC 4.0"),
}
# role: (asset id, actual event boundary); Tang has no added attack sound.
ROLE_PINS = {
    "guard_monk": ("monk_bear_whack", "melee_damage_applied"),
    "wild_hunter": ("hunter_launch_02_noncommercial", "projectile_launched"),
    "sparrow_spirit": ("sparrow_attack", "projectile_launched"),
    "herbal_spirit_child": ("healer_new", "positive_healing_applied"),
    "foxfire_imp": ("foxfire_A", "projectile_launched"),
    "rat": ("rat_attack", "projectile_damage_applied"),
    "boar": ("boar_attack_full", "melee_damage_applied"),
    "wolf": ("wolf_attack_full", "melee_damage_applied"),
    "bear_lord": ("monk_bear_whack", "melee_damage_applied"),
}
PROVENANCE_KEYS = (
    "source_id", "source_title", "author", "source_page", "license",
    "license_url", "license_checked", "source_sha256", "source_kind", "changes",
    "sha256", "frames", "duration_seconds", "sample_rate", "bits", "channels",
)
FORBIDDEN_KEYS = {"input", "raw_source", "prior_manifest", "backups", "reference_path"}
LICENSE_URLS = {
    "CC0 1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "CC BY 3.0": "https://creativecommons.org/licenses/by/3.0/",
    "CC BY 4.0": "https://creativecommons.org/licenses/by/4.0/",
    "CC BY-NC 4.0": "https://creativecommons.org/licenses/by-nc/4.0/",
}


def asset_path(base: Path, relative: str) -> Path:
    value = PurePosixPath(relative)
    if value.is_absolute() or ".." in value.parts or "\\" in relative:
        raise ValueError(f"unsafe asset path: {relative}")
    path = (base / relative).resolve()
    if not path.is_relative_to(base.resolve()):
        raise ValueError(f"asset escapes its own delivery: {relative}")
    return path


def wav_info(path: Path) -> dict:
    whole_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    with wave.open(str(path), "rb") as handle:
        frames = handle.getnframes()
        pcm = handle.readframes(frames)
        return {
            "sha256": whole_hash,
            "pcm_sha256": hashlib.sha256(pcm).hexdigest(),
            "encoding": "PCM" if handle.getcomptype() == "NONE" else handle.getcomptype(),
            "sample_rate": handle.getframerate(), "bits": handle.getsampwidth() * 8,
            "channels": handle.getnchannels(), "frames": frames,
            "pcm_bytes": len(pcm),
        }


def forbidden_keys(value) -> set[str]:
    if isinstance(value, dict):
        found = set(value).intersection(FORBIDDEN_KEYS)
        for child in value.values():
            found.update(forbidden_keys(child))
        return found
    if isinstance(value, list):
        return set().union(*(forbidden_keys(child) for child in value))
    return set()


def verify(mode: str, source: Path, runtime: Path) -> dict:
    failures: list[str] = []
    verified: list[dict] = []

    def check(condition: bool, reason: str) -> None:
        if not condition:
            failures.append(reason)

    selected = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    deployed = json.loads((runtime / "manifest.json").read_text(encoding="utf-8"))
    source_assets = {asset["id"]: asset for asset in selected["assets"]}
    assets = {asset["id"]: asset for asset in deployed["assets"]}
    check(len(selected["assets"]) == len(source_assets) == 8, "source must contain exactly eight distinct selected assets")
    check(len(deployed["assets"]) == len(assets) == 8, "runtime must contain exactly eight distinct assets")
    check(set(source_assets) == set(assets) == set(PINS), "source/runtime selected asset IDs differ from the pinned eight")
    check(deployed.get("profile") == PROFILE, "runtime must name this exact noncommercial profile")
    check(deployed.get("schema_version") == 1, "unknown runtime schema")
    check(deployed.get("role_count") == 9 and deployed.get("file_count") == 8 and deployed.get("external_source_count") == 8, "runtime inventory counts must remain 9 roles / 8 files / 8 sources")
    check(deployed.get("sample_rate") == selected.get("sample_rate") == 44100 and deployed.get("sample_width_bytes") == selected.get("sample_width_bytes") == 2, "global format must be 44.1kHz / 16-bit PCM")
    check(not forbidden_keys(deployed), "runtime manifest must not depend on source/backup/reference local paths")
    semantics = deployed.get("hash_semantics", {})
    check("complete" in semantics.get("sha256", "") and "PCM" in semantics.get("pcm_sha256", ""), "manifest must distinguish full WAV and imported PCM hashes")
    check(deployed["roles"] == selected["roles"] and len(deployed["roles"]) == 9, "nine role/event mappings must exactly preserve the selected delivery")
    check({role["role"] for role in deployed["roles"]} == set(ROLE_PINS), "unexpected or missing role; no Tang attack cue may be added")
    for role in deployed["roles"]:
        pin = ROLE_PINS.get(role["role"])
        check(pin == (role.get("asset"), role.get("recommended_trigger")) and role.get("event_key") == role["role"] + "_attack" and role.get("plays_per_attack_max") == 1, f"role event/asset/trigger/single-play mismatch: {role['role']}")

    for asset_id, (filename, whole_hash, frames, channels, license_name) in PINS.items():
        if asset_id not in source_assets or asset_id not in assets:
            continue
        old, new = source_assets[asset_id], assets[asset_id]
        check(new.get("file") == "wav/" + filename, f"runtime asset must use its own wav path: {asset_id}")
        check(old.get("file") == ("noncommercial/wav/" if asset_id == HUNTER else "wav/") + filename, f"selected delivery path changed: {asset_id}")
        check(all(new.get(key) == old.get(key) for key in PROVENANCE_KEYS), f"provenance/license/changes/format differs from selected delivery: {asset_id}")
        check(new.get("license") == license_name and new.get("license_url") == LICENSE_URLS[license_name], f"individual selected license is not preserved: {asset_id}")
        check(new.get("sha256") == old.get("sha256") == whole_hash, f"selected WAV hash pin differs: {asset_id}")
        check(new.get("encoding") == "PCM", f"runtime encoding declaration differs: {asset_id}")
        settings = asset_path(runtime, new["file"] + ".import").read_text(encoding="utf-8")
        for option in ("compress/mode=0", "force/8_bit=false", "force/mono=false", "force/max_rate=false", "edit/trim=false", "edit/normalize=false", "edit/loop_mode=0"):
            check(option in settings.splitlines(), f"runtime Godot import must preserve exact PCM ({option}): {asset_id}")
        before = wav_info(asset_path(source, old["file"]))
        after = wav_info(asset_path(runtime, new["file"]))
        check(before == after, f"source-to-runtime WAV/PCM/format mismatch: {asset_id}")
        check(after["sha256"] == whole_hash and after["pcm_sha256"] == new.get("pcm_sha256"), f"actual full WAV / PCM digest mismatch: {asset_id}")
        check(after["encoding"] == "PCM" and after["sample_rate"] == 44100 and after["bits"] == 16 and after["frames"] == frames and after["channels"] == channels and after["pcm_bytes"] == frames * channels * 2, f"actual PCM format/frame/channel mismatch: {asset_id}")
        check(new.get("frames") == frames and new.get("channels") == channels and abs(float(new["duration_seconds"]) - frames / 44100) < 1e-12, f"runtime declared duration/frames/channels mismatch: {asset_id}")
        verified.append({"id": asset_id, "file": new["file"], **after})

    expected_files = {"wav/" + pin[0] for pin in PINS.values()}
    actual_files = {path.relative_to(runtime).as_posix() for path in runtime.rglob("*.wav")}
    check(actual_files == expected_files, "runtime has an extra/missing WAV outside the exact selected eight")
    check(not any((runtime / name).exists() for name in ("source", "backup", "backups", "reference", "references", "noncommercial")), "runtime must not include candidate/source/reference partitions")
    nc_assets = [asset for asset in deployed["assets"] if "-NC" in asset.get("license", "")]
    check(len(nc_assets) == 1 and nc_assets[0].get("id") == HUNTER, "no other NC asset is authorized")
    restrictions = deployed.get("usage_restriction", {})
    check(restrictions.get("contains_nc") is True and restrictions.get("commercial_permission_obtained") is False and restrictions.get("permitted_delivery_use") == "仅非商业试玩", "runtime must remain explicitly noncommercial, not commercial authorization")
    hunter_file = RUNTIME_REL + "/wav/" + PINS[HUNTER][0]
    exception = {
        "file": "wav/" + PINS[HUNTER][0], "repository_relative_file": hunter_file,
        "sha256": PINS[HUNTER][1], "source_id": "126464", "license": "CC BY-NC 4.0",
    }
    check(restrictions.get("exact_nc_exception") == exception, "NC exception must be exactly the selected hunter path/hash/source/license")
    check(runtime.resolve() == (ROOT / RUNTIME_REL).resolve() and asset_path(runtime, exception["file"]) == (ROOT / hunter_file).resolve(), "noncommercial exception only permits this exact repository runtime hunter path")
    if mode == "commercial":
        failures.append(f"COMMERCIAL_BLOCKED: {hunter_file} ({PINS[HUNTER][1]}) is CC BY-NC 4.0; replace source or obtain commercial permission. No general NC override exists.")

    expected_attribution = (source / "ATTRIBUTION.md").read_text(encoding="utf-8").replace("`noncommercial/wav/hunter_launch_02.wav`", "`wav/hunter_launch_02.wav`")
    check((runtime / "ATTRIBUTION.md").read_text(encoding="utf-8") == expected_attribution, "complete attribution must be preserved; only the final hunter relative path may change")
    use = (runtime / "USE.md").read_text(encoding="utf-8")
    check(PROFILE in use and "仅非商业" in use and PINS[HUNTER][1] in use and "pcm_sha256" in use, "USE must state exact NC restriction and distinct full-WAV / PCM checks")
    validation = json.loads((source / "VALIDATION.json").read_text(encoding="utf-8"))
    check(validation.get("role_count") == 9 and validation.get("file_count") == 8 and {item["id"]: item["sha256"] for item in validation["assets"]} == {asset_id: pin[1] for asset_id, pin in PINS.items()}, "selected technical-validation inventory differs from pinned assets")
    return {
        "profile": PROFILE, "mode": mode, "scope": "offline source-to-runtime material/license check; not game events, listening or PCK acceptance",
        "asset_count": len(verified), "role_count": len(deployed["roles"]),
        "foxfire_A_exact": assets.get("foxfire_A", {}).get("sha256") == PINS["foxfire_A"][1],
        "nc_exception": exception, "commercial_blocked": mode == "commercial",
        "assets": verified, "failures": failures, "passed": not failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("commercial", "noncommercial"), default="commercial")
    parser.add_argument("--source", type=Path, default=ROOT / SOURCE_REL)
    parser.add_argument("--runtime", type=Path, default=ROOT / RUNTIME_REL)
    args = parser.parse_args()
    try:
        result = verify(args.mode, args.source.resolve(), args.runtime.resolve())
    except (OSError, ValueError, KeyError, TypeError, wave.Error) as error:
        result = {"profile": PROFILE, "mode": args.mode, "passed": False, "failures": [str(error)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
