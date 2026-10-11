#!/usr/bin/env python3
"""List and validate files stored in an unencrypted Godot 4 PCK."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from verify_board_audio import PINS, ROLE_PINS, PROFILE, HUNTER, RUNTIME_REL

BOARD_AUDIO = "audio/runtime/board-selected-20261010/"


REQUIRED_RELEASE_FILES = (
    "scripts/combat/board_trial_melee.gd.remap",
    "scripts/combat/board_trial_stepwise.gd.remap",
    "scripts/presentation/board_trial_healer_view.gd.remap",
    "scripts/presentation/board_trial_bear_view.gd.remap",
    "scripts/presentation/board_trial_monk_view.gd.remap",
    "art/boards/formation_trial_v2/board-courtyard.png.import",
    "scripts/presentation/board_trial_ui.gd.remap",
    "scripts/presentation/board_trial_portrait.gd.remap",
    "scripts/presentation/board_trial_meter.gd.remap",
    "scripts/presentation/board_trial_style.gd.remap",
    "scripts/presentation/board_trial_hero.gd.remap",
    "scripts/presentation/board_trial_enemy.gd.remap",
    "scenes/board_trial.tscn.remap",
    "scenes/audio_trial.tscn.remap",
    "scripts/audio_trial.gd.remap",
    "scripts/presentation/audio_trial_ui.gd.remap",
    "scripts/presentation/audio_trial_feedback.gd.remap",
    "scripts/board_trial.gd.remap",
    "scripts/board_trial_core.gd.remap",
    "scripts/combat/board_trial_space.gd.remap",
    "scripts/data/board_trial_config.gd.remap",
    "scenes/monk_animation_trial.tscn.remap",
    "scripts/monk_animation_trial.gd.remap",
    "scripts/presentation/motion_sample_track.gd.remap",
    "art/reviews/animation-samples-20261004/guard_monk/manifest.json",
    "art/reviews/animation-samples-20261004/guard_monk/body-atlas.png.import",
    "scripts/data/run_casualties.gd.remap",
    "scripts/presentation/roster_style.gd.remap",
    "scripts/presentation/roster_hud.gd.remap",
    "scripts/data/camp_positions.gd.remap",
    "scenes/free_escort.tscn.remap",
    "scripts/free_escort.gd.remap",
    "scripts/data/free_escort_rules.gd.remap",
    "scripts/combat/continuous_space.gd.remap",
    "art/production/escort_map/natural_ground_v1/background.png.import",
    "scenes/escort_route.tscn.remap",
    "scripts/escort_route.gd.remap",
    "scripts/data/escort_map.gd.remap",
    "scripts/combat/friendly_transit.gd.remap",
    "art/production/escort_map/painted_route_v2/background.png.import",
    "art/production/wild_hunter/nine_sols_v1/manifest.json",
    "art/production/gray_rat/nine_sols_v1/manifest.json",
    "art/production/tangseng/nine_sols_v1/idle.png.import",
    "scenes/main.tscn.remap",
    "scripts/game.gd.remap",
    "scripts/unit.gd.remap",
    "scripts/enemy.gd.remap",
    "scripts/presentation/audio_feedback.gd.remap",
    "scripts/presentation/board_trial_audio.gd.remap",
    "CREDITS.md",
    BOARD_AUDIO + "manifest.json",
    BOARD_AUDIO + "ATTRIBUTION.md",
    BOARD_AUDIO + "USE.md",
    "art/demo/hero_atlas_keyed.png.import",
    "art/demo/enemy_atlas_keyed.png.import",
    "art/reviews/style-unification-v1/battlefield-candidate.png.import",
    "art/production/guard_monk/demo_v1/manifest.json",
    "art/production/boar/painted_v1/manifest.json",
    "audio/runtime_overrides.json",
    "audio/candidates/foxfire-dwoboyle-v1/foxfire_A_faithful.wav.import",
) + tuple(BOARD_AUDIO + "wav/" + pin[0] + ".import" for pin in PINS.values()) + tuple(
    f"art/production/{role}/nine_sols_v1/idle.png.import"
    for role in ("guard_monk", "wild_hunter", "sparrow_spirit", "herbal_spirit_child", "foxfire_imp", "mountain_wolf", "boar", "gray_rat", "bear_lord")
) + tuple(
    f"art/production/{role}/nine_sols_v1/{file}"
    for role in ("guard_monk", "wild_hunter", "herbal_spirit_child", "sparrow_spirit", "foxfire_imp", "bear_lord", "mountain_wolf", "gray_rat", "boar", "tangseng")
    for file in ("manifest.json", "body-atlas.png.import")
)

FORBIDDEN_RELEASE_PREFIXES = (
    "art/boards/formation_trial_v2/review/",
    "art/reviews/formation-ui-v2/",
    "art/boards/formation_trial_v1/review/",
    "art/reviews/foxfire-spine-trial-",
    "art/reviews/wolf-gait-d004-",
    "tests/",
    "art/concepts/",
    "art/reviews/six-role-battle/",
    "art/production/tools/",
    "audio/candidates/foxfire-dwoboyle-v1/source/",
    "audio/candidates/selected-20261009/",
    "audio/candidates/healer-lilmati-v1/",
    "audio/candidates/sparrow-plantmonkey-v1/",
    "audio/candidates/rat-cheddababy-v1/",
    "audio/candidates/wolf-first-call-v1/",
    "audio/runtime/board-selected-20261009/",
)


def read_u32(handle) -> int:
    data = handle.read(4)
    if len(data) != 4:
        raise ValueError("PCK ended while reading uint32")
    return struct.unpack("<I", data)[0]


def read_u64(handle) -> int:
    data = handle.read(8)
    if len(data) != 8:
        raise ValueError("PCK ended while reading uint64")
    return struct.unpack("<Q", data)[0]


def read_entries(pck_path: Path) -> dict[str, tuple[int, int]]:
    with pck_path.open("rb") as handle:
        if handle.read(4) != b"GDPC":
            raise ValueError("not a Godot PCK (missing GDPC header)")
        pack_version = read_u32(handle)
        if pack_version not in (2, 3, 4):
            raise ValueError(f"unsupported PCK format version: {pack_version}")
        read_u32(handle)  # Engine major.
        read_u32(handle)  # Engine minor.
        read_u32(handle)  # Engine patch.
        pack_flags = read_u32(handle)
        file_base = read_u64(handle)
        directory_offset = read_u64(handle) if pack_version >= 4 else None
        handle.seek(16 * 4, 1)  # Reserved words.
        if pack_flags & 1:
            raise ValueError("encrypted PCK directories are not supported")
        if directory_offset is not None:
            handle.seek(directory_offset)
        file_count = read_u32(handle)
        entries: dict[str, tuple[int, int]] = {}
        for _ in range(file_count):
            path_size = read_u32(handle)
            raw_path = handle.read(path_size)
            if len(raw_path) != path_size:
                raise ValueError("PCK ended while reading a path")
            path = raw_path.rstrip(b"\0").decode("utf-8")
            offset = read_u64(handle)
            size = read_u64(handle)
            if len(handle.read(16)) != 16:
                raise ValueError("PCK ended while reading MD5")
            flags = read_u32(handle)
            if flags & 1:
                raise ValueError("encrypted PCK files are not supported")
            entries[path] = (file_base + offset, size)
        return entries


def list_paths(pck_path: Path) -> list[str]:
    return list(read_entries(pck_path))


def packed_text(pck: Path, entries: dict, path: str) -> str:
    offset, size = entries[path]
    if size > 256 * 1024:
        raise ValueError("unexpectedly large package text: " + path)
    with pck.open("rb") as handle:
        handle.seek(offset)
        raw = handle.read(size)
    if len(raw) != size:
        raise ValueError("truncated package text: " + path)
    return raw.decode("utf-8")


def check_board_usage(manifest: dict, usage: str) -> None:
    if manifest.get("profile") != PROFILE:
        raise ValueError("package has unknown board audio profile")
    assets = {entry["id"]: entry for entry in manifest["assets"]}
    if len(manifest["assets"]) != 9 or set(assets) != set(PINS):
        raise ValueError("package audio assets differ from the exact current nine")
    for asset_id, (name, sha, frames, channels, license_name) in PINS.items():
        entry = assets[asset_id]
        if (entry.get("file"), entry.get("sha256"), entry.get("frames"), entry.get("channels"), entry.get("license")) != ("wav/" + name, sha, frames, channels, license_name):
            raise ValueError("package path/hash/format/license pin changed: " + asset_id)
    roles = manifest["roles"]
    if len(roles) != 9 or {entry["role"]: (entry["asset"], entry["recommended_trigger"]) for entry in roles} != ROLE_PINS:
        raise ValueError("package role/trigger mapping changed")
    if manifest.get("secondary_cues") != [{"event_key":"tangseng_hurt_warning","asset":"tangseng_hurt_warning","recommended_trigger":"positive_core_damage"}]:
        raise ValueError("package warning mapping changed")
    if manifest.get("disable_cues") != ["rat_death","boar_death","wolf_death","bear_lord_death","victory"] or manifest.get("event_count") != 10:
        raise ValueError("package disabled cues/current event count changed")
    restriction = manifest["usage_restriction"]
    exact = {"file":"wav/" + PINS[HUNTER][0], "repository_relative_file": RUNTIME_REL + "/wav/" + PINS[HUNTER][0], "sha256":PINS[HUNTER][1], "source_id":"126464", "license":"CC BY-NC 4.0"}
    if restriction.get("exact_nc_exception") != exact or restriction.get("permitted_delivery_use") != "仅非商业试玩" or restriction.get("commercial_permission_obtained") is not False:
        raise ValueError("package NC exception is not this exact hunter path/hash/noncommercial use")
    if usage != "noncommercial":
        raise ValueError("COMMERCIAL_BLOCKED: selected Robinhood76 hunter sound is CC BY-NC 4.0; replace it or obtain permission")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pck", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--release-policy", action="store_true")
    parser.add_argument("--usage", choices=("commercial", "noncommercial"), default="commercial")
    args = parser.parse_args()

    entries = read_entries(args.pck)
    paths = list(entries)
    listing = "\n".join(paths) + "\n"
    if args.output:
        args.output.write_text(listing, encoding="utf-8")
    else:
        print(listing, end="")

    if args.release_policy:
        missing = [item for item in REQUIRED_RELEASE_FILES if item not in paths]
        forbidden = [
            item
            for item in paths
            if any(item.startswith(prefix) for prefix in FORBIDDEN_RELEASE_PREFIXES)
        ]
        if missing:
            raise SystemExit("PCK missing required files: " + ", ".join(missing))
        if forbidden:
            raise SystemExit("PCK contains forbidden files: " + ", ".join(forbidden))
        expected_runtime = {BOARD_AUDIO + name for name in ("manifest.json", "ATTRIBUTION.md", "USE.md")} | {BOARD_AUDIO + "wav/" + pin[0] + ".import" for pin in PINS.values()}
        if {name for name in paths if name.startswith(BOARD_AUDIO)} != expected_runtime:
            raise SystemExit("PCK includes extra/missing files in the selected board runtime directory")
        try:
            manifest = json.loads(packed_text(args.pck, entries, BOARD_AUDIO + "manifest.json"))
            check_board_usage(manifest, args.usage)
            project = Path(__file__).resolve().parents[1] / "godot-demo"
            for name in ("ATTRIBUTION.md", "USE.md"):
                if packed_text(args.pck, entries, BOARD_AUDIO + name) != (project / BOARD_AUDIO / name).read_text(encoding="utf-8"):
                    raise ValueError("package does not retain complete runtime declaration: " + name)
            if "仅非商业" not in packed_text(args.pck, entries, "CREDITS.md"):
                raise ValueError("package credits omit the noncommercial use restriction")
        except (ValueError, KeyError, TypeError, OSError) as error:
            raise SystemExit(str(error)) from error
        print(f"PCK_POLICY_OK files={len(paths)} usage={args.usage} (PCM behavior/hash verified separately by Godot runtime test)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
