#!/usr/bin/env python3
"""List and validate files stored in an unencrypted Godot 4 PCK."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


REQUIRED_RELEASE_FILES = (
    "scripts/combat/board_trial_melee.gd.remap",
    "scripts/presentation/board_trial_healer_view.gd.remap",
    "art/boards/formation_trial_v2/board-courtyard.png.import",
    "scripts/presentation/board_trial_ui.gd.remap",
    "scripts/presentation/board_trial_portrait.gd.remap",
    "scripts/presentation/board_trial_meter.gd.remap",
    "scripts/presentation/board_trial_style.gd.remap",
    "scripts/presentation/board_trial_hero.gd.remap",
    "scripts/presentation/board_trial_enemy.gd.remap",
    "scenes/board_trial.tscn.remap",
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
    "art/demo/hero_atlas_keyed.png.import",
    "art/demo/enemy_atlas_keyed.png.import",
    "art/reviews/style-unification-v1/battlefield-candidate.png.import",
    "art/production/guard_monk/demo_v1/manifest.json",
    "art/production/boar/painted_v1/manifest.json",
    "audio/runtime_overrides.json",
    "audio/candidates/foxfire-dwoboyle-v1/foxfire_A_faithful.wav.import",
) + tuple(
    f"art/production/{role}/nine_sols_v1/idle.png.import"
    for role in ("guard_monk", "wild_hunter", "sparrow_spirit", "herbal_spirit_child", "foxfire_imp", "mountain_wolf", "boar", "gray_rat")
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


def list_paths(pck_path: Path) -> list[str]:
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
        read_u64(handle)  # File base.
        directory_offset = read_u64(handle) if pack_version >= 4 else None
        handle.seek(16 * 4, 1)  # Reserved words.
        if pack_flags & 1:
            raise ValueError("encrypted PCK directories are not supported")
        if directory_offset is not None:
            handle.seek(directory_offset)
        file_count = read_u32(handle)
        paths: list[str] = []
        for _ in range(file_count):
            path_size = read_u32(handle)
            raw_path = handle.read(path_size)
            if len(raw_path) != path_size:
                raise ValueError("PCK ended while reading a path")
            path = raw_path.rstrip(b"\0").decode("utf-8")
            read_u64(handle)  # Offset.
            read_u64(handle)  # Size.
            if len(handle.read(16)) != 16:
                raise ValueError("PCK ended while reading MD5")
            read_u32(handle)  # File flags.
            paths.append(path)
        return paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pck", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--release-policy", action="store_true")
    args = parser.parse_args()

    paths = list_paths(args.pck)
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
        print(f"PCK_POLICY_OK files={len(paths)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
