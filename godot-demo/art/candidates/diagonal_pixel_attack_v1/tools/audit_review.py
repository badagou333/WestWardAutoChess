#!/usr/bin/env python3
"""Independently check source/derived pixels, GIF time and local review links.

Does not import the packager or the old animation builder.  This is an integrity
audit, not a claim of visual acceptance, continuous human viewing or runtime use.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from html.parser import HTMLParser
from io import BytesIO
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote,urlsplit

import numpy as np
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parent.parent
BG = (28, 35, 43)
GUIDES = [BG, (109,119,118), (42,56,57), (231,218,187),
          (166,181,187), (65,83,82), (181,176,126)]
DIRECTIONS = ("se","sw","ne","nw")
FROM = {"se":"se","sw":"se","ne":"ne","nw":"ne"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def resolve(name):
    path = (ROOT/name).resolve()
    assert path.is_relative_to(ROOT) and path.is_file(), name
    return path


def raster(name):
    with Image.open(resolve(name)) as image:
        image.load()
        return image.convert("RGBA").copy()


def check_file(record):
    path = resolve(record["file"])
    assert sha(path.read_bytes()) == record["sha256"], record["file"]
    with Image.open(path) as image:
        image.load()
        assert list(image.size) == record["size"], record["file"]


def decode_gif(path):
    images, durations = [], []
    with Image.open(path) as image:
        assert image.format == "GIF"
        for index in range(image.n_frames):
            image.seek(index)
            images.append(np.asarray(image.convert("RGB")).copy())
            durations.append(int(image.info.get("duration",0)))
    assert durations and all(t > 0 for t in durations)
    return images, durations, np.cumsum(durations).tolist()


def tick(value):
    return int((value+5)//10)*10


def expected_time(manifest,factor):
    starts = [tick(x["at_ms"]*factor) for x in manifest["track"]]
    end = tick(manifest["duration_ms"]*factor+manifest["idle_ms"])
    assert starts == sorted(set(starts)) and starts[0] == 0 and starts[-1] < end
    return starts,end


def at_frame(decoded, ends, at):
    return decoded[bisect_right(ends,at)]


def rgba_on_bg(image):
    base = Image.new("RGBA",image.size,(*BG,255))
    base.alpha_composite(image)
    return np.asarray(base.convert("RGB"))


def background():
    # Draw independently from fixed published 192×96 geometry, no renderer import.
    image = Image.new("RGBA",(320,320),(*BG,255))
    draw = ImageDraw.Draw(image)
    draw.polygon([(160,190),(256,238),(160,286),(64,238)],
                 fill=(42,56,57,255),outline=(109,119,118,255))
    draw.line([(160,194.8),(246.4,238),(160,281.2),(73.6,238),(160,194.8)],
              fill=(65,83,82,255),width=1)
    draw.line((156,238,164,238),fill=(181,176,126,255))
    draw.line((160,234,160,242),fill=(181,176,126,255))
    return image


def codes(image):
    image = image.astype(np.uint32)
    return (image[:,:,0]<<16)|(image[:,:,1]<<8)|image[:,:,2]


def exact_reserved(wanted, actual, colors):
    values = [(r<<16)|(g<<8)|b for r,g,b in colors]
    mask = np.isin(codes(wanted),values)
    assert np.array_equal(actual[mask],wanted[mask]), "GIF changed a reserved body/grid RGB"
    error = int(np.abs(actual[~mask].astype(int)-wanted[~mask].astype(int)).max()) if (~mask).any() else 0
    return int(mask.sum()),error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",default="tools/review_integrity.json")
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.is_relative_to(ROOT/"tools"), "Audit writes are restricted to this batch tools/"
    audit = json.loads((ROOT/"delivery_audit.json").read_text())
    parent = json.loads((ROOT/"STATUS.json").read_text()) if (ROOT/"STATUS.json").is_file() else {}
    assert not audit["visual_acceptance_awarded"]
    def expected_direction(role,direction,available):
        entry = parent.get("characters",{}).get(role,{})
        return "limited_offline_pass" if (available and entry.get("status") == "reviewed_candidate"
             and entry.get("visual_review") == "limited_offline_pass"
             and entry.get("directions",{}).get(direction) == "limited_offline_pass") else "under_review"
    expected_roles = {role["id"]:("reviewed_candidate" if all(expected_direction(role["id"],d,role["source_directions"][d]["available"]) == "limited_offline_pass" for d in ("se","ne")) else "under_review") for role in audit["roles"]}
    expected_overall = "reviewed_candidate" if (parent.get("overall_status") == "reviewed_candidate"
          and parent.get("visual_review",{}).get("status") == "limited_offline_pass"
          and all(value == "reviewed_candidate" for value in expected_roles.values())) else "under_review"
    assert audit["status"] == expected_overall
    assert audit["parent_visual_review_status"] == parent.get("visual_review",{}).get("status","under_review")
    assert audit["grid"]["width"] == 192 and audit["grid"]["height"] == 96
    assert audit["grid"]["center"] == [160,238] and audit["grid"]["panel"] == [320,320]
    for name,digest in audit["source_snapshots"].items():
        assert sha(resolve(name).read_bytes()) == digest, f"Input changed after build: {name}"
    # Real sources happen to have a centered anchor.  This asymmetric fixture
    # catches confusing a pixel-index mirror (W-1-x) with a continuous-edge anchor.
    fixture = Image.new("RGBA",(13,7)); fixture.putpixel((2,4),(13,99,200,255))
    reflected = ImageOps.mirror(fixture)
    assert reflected.getpixel((10,4)) == fixture.getpixel((2,4))
    fixture_anchor = (2.5,4.5)
    assert (13-fixture_anchor[0],fixture_anchor[1]) == (10.5,4.5)
    probe = audit["asymmetric_mirror_registration_probe"]
    assert probe["source_canvas"] == [13,7] and probe["source_anchor"] == [2.5,4.5]
    assert probe["mirrored"] and probe["mirror_anchor_continuous_edge"] == [10.5,4.5]
    assert probe["resized_anchor"] == [10.5,4.5]
    assert probe["raster_offset"] == [150,234]
    assert probe["placed_anchor"] == [160.5,238.5]
    counters = {"available_source_directions":0,"real_bodies":0,"display_stages":0,
                "board_stage_pngs":0,"source_gifs":0,"derived_gifs":0,
                "checked_reserved_gif_pixels":0,"maximum_unreserved_fx_or_text_channel_error":0}
    role_reports = []
    observed_sources = {}
    board_lookup = {}
    for role in audit["roles"]:
        role_id = role["id"]
        assert role["status"] == expected_roles[role_id]
        source_data = {}
        colors = list(GUIDES)
        direction_reports = {}
        for direction in ("se","ne"):
            record = role["source_directions"][direction]
            assert record["status"] == expected_direction(role_id,direction,record["available"])
            if not record["available"]:
                direction_reports[direction] = {"available":False,"status":"under_review"}
                continue
            counters["available_source_directions"] += 1
            path = resolve(record["manifest"])
            raw = path.read_bytes()
            assert sha(raw) == record["manifest_sha256"]
            m = json.loads(raw)
            assert m["canvas"] == [448,448] and m["anchor"] == [224,344]
            assert len(m["renders"]) == len(record["stages"]) == len(m["track"])
            counters["real_bodies"] += len(m["bodies"])
            counters["display_stages"] += len(m["renders"])
            colors.extend(tuple(rgb) for rgb in m["body_palette_rgb"])
            folder = path.parent
            source_images = []
            for body in m["bodies"]:
                data = (folder/body["file"]).read_bytes()
                assert sha(data) == body["sha256"]
                with Image.open(BytesIO(data)) as image:
                    image.load()
                    assert image.size == (448,448)
                    if body.get("rgba_pixel_sha256"):
                        assert sha(image.convert("RGBA").tobytes()) == body["rgba_pixel_sha256"]
            for index,(entry,stage,track) in enumerate(zip(m["renders"],record["stages"],m["track"])):
                data = (folder/entry["file"]).read_bytes()
                assert sha(data) == entry["sha256"]
                source = Image.open(BytesIO(data)).convert("RGBA")
                source_images.append(source)
                assert stage["at_ms"] == track["at_ms"] == entry["at_ms"]
                assert stage["body"] == entry["body"] == track["body"]
                assert resolve(stage["source_file"]) == (folder/entry["file"]).resolve()
                for target,board in stage["board"].items():
                    assert FROM[target] == direction
                    check_file(board)
                    actual = raster(board["file"])
                    p = board["placement"]
                    mirror = target in ("sw","nw")
                    assert p["mirrored"] == mirror
                    anchor = [448-m["anchor"][0],m["anchor"][1]] if mirror else m["anchor"]
                    assert p["mirror_anchor_continuous_edge"] == anchor
                    assert p["requested_scale"] == role["display_scale"]
                    size = (round(448*role["display_scale"]),)*2
                    scaled = [anchor[0]*size[0]/448,anchor[1]*size[1]/448]
                    offset = [round(160-scaled[0]),round(238-scaled[1])]
                    assert p["raster_offset"] == offset and p["resized_canvas"] == list(size)
                    assert p["resized_anchor"] == scaled
                    assert p["placed_anchor"] == [offset[0]+scaled[0],offset[1]+scaled[1]]
                    assert max(abs(p["placed_anchor"][i]-[160,238][i]) for i in (0,1)) <= .5
                    assert p["board_sampling_order"] == "nearest resize, then horizontal reflection if mirrored"
                    resized = source.resize(size,Image.Resampling.NEAREST)
                    if mirror:resized = ImageOps.mirror(resized)
                    wanted = background();wanted.alpha_composite(resized,tuple(offset))
                    # Body rectangle never overlaps labels for the current fixed scale.
                    box = (offset[0],offset[1],offset[0]+size[0],offset[1]+size[1])
                    assert box[0]>=0 and box[1]>=66 and box[2]<=320 and box[3]<=297
                    assert np.array_equal(np.asarray(actual.crop(box)),np.asarray(wanted.crop(box))), board["file"]
                    board_lookup[(role_id,target,index)] = actual.convert("RGB")
                    counters["board_stage_pngs"] += 1
            source_data[direction] = (m,source_images,record)
            for name,factor in (("preview.gif",1),("preview_slow.gif",2)):
                file = folder/name
                info = record["source_previews"][name]
                assert sha(file.read_bytes()) == info["sha256"] == m["previews"][name]["sha256"]
                decoded,durations,ends = decode_gif(file)
                starts,end = expected_time(m,factor)
                assert ends[-1] == end == info["total_ms"]
                assert len(decoded) == info["encoded_frames"] and durations == info["durations_ms"]
                for source,at in zip(source_images,starts):
                    wanted = np.asarray(source)
                    opaque = wanted[:,:,3] == 255
                    assert np.array_equal(at_frame(decoded,ends,at)[opaque],wanted[:,:,:3][opaque])
                counters["source_gifs"] += 1
            for name,factor in (("normal",1),("slow",2)):
                info = record["mirror_gifs"][name]
                check_file(info)
                decoded,durations,ends = decode_gif(resolve(info["file"]))
                starts,end = expected_time(m,factor)
                assert ends[-1] == end == info["total_ms"]
                for source,at in zip(source_images,starts):
                    actual = at_frame(decoded,ends,at)
                    normal = rgba_on_bg(source)
                    reflected = rgba_on_bg(ImageOps.mirror(source))
                    # Exclude only the 32px title strip; all original canvas pixels remain.
                    for wanted,half in ((normal,actual[32:,0:448]),(reflected,actual[32:,448:896])):
                        checked,error = exact_reserved(wanted,half,colors)
                        counters["checked_reserved_gif_pixels"] += checked
                        counters["maximum_unreserved_fx_or_text_channel_error"] = max(counters["maximum_unreserved_fx_or_text_channel_error"],error)
                    for original,half in ((source,actual[32:,0:448]),(ImageOps.mirror(source),actual[32:,448:896])):
                        values = np.asarray(original);opaque = values[:,:,3] == 255
                        assert np.array_equal(values[:,:,:3][opaque],half[opaque]), info["file"]
                counters["derived_gifs"] += 1
            direction_reports[direction] = {"available":True,"status":record["status"],
                                           "bodies":len(m["bodies"]),"stages":len(source_images),
                                           "source_gif_times":[record["source_previews"][x]["total_ms"] for x in ("preview.gif","preview_slow.gif")],
                                           "mirror_opaque_rgb_and_reserved_colors_exact":True,"board_actor_rectangle_rgba_exact":True}
        observed_sources[role_id] = source_data
        if source_data:
            sheet_record = role["all_stage_board_sheet"]
            check_file(sheet_record)
            sheet = raster(sheet_record["file"]).convert("RGB")
            count = max(len(value[1]) for value in source_data.values())
            assert sheet.size == (1280,320*count)
            for index in range(count):
                for column,target in enumerate(DIRECTIONS):
                    key = (role_id,target,index)
                    if key in board_lookup:
                        actual = sheet.crop((column*320,index*320,(column+1)*320,(index+1)*320))
                        assert np.array_equal(np.asarray(actual),np.asarray(board_lookup[key]))
        for name,factor in (("normal",1),("slow",2)):
            if name not in role["board_gifs"]:
                assert not source_data
                continue
            info = role["board_gifs"][name]
            check_file(info)
            decoded,durations,ends = decode_gif(resolve(info["file"]))
            boundaries = {0}
            source_times = {}
            for direction,(m,_,_) in source_data.items():
                starts,end = expected_time(m,factor)
                boundaries.update(starts);boundaries.update((tick(m["duration_ms"]*factor),end))
                source_times[direction] = (starts,end)
            times = sorted(boundaries)
            assert ends[-1] == times[-1] == info["total_ms"]
            assert info["union_boundaries_ms"] == times
            assert info["durations_ms"] == [b-a for a,b in zip(times,times[1:])]
            for index,at in enumerate(times[:-1]):
                actual = at_frame(decoded,ends,at)
                for column,target in enumerate(DIRECTIONS):
                    direction = FROM[target]
                    if direction not in source_data:
                        continue
                    stage = bisect_right(source_times[direction][0],at)-1
                    assert info["source_stage_indices"][index][direction] == stage
                    wanted = np.asarray(board_lookup[(role_id,target,stage)])
                    actual_panel = actual[:,column*320:(column+1)*320]
                    checked,error = exact_reserved(wanted,actual_panel,colors)
                    counters["checked_reserved_gif_pixels"] += checked
                    counters["maximum_unreserved_fx_or_text_channel_error"] = max(counters["maximum_unreserved_fx_or_text_channel_error"],error)
            counters["derived_gifs"] += 1
        role_reports.append({"id":role_id,"status":role["status"],"directions":direction_reports})
    assert counters["available_source_directions"] == audit["available_source_direction_count"]
    for name,selection in (("overview",False),("contact_sheet",True)):
        info = audit[name];check_file(info)
        image = raster(info["file"]).convert("RGB")
        assert image.size == (1280,640)
        for row,role in enumerate(audit["roles"]):
            for column,target in enumerate(DIRECTIONS):
                record = role["source_directions"][FROM[target]]
                if not record["available"]:
                    continue
                stage = record["contact_selection"]["stage"] if selection else 0
                expected = board_lookup[(role["id"],target,stage)]
                assert np.array_equal(np.asarray(image.crop((column*320,row*320,(column+1)*320,(row+1)*320))),np.asarray(expected))
    class References(HTMLParser):
        def __init__(self):super().__init__();self.items=[]
        def handle_starttag(self,tag,attrs):
            for key,value in attrs:
                if key in ("src","href") and value and not value.startswith("#"):
                    self.items.append(value)
    refs = References();refs.feed((ROOT/"review.html").read_text())
    unique_media = set()
    for name in refs.items:
        path = resolve(name)
        if path.suffix.lower() in (".png",".gif",".webp"):
            unique_media.add(path)
            with Image.open(path) as image:
                for index in range(getattr(image,"n_frames",1)):
                    image.seek(index);image.load()
    assert len(refs.items) == audit["local_html_reference_count"]
    # Inspect only the parent and this batch's directly linked role documents.
    # Their baseline links may legitimately lead to a sibling candidate README.
    docs = [ROOT/"README.md"]
    docs.extend(ROOT/role/"README.md" for role in ("monk","wolf"))
    docs.extend(ROOT/role/direction/name for role in ("monk","wolf") for direction in ("se","ne") for name in ("README.md","REVIEW.md"))
    markdown_refs = []
    for doc in docs:
        if not doc.is_file():continue
        for target in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)',doc.read_text()):
            parsed = urlsplit(target)
            if parsed.scheme or not parsed.path:continue
            path = (doc.parent/unquote(parsed.path)).resolve()
            assert path.is_relative_to(ROOT.parent) and path.is_file(), f"Broken Markdown link {doc}: {target}"
            markdown_refs.append({"document":doc.relative_to(ROOT).as_posix(),"target":target})
    for role,entry in audit.get("inherited_visual_evidence",{}).items():
        path = resolve(entry["file"])
        assert sha(path.read_bytes()) == entry["sha256"]
        reviewed = json.loads(path.read_text())
        for direction,record in next(x for x in audit["roles"] if x["id"] == role)["source_directions"].items():
            if record["status"] != "limited_offline_pass":continue
            gate = reviewed["directions"][direction]
            assert gate["status"] == "limited_offline_pass"
            manifest = json.loads(resolve(record["manifest"]).read_text())
            for kind in ("bodies","renders"):
                if kind not in gate:continue
                assert len(gate[kind]) == len(manifest[kind])
                assert [(x["file"],x["sha256"]) for x in gate[kind]] == [(x["file"],x["sha256"]) for x in manifest[kind]]
    result = {"schema":"diagonal-review-independent-integrity-v1","integrity":"pass",
              "visual_status":audit["parent_visual_review_status"],"overall_status":audit["status"],"visual_acceptance_awarded":False,
              "visual_status_authority":"parent STATUS.json only",
              "audit_sha256":sha((ROOT/"delivery_audit.json").read_bytes()),
              "review_html_sha256":sha((ROOT/"review.html").read_bytes()),
              "source_snapshot_hashes_match":True,"continuous_edge_mirror_asymmetric_fixture_pass":True,
              "fixed_scale_and_anchor_registration_pass":True,"source_and_derived_gif_times_match":True,
              "overview_and_contact_match_complete_board_panels":True,
              "relative_reference_count":len(refs.items),"unique_html_media_decode_count":len(unique_media),
              "markdown_relative_reference_count":len(markdown_refs),"all_markdown_references_exist":True,
              "all_relative_references_exist":True,"browser_or_runtime_verified":False,
              "limits":"Static pixels, mirrors, timing and links. Inherits parent visual state; does not award a new visual pass. No human continuous playback, browser interaction or runtime test.",
              "counts":counters,"roles":role_reports}
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"integrity":"pass","visual_status":audit["parent_visual_review_status"],**counters,
                      "relative_references":len(refs.items),"unique_media":len(unique_media)}))


if __name__ == "__main__":
    main()
