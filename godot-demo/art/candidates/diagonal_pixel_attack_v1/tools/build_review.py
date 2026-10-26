#!/usr/bin/env python3
"""Build only derived review media for the two diagonal attack candidates.

Usage: bundled-python tools/build_review.py [--monk-scale .5 --wolf-scale .5]
Source manifests and character directories are read-only.  Missing directions
remain explicit placeholders; an integrity check never awards a visual pass.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from datetime import date
from html import escape
from html.parser import HTMLParser
import hashlib
import importlib.util
from io import BytesIO
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
OLD_BUILDER = ROOT.parent / "pixel_attack_series_v1/tools/build_attack.py"
spec = importlib.util.spec_from_file_location("diagonal_shared_encoding", OLD_BUILDER)
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)

ROLES = (("monk", "护寺棍僧"), ("wolf", "山狼"))
DIRECTIONS = ("se", "sw", "ne", "nw")
SOURCE_DIRECTION = {"se": "se", "sw": "se", "ne": "ne", "nw": "ne"}
MIRRORED = {"se": False, "sw": True, "ne": False, "nw": True}
PANEL = (320, 320)
CENTER = (160, 238)
BG = (28, 35, 43)
GRID = (109, 119, 118)
FILL = (42, 56, 57)
TEXT = (231, 218, 187)
SUBTEXT = (166, 181, 187)
STATUS = "under_review"
PARENT_STATUS = {}
DIRECTION_STATUS = {}
ROLE_STATUS = {}
OUTPUT = ROOT / "board_previews"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def safe_path(folder: Path, name: str) -> Path:
    path = (folder / name).resolve()
    if not path.is_relative_to(folder.resolve()) or not path.is_file():
        raise ValueError(f"Source reference unavailable/outside direction: {path}")
    return path


def source_snapshot(path: Path, snapshots: dict) -> bytes:
    data = path.read_bytes()
    snapshots[str(path)] = sha(data)
    return data


def gif_info(data: bytes) -> tuple[dict, list]:
    frames, durations = [], []
    with Image.open(BytesIO(data)) as image:
        if image.format != "GIF":
            raise ValueError("Expected GIF")
        for index in range(image.n_frames):
            image.seek(index)
            frames.append(image.convert("RGB").copy())
            durations.append(int(image.info.get("duration", 0)))
        size = list(image.size)
    if not all(x > 0 for x in durations):
        raise ValueError("GIF contains a zero-duration stage")
    return {"size": size, "encoded_frames": len(frames), "durations_ms": durations,
            "total_ms": sum(durations), "sha256": sha(data)}, frames


def load_direction(role: str, direction: str, snapshots: dict) -> dict | None:
    folder = ROOT / role / direction
    path = folder / "manifest.json"
    if not path.is_file():
        return None
    raw = source_snapshot(path, snapshots)
    manifest = json.loads(raw)
    if manifest["canvas"] != [448, 448] or manifest["anchor"] != [224, 344]:
        raise ValueError(f"Unexpected current canvas/anchor: {role}/{direction}")
    track = manifest["track"]
    renders = manifest["renders"]
    starts = [x["at_ms"] for x in track]
    if (len(renders) != len(track) or not starts or starts[0] != 0
            or starts != sorted(set(starts)) or starts[-1] >= manifest["duration_ms"]):
        raise ValueError(f"Invalid explicit stage sequence: {role}/{direction}")
    images = []
    for stage, record in zip(track, renders):
        if stage["at_ms"] != record["at_ms"] or stage["body"] != record["body"]:
            raise ValueError("Track and render differ")
        path = safe_path(folder, record["file"])
        data = source_snapshot(path, snapshots)
        if sha(data) != record["sha256"]:
            raise ValueError(f"Source is being rebuilt or hash is stale: {path}")
        with Image.open(BytesIO(data)) as image:
            image.load()
            if list(image.size) != manifest["canvas"]:
                raise ValueError(f"Render canvas mismatch: {path}")
            images.append(image.convert("RGBA").copy())
    for body in manifest["bodies"]:
        path = safe_path(folder, body["file"])
        data = source_snapshot(path, snapshots)
        if sha(data) != body["sha256"]:
            raise ValueError(f"Body SHA differs: {path}")
    previews = {}
    for name, factor in (("preview.gif", 1), ("preview_slow.gif", 2)):
        data = source_snapshot(safe_path(folder, name), snapshots)
        info, decoded = gif_info(data)
        timing = shared.gif_timing(track, manifest["duration_ms"], manifest["idle_ms"],
                                   manifest.get("events", []), factor)
        if (info["total_ms"] != timing["total_ms"]
                or info["sha256"] != manifest["previews"][name]["sha256"]):
            raise ValueError(f"Source GIF timing/SHA mismatch: {folder/name}")
        ends = np.cumsum(info["durations_ms"]).tolist()
        checked = 0
        for image, at in zip(images, timing["stage_starts_gif_ms"]):
            actual = np.asarray(decoded[bisect_right(ends, at)])
            wanted = np.asarray(image)
            opaque = wanted[:, :, 3] == 255
            if not np.array_equal(actual[opaque], wanted[:, :, :3][opaque]):
                raise ValueError(f"Source GIF changed opaque render RGB: {folder/name}")
            checked += int(opaque.sum())
        previews[name] = {**info, "opaque_render_rgb_exact": True,
                          "opaque_pixels_checked": checked, "factor": factor}
    # Source docs are links, not status authorities for this mechanical packager.
    docs = {name: relative(folder/name) if (folder/name).is_file() else None
            for name in ("README.md", "REVIEW.md", "contact_sheet.png")}
    return {"folder": folder, "manifest": manifest, "manifest_sha256": sha(raw),
            "images": images, "previews": previews, "docs": docs}


def gate_text(status: str) -> str:
    return "离线逐帧复核通过 · 待真人观感确认" if status == "limited_offline_pass" else "under_review · 复核中"


def load_parent_gates(all_sources: dict, snapshots: dict) -> tuple:
    """Inherit visual states only from the parent-maintained STATUS.json."""
    path = ROOT/"STATUS.json"
    parent = json.loads(source_snapshot(path,snapshots)) if path.is_file() else {}
    direction_states, role_states, evidence = {}, {}, {}
    for role,_ in ROLES:
        entry = parent.get("characters",{}).get(role,{})
        review = None
        if entry.get("review"):
            review_path = safe_path(ROOT,entry["review"])
            review = json.loads(source_snapshot(review_path,snapshots))
            evidence[role] = {"file":relative(review_path),"sha256":sha(review_path.read_bytes())}
        for direction in ("se","ne"):
            source = all_sources[role][direction]
            accepted = (source is not None and entry.get("status") == "reviewed_candidate"
                        and entry.get("visual_review") == "limited_offline_pass"
                        and entry.get("directions",{}).get(direction) == "limited_offline_pass")
            if accepted and review is not None:
                reviewed = review.get("directions",{}).get(direction,{})
                assert reviewed.get("status") == "limited_offline_pass", "Parent/evidence direction statuses disagree"
                # A textual gate must not silently outlive the exact reviewed PNGs.
                for kind in ("bodies","renders"):
                    records = reviewed.get(kind)
                    if records is not None:
                        current = source["manifest"][kind]
                        assert len(records) == len(current), "Reviewed/current stage count changed"
                        for old,new in zip(records,current):
                            assert old["file"] == new["file"] and old["sha256"] == new["sha256"], "Reviewed/current PNGs changed"
            direction_states[(role,direction)] = "limited_offline_pass" if accepted else "under_review"
        role_states[role] = "reviewed_candidate" if all(direction_states[(role,d)] == "limited_offline_pass" for d in ("se","ne")) else "under_review"
    overall = "reviewed_candidate" if (parent.get("overall_status") == "reviewed_candidate"
              and parent.get("visual_review",{}).get("status") == "limited_offline_pass"
              and all(state == "reviewed_candidate" for state in role_states.values())) else "under_review"
    return parent,direction_states,role_states,overall,evidence


def fonts(requested: str | None = None) -> tuple:
    candidates = [requested] if requested else ["/System/Library/Fonts/STHeiti Medium.ttc",
                  "C:/Windows/Fonts/msyh.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"]
    path = next((Path(name) for name in candidates if name and Path(name).is_file()), None)
    if path is None:
        raise ValueError("Pass --font with an installed Chinese-capable TTF/TTC/OTF; no font is downloaded")
    return ImageFont.truetype(str(path), 18), ImageFont.truetype(str(path), 13), path


FONT = SMALL = None


def board_background(role: str, direction: str, at: int | None = None) -> Image.Image:
    panel = Image.new("RGBA", PANEL, (*BG, 255))
    draw = ImageDraw.Draw(panel)
    cx, cy = CENTER
    points = [(cx, cy-48), (cx+96, cy), (cx, cy+48), (cx-96, cy)]
    draw.polygon(points, fill=(*FILL, 255), outline=(*GRID, 255))
    inner = [(cx, cy-43.2), (cx+86.4, cy), (cx, cy+43.2), (cx-86.4, cy)]
    draw.line(inner+[inner[0]], fill=(65, 83, 82, 255), width=1)
    draw.line((cx-4, cy, cx+4, cy), fill=(181, 176, 126, 255))
    draw.line((cx, cy-4, cx, cy+4), fill=(181, 176, 126, 255))
    title = dict(ROLES)[role]
    draw.text((12, 8), f"{title}  {direction.upper()}", font=FONT, fill=TEXT)
    status = DIRECTION_STATUS.get((role,SOURCE_DIRECTION[direction]),"under_review")
    if status == "limited_offline_pass":
        draw.text((12,31), "limited_offline_pass" if at is None else f"{at} ms · limited_offline_pass",font=SMALL,fill=SUBTEXT)
        draw.text((12,48),gate_text(status),font=SMALL,fill=SUBTEXT)
    else:
        draw.text((12,31), "under_review" if at is None else f"{at} ms · under_review",font=SMALL,fill=SUBTEXT)
    draw.text((12, 299), "192 × 96 · scale fixed per role", font=SMALL, fill=SUBTEXT)
    return panel


def place_board(source: Image.Image, anchor: list, scale: float, mirrored: bool,
                role: str, direction: str, at: int | None = None) -> tuple:
    if scale <= 0:
        raise ValueError("Display scale must be positive")
    width, height = source.size
    mirror_anchor = [width-anchor[0], anchor[1]] if mirrored else list(anchor)
    size = [round(width*scale), round(height*scale)]
    if min(size) < 1:
        raise ValueError("Scale collapsed source canvas")
    effective = [size[0]/width, size[1]/height]
    scaled_anchor = [mirror_anchor[0]*effective[0], mirror_anchor[1]*effective[1]]
    offset = [round(CENTER[0]-scaled_anchor[0]), round(CENTER[1]-scaled_anchor[1])]
    if offset[0] < 0 or offset[1] < 66 or offset[0]+size[0] > PANEL[0] or offset[1]+size[1] > 297:
        raise ValueError("Scaled canvas would overlap labels or be cropped; enlarge the panel explicitly")
    # At non-integer scales, nearest sampling and reflection do not commute.
    # Reflect the already sampled sprite so board SW/NW are pixel-exact mirrors
    # of board SE/NE, with no alternating source-column sampling phase.
    image = source.resize(tuple(size), Image.Resampling.NEAREST)
    if mirrored:
        image = ImageOps.mirror(image)
    panel = board_background(role, direction, at)
    panel.alpha_composite(image, tuple(offset))
    meta = {"source_canvas": [width, height], "source_anchor": list(anchor),
            "mirrored": mirrored, "mirror_anchor_continuous_edge": mirror_anchor,
            "requested_scale": scale, "effective_scale": effective,
            "resized_canvas": size, "resized_anchor": scaled_anchor,
            "board_sampling_order": "nearest resize, then horizontal reflection if mirrored",
            "raster_offset": offset, "grid_center": list(CENTER),
            "placed_anchor": [offset[i]+scaled_anchor[i] for i in range(2)],
            "anchor_rounding_error_px": [offset[i]+scaled_anchor[i]-CENTER[i] for i in range(2)]}
    return panel.convert("RGB"), meta


def pending_panel(role: str, direction: str) -> Image.Image:
    image = board_background(role, direction)
    ImageDraw.Draw(image).text((77, 143), "源方向待交付", font=FONT, fill=TEXT)
    return image.convert("RGB")


def save_png(path: Path, image: Image.Image) -> dict:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    return {"file": relative(path), "sha256": sha(path.read_bytes()), "size": list(image.size)}


def palette_colors(sources: dict) -> list:
    colors = []
    for source in sources.values():
        if source:
            colors.extend(tuple(rgb) for rgb in source["manifest"]["body_palette_rgb"])
    return colors + [BG, GRID, FILL, TEXT, SUBTEXT, (65, 83, 82), (181, 176, 126)]


def save_gif(path: Path, images: list, timing: dict, colors: list) -> dict:
    palette = shared.GifPalette(colors, BG, images)
    data, info = shared.gif_bytes(images, timing, palette)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return {"file": relative(path), "size": list(images[0].size), **info}


def mirror_pair(source: Image.Image, role: str, direction: str) -> Image.Image:
    result = Image.new("RGBA", (896, 480), (*BG, 255))
    result.alpha_composite(source, (0, 32))
    result.alpha_composite(ImageOps.mirror(source), (448, 32))
    draw = ImageDraw.Draw(result)
    mirror = "sw" if direction == "se" else "nw"
    status = DIRECTION_STATUS.get((role,direction),"under_review")
    draw.text((12,7),f"{dict(ROLES)[role]} {direction.upper()}源 · {gate_text(status)}",font=SMALL,fill=TEXT)
    draw.text((460,7),f"{mirror.upper()}镜像 · {gate_text(status)}",font=SMALL,fill=TEXT)
    return result.convert("RGB")


def union_timing(sources: dict, factor: int) -> tuple:
    available = [source for source in sources.values() if source]
    if not available:
        return None, None
    per_source = {}
    boundaries = {0}
    for direction, source in sources.items():
        if not source:
            continue
        m = source["manifest"]
        timing = shared.gif_timing(m["track"], m["duration_ms"], m["idle_ms"], m.get("events", []), factor)
        per_source[direction] = timing
        boundaries.update(timing["stage_starts_gif_ms"])
        boundaries.add(shared.tick(m["duration_ms"]*factor))
        boundaries.add(timing["total_ms"])
    period = max(x["total_ms"] for x in per_source.values())
    times = sorted(t for t in boundaries if t <= period)
    intervals = [b-a for a,b in zip(times, times[1:])]
    if not intervals or not all(x > 0 for x in intervals):
        raise ValueError("Invalid composite time union")
    timing = {"durations_ms": intervals, "total_ms": period, "slow_factor": factor,
              "stage_starts_gif_ms": times[:-1], "union_boundaries_ms": times,
              "alignment": "common absolute time; hold shorter final stage until longest cycle ends",
              "source_cycles_ms": {k:v["total_ms"] for k,v in per_source.items()}}
    return timing, per_source


def local_refs(html: str, pending: tuple = ()) -> list:
    class References(HTMLParser):
        def __init__(self):
            super().__init__(); self.items = []
        def handle_starttag(self, tag, attrs):
            for key, value in attrs:
                if key in ("src", "href") and value and not value.startswith("#"):
                    self.items.append(value)
    parser = References(); parser.feed(html)
    for name in parser.items:
        path = (ROOT / name).resolve()
        if not path.is_relative_to(ROOT) or (not path.is_file() and name not in pending):
            raise ValueError(f"Broken/local-escape HTML reference: {name}")
    return parser.items


CSS = """*{box-sizing:border-box}body{margin:0;background:#161d25;color:#f2e8d3;font:16px -apple-system,BlinkMacSystemFont,sans-serif}header,main{max-width:1390px;margin:auto;padding:24px}h1{font-size:30px}h2{font-size:25px;margin:0 0 10px}h3{font-size:20px}p{line-height:1.7;color:#c1c9c7}a{color:#edcf85;text-underline-offset:4px}.role{background:#202a32;padding:20px;margin:22px 0;border:1px solid #56635e;border-radius:12px}.status{color:#ffd493}.scroll{overflow:auto;max-width:100%;padding-bottom:8px}img{display:block;image-rendering:pixelated;max-width:none}figure{margin:0}figcaption{padding:8px 0;color:#c9c4b4;font-size:14px}.sources{display:flex;gap:18px;flex-wrap:wrap}.source img{width:448px;height:448px}.stage-grid{display:flex;flex-wrap:wrap;gap:12px}.stage-grid figure{border:1px solid #55605b;padding:4px;width:330px}.stage-grid img{width:320px;height:320px}summary{cursor:pointer;color:#efd291;margin:16px 0}.note{font-size:14px;color:#aebdbb}.warning{border:1px solid #bc965d;padding:14px;background:#352f26}nav{display:flex;gap:20px}footer{padding:24px;color:#9eb0b0}@media(max-width:500px){header,main{padding:12px}.role{padding:12px}}"""


def main():
    global FONT, SMALL, PARENT_STATUS, DIRECTION_STATUS, ROLE_STATUS, STATUS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--monk-scale", type=float, default=.5)
    parser.add_argument("--wolf-scale", type=float, default=.5)
    parser.add_argument("--font", help="Installed Chinese-capable font for PNG labels; never downloaded or bundled")
    args = parser.parse_args()
    FONT, SMALL, font_path = fonts(args.font)
    scales = {"monk": args.monk_scale, "wolf": args.wolf_scale}
    # Actual anchors are centered, so exercise this function on an asymmetric
    # source to make a W-1-x bug observable before publishing any derived files.
    fixture = Image.new("RGBA", (13, 7))
    fixture.putpixel((2, 4), (13, 99, 200, 255))
    _, probe = place_board(fixture, [2.5, 4.5], 1, True, "monk", "sw")
    if probe["mirror_anchor_continuous_edge"] != [10.5, 4.5]:
        raise ValueError("Continuous-edge mirror anchor self-check failed")
    snapshots, report, html_roles = {}, [], []
    all_sources = {role:{direction:load_direction(role,direction,snapshots) for direction in ("se","ne")} for role,_ in ROLES}
    PARENT_STATUS,DIRECTION_STATUS,ROLE_STATUS,STATUS,evidence = load_parent_gates(all_sources,snapshots)
    overview = Image.new("RGB", (PANEL[0]*4, PANEL[1]*2), BG)
    contact = Image.new("RGB", overview.size, BG)
    for row, (role, title) in enumerate(ROLES):
        sources = all_sources[role]
        record = {"id": role, "title": title, "status": ROLE_STATUS[role], "display_scale": scales[role],
                  "source_directions": {}, "board_gifs": {}, "source_snapshot_stable": None}
        sections, board_frames = [], {}
        for direction in ("se", "ne"):
            source = sources[direction]
            if source is None:
                record["source_directions"][direction] = {"status": "under_review", "available": False}
                sections.append(f'<h3>{direction.upper()} 源方向</h3><p>待交付 · under_review。镜像方向同样待交付。</p>')
                continue
            m = source["manifest"]
            mirror_direction = "sw" if direction == "se" else "nw"
            stage_report = []
            for index, (stage, image) in enumerate(zip(m["renders"], source["images"])):
                item = {"index": index, "at_ms": stage["at_ms"], "body": stage["body"],
                        "source_file": relative(source["folder"]/stage["file"]), "board": {}}
                for target in (direction, mirror_direction):
                    board, placement = place_board(image, m["anchor"], scales[role], MIRRORED[target], role, target, stage["at_ms"])
                    file = OUTPUT / f"{role}-{target}-stage-{index:03}.png"
                    item["board"][target] = {**save_png(file, board), "placement": placement}
                    board_frames[(target,index)] = board
                stage_report.append(item)
            colors = palette_colors({direction: source})
            mirror_gifs = {}
            pair_images = [mirror_pair(image, role, direction) for image in source["images"]]
            for name, factor in (("normal",1),("slow",2)):
                timing = shared.gif_timing(m["track"], m["duration_ms"], m["idle_ms"], m.get("events",[]), factor)
                mirror_gifs[name] = save_gif(OUTPUT/f"{role}-{direction}-mirror-{name}.gif", pair_images, timing, colors)
            event = next((x for x in m.get("events",[]) if any(word in x["name"].lower() for word in ("contact","impact","hit"))), None)
            selected = max(0, bisect_right([x["at_ms"] for x in m["track"]], event["at_ms"])-1) if event else len(m["track"])//2
            direction_status = DIRECTION_STATUS[(role,direction)]
            direction_report = {"status": direction_status, "available": True, "manifest": relative(source["folder"]/"manifest.json"),
                                "manifest_sha256": source["manifest_sha256"], "canvas": m["canvas"], "anchor": m["anchor"],
                                "real_body_count": len(m["bodies"]), "display_stage_count": len(m["renders"]),
                                "action_duration_ms": m["duration_ms"], "idle_ms": m["idle_ms"],
                                "source_previews": source["previews"], "mirror_gifs": mirror_gifs,
                                "contact_selection": {"stage": selected,"policy":"event stage" if event else "middle stage; no contact event declared"},
                                "docs": source["docs"], "stages": stage_report}
            record["source_directions"][direction] = direction_report
            for target in (direction, mirror_direction):
                col = DIRECTIONS.index(target)
                overview.paste(board_frames[(target,0)], (col*PANEL[0], row*PANEL[1]))
                contact.paste(board_frames[(target,selected)], (col*PANEL[0], row*PANEL[1]))
            prefix = f"{role}/{direction}"
            normal = source["previews"]["preview.gif"]["total_ms"]
            slow = source["previews"]["preview_slow.gif"]["total_ms"]
            docs = "　".join(f'<a href="{escape(path)}">{escape(name)}</a>' if path else f'{escape(name)} 待交付' for name,path in source["docs"].items())
            stages = []
            for item in stage_report:
                for target, board in item["board"].items():
                    stages.append(f'<figure><a href="{board["file"]}"><img loading="lazy" src="{board["file"]}" width="320" height="320" alt="{title} {target.upper()} 第{item["index"]+1}显示阶段"></a><figcaption>{target.upper()} · 第{item["index"]+1}阶段 · {item["at_ms"]}ms · <a href="{item["source_file"]}">源 PNG</a></figcaption></figure>')
            sections.append(f'<h3>{direction.upper()} 源方向 / {mirror_direction.upper()} 镜像 · {gate_text(direction_status)}</h3><p>{len(m["bodies"])}真实身体 / {len(m["renders"])}显示阶段 · {docs}</p><div class="sources"><figure class="source"><div class="scroll"><img src="{prefix}/preview.gif" width="448" height="448" alt="{title} {direction} 正常"></div><figcaption>源方向正常 · {normal}ms · 原始 448×448</figcaption></figure><figure class="source"><div class="scroll"><img src="{prefix}/preview_slow.gif" width="448" height="448" alt="{title} {direction} 半速"></div><figcaption>源方向半速 · {slow}ms · 原始 448×448</figcaption></figure></div><div class="scroll"><img loading="lazy" src="{mirror_gifs["normal"]["file"]}" width="896" height="480" alt="{title} {direction}/{mirror_direction} 正常镜像对照"></div><p class="note">源方向与镜像正常对照 · {normal}ms</p><div class="scroll"><img loading="lazy" src="{mirror_gifs["slow"]["file"]}" width="896" height="480" alt="{title} {direction}/{mirror_direction} 半速镜像对照"></div><p class="note">半速对照 · {slow}ms。镜像只做水平反转，anchor 使用连续边界 W−x。</p><details><summary>全部 {len(stage_report)} 显示阶段 × 2 方向棋盘图</summary><div class="stage-grid">{"".join(stages)}</div></details>')
        for target in DIRECTIONS:
            if sources[SOURCE_DIRECTION[target]] is None:
                col = DIRECTIONS.index(target)
                placeholder = pending_panel(role,target)
                overview.paste(placeholder,(col*PANEL[0],row*PANEL[1]))
                contact.paste(placeholder,(col*PANEL[0],row*PANEL[1]))
        for name,factor in (("normal",1),("slow",2)):
            timing, per_source = union_timing(sources,factor)
            if timing is None:
                continue
            images = []
            indices = []
            for at in timing["stage_starts_gif_ms"]:
                strip = Image.new("RGB", (PANEL[0]*4,PANEL[1]), BG)
                source_indices = {}
                for col,target in enumerate(DIRECTIONS):
                    direction = SOURCE_DIRECTION[target]
                    source = sources[direction]
                    if source is None:
                        panel = pending_panel(role,target)
                    else:
                        index = max(0,bisect_right(per_source[direction]["stage_starts_gif_ms"],at)-1)
                        source_indices[direction] = index
                        # Static native stage pixels, including its action timestamp.
                        panel = board_frames[(target,index)]
                    strip.paste(panel,(col*PANEL[0],0))
                images.append(strip);indices.append(source_indices)
            gif = save_gif(OUTPUT/f"{role}-board-{name}.gif",images,timing,palette_colors(sources))
            record["board_gifs"][name] = {**gif,"source_stage_indices":indices}
        maximum_stages = max((len(source["images"]) for source in sources.values() if source), default=0)
        stage_sheet_link = ""
        if maximum_stages:
            sheet = Image.new("RGB", (PANEL[0]*4,PANEL[1]*maximum_stages), BG)
            for index in range(maximum_stages):
                for col,target in enumerate(DIRECTIONS):
                    panel = board_frames.get((target,index))
                    if panel is None:
                        panel = pending_panel(role,target)
                    sheet.paste(panel,(col*PANEL[0],index*PANEL[1]))
            record["all_stage_board_sheet"] = save_png(OUTPUT/f"{role}-all-stages.png",sheet)
            record["all_stage_board_sheet"]["row_policy"] = "display-stage index, not synchronized time; per-panel action timestamps retained"
            stage_sheet_link = f'<p><a href="{record["all_stage_board_sheet"]["file"]}">全部显示阶段的四方向棋盘接触表</a>（逐显示阶段编号排列；各方向时间看格内标签）。</p>'
        boards = "".join(f'<div class="scroll"><img src="{gif["file"]}" width="1280" height="320" alt="{title} 四方向棋盘 {name}"></div><p class="note">{"正常" if name=="normal" else "半速"} · {gif["total_ms"]}ms · SE / SW / NE / NW</p>' for name,gif in record["board_gifs"].items())
        if not boards:
            boards = '<p>棋盘动图等待源方向交付。</p>'
        role_label = gate_text("limited_offline_pass" if ROLE_STATUS[role] == "reviewed_candidate" else "under_review")
        package_link = f'<p><a href="{role}/README.md">角色包说明</a></p>' if (ROOT/role/"README.md").is_file() else ""
        if role in evidence:
            package_link += f'<p><a href="{evidence[role]["file"]}">根任务保存的独立视觉结论</a></p>'
        html_roles.append(f'<section class="role" id="{role}"><h2>{title}</h2><p class="status">{role_label} · 固定角色展示比例 {scales[role]:g}</p>{package_link}<h3>原像素棋盘 · 四方向</h3>{boards}{stage_sheet_link}{"".join(sections)}</section>')
        report.append(record)
    overview_meta = save_png(ROOT/"overview.png",overview)
    contact_meta = save_png(ROOT/"contact_sheet.png",contact)
    overall_label = gate_text("limited_offline_pass") if STATUS == "reviewed_candidate" else "本批整体 under_review · 各角色与方向状态见下方"
    status_link = '<a href="STATUS.json">当前复核状态</a>' if (ROOT/"STATUS.json").is_file() else ""
    html = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>斜向像素攻击 · 候选审阅</title><style>'+CSS+'</style><header><h1>斜向像素攻击 · 候选审阅</h1><p class="warning">'+overall_label+'。离线复核不能替代负责人真人连续观感和游戏内验收；状态只读取根任务记录。</p><p>每格为原像素 192×96 菱形；图像以固定角色比例放置，脚锚对齐格心。原像素预览在窄窗口横向滚动，不自动缩小。格心标记只证明 anchor 的位置；足底接触与格内占地仍需逐帧视觉判断。<br>慢速只将动作段时间乘二，空闲停留不变。不同源方向以共同绝对时间对齐；较短周期停在末尾姿势直到最长周期结束。</p><nav><a href="#monk">护寺棍僧</a><a href="#wolf">山狼</a><a href="README.md">本批说明</a>'+status_link+'<a href="delivery_audit.json">交付检查</a><a href="contact_sheet.png">接触姿势总览</a></nav><div class="scroll"><img src="overview.png" width="1280" height="640" alt="两角色四方向待机棋盘总览"></div></header><main>'+''.join(html_roles)+'</main><footer>'+date.today().isoformat()+' · 静态文件与媒体检查；未做浏览器交互、真人连续观看或运行验收。</footer></html>'
    refs = local_refs(html, ("delivery_audit.json",))
    # Reject a mixed generation if an author rewrote any input during this build.
    changed = [path for path,digest in snapshots.items() if not Path(path).is_file() or sha(Path(path).read_bytes()) != digest]
    if changed:
        raise ValueError("Source changed during packing; rebuild after author finishes: "+", ".join(changed))
    for role in report:
        role["source_snapshot_stable"] = True
    audit = {"schema":"diagonal-attack-review-v1","updated":date.today().isoformat(),"status":STATUS,
             "visual_acceptance_awarded":False,"runtime_integrated":False,"role_count":len(ROLES),
             "visual_status_authority":"parent-maintained STATUS.json; packager never awards a visual pass",
             "parent_visual_review_status":PARENT_STATUS.get("visual_review",{}).get("status","under_review"),
             "parent_status_file":"STATUS.json" if (ROOT/"STATUS.json").is_file() else None,
             "inherited_visual_evidence":evidence,
             "label_font":{"path":str(font_path),"sha256":sha(font_path.read_bytes()),"sizes_px":[18,13],
                           "font_not_bundled":True},
             "available_source_direction_count":sum(bool(s) for sources in all_sources.values() for s in sources.values()),
             "expected_source_direction_count":4,"source_direction_names":["se","ne"],"derived_direction_names":["sw","nw"],
             "grid":{"width":192,"height":96,"center":list(CENTER),"panel":list(PANEL),"one_design_pixel_per_output_pixel":True,
                     "vertices_relative":[[0,-48],[96,0],[0,48],[-96,0]],"inner_guide_fraction":.9,
                     "anchor_placement_is_not_footprint_acceptance":True},
             "mirror_policy":"Full-size GIF: RGBA horizontal reflection. Board: fixed nearest resize then horizontal reflection; continuous-edge anchor x'=W-x; no per-frame fitting",
             "asymmetric_mirror_registration_probe":probe,
             "source_snapshot_stable":True,"source_snapshots":{relative(Path(p)):h for p,h in snapshots.items()},
             "local_html_reference_count":len(refs),"all_local_html_references_exist":True,
             "browser_verification":"not performed; static files only; local file preview policy is not bypassed",
             "overview":overview_meta,"contact_sheet":contact_meta,"roles":report}
    # Publish the HTML only after every source snapshot check passes.
    (ROOT/"review.html").write_text(html,encoding="utf-8")
    (ROOT/"delivery_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    local_refs(html)
    print(json.dumps({"available_directions":audit["available_source_direction_count"],"status":STATUS,
                      "stage_count":sum(d.get("display_stage_count",0) for r in report for d in r["source_directions"].values()),
                      "html_references":len(refs),"source_snapshot_stable":True},ensure_ascii=False))


if __name__ == "__main__":
    main()
