#!/usr/bin/env python3
"""Artifact consistency audit, explicitly not independent visual acceptance."""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import types
import numpy as np
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parent

def digest(data):
    return hashlib.sha256(data).hexdigest()

def module(path, name):
    m = types.ModuleType(name)
    m.__file__ = str(path)
    exec(compile(path.read_text(),str(path),"exec"),m.__dict__)
    return m

def main():
    failures = []
    def check(ok, message):
        if not ok:
            failures.append(message)
    public = module(ROOT.parent / "tools/build_attack.py", "boar_public_audit")
    prep = module(ROOT / "prepare_fixed_stance.py", "boar_preparation_audit")
    spec = json.loads((ROOT / "spec.json").read_text())
    manifest = json.loads((ROOT / "manifest.json").read_text())
    provenance = json.loads((ROOT / "source/provenance.json").read_text())
    prepared, preparation, registered = prep.prepare()
    sheet = Image.new("RGBA",(1344,896))
    for i,body in enumerate(prepared):
        sheet.alpha_composite(body,((i%3)*448,(i//3)*448))
    check(sheet.tobytes()==Image.open(ROOT / "source/prepared_sheet.webp").convert("RGBA").tobytes(),"prepared sheet replay")
    source = provenance["source"]
    raw = ROOT / source["file"]
    check(digest(raw.read_bytes())==source["sha256"],"raw source hash")
    raw_decoded = Image.open(raw).convert("RGBA")
    check(digest(raw_decoded.tobytes())==source["rgba_pixel_sha256"],"raw source pixel hash")
    check(public.webp_is_lossless(raw.read_bytes()),"raw WebP lossless chunk")
    original = Path(provenance["iterations"][-1]["original_tool_png"])
    original_available = original.exists()
    original_exact = None
    if original_available:
        check(digest(original.read_bytes())==source["original_png_sha256"],"original PNG hash")
        original_exact = Image.open(original).convert("RGBA").tobytes()==raw_decoded.tobytes()
        check(original_exact,"all RGBA PNG/WebP equality")
    prompt_checks = []
    for entry in provenance["iterations"]:
        p = ROOT / entry["actual_prompt"]
        ok = p.exists() and digest(p.read_bytes())==entry["prompt_sha256"]
        check(ok,"actual prompt hash")
        prompt_checks.append(ok)
    ref = provenance["approved_reference"]
    check(digest((ROOT/ref["file"]).read_bytes())==ref["sha256"],"approved reference hash")
    assets = public.build_assets(spec,ROOT)
    color_set = set()
    bodies = []
    records = []
    for expected, record in zip(assets["bodies"],manifest["bodies"]):
        p = ROOT / record["file"]
        actual = Image.open(p).convert("RGBA")
        a = np.asarray(actual)
        check(actual.size==(448,448),"body size")
        check(actual.tobytes()==expected.tobytes(),"body replay "+record["id"])
        check(digest(p.read_bytes())==record["sha256"],"body byte hash "+record["id"])
        check(digest(actual.tobytes())==record["rgba_pixel_sha256"],"body pixel hash "+record["id"])
        check(set(np.unique(a[:,:,3]).tolist())<={0,255},"body binary alpha")
        check(np.all(a[a[:,:,3]==0]==0),"transparent RGBA zero")
        color_set.update(map(tuple,a[:,:,:3][a[:,:,3]==255].tolist()))
        selected,parts,_=public.component_union(a[:,:,3]==255,[[204,250]])
        check(np.array_equal(selected,a[:,:,3]==255),"disconnected opaque pixels "+record["id"])
        bounds = actual.getbbox()
        margin = min(bounds[0],bounds[1],448-bounds[2],448-bounds[3])
        check(margin>=5,"body margin "+record["id"])
        records.append({"id":record["id"],"bbox":list(bounds),"minimum_margin_px":margin,
                        "opaque_components_from_torso_seed":len(parts),"sha256":record["sha256"]})
        bodies.append(actual)
    check(len(color_set)<=96,"shared palette cap")
    atlas = Image.open(ROOT / "atlas.png").convert("RGBA")
    for i,body in enumerate(bodies):
        check(atlas.crop((448*i,0,448*(i+1),448)).tobytes()==body.tobytes(),"atlas "+str(i))
    contact = public.make_sheet(assets["renders"],assets["track"],tuple(spec["background"]),assets["anchor"])
    check(contact.convert("RGBA").tobytes()==Image.open(ROOT / "contact_sheet.png").convert("RGBA").tobytes(),"contact sheet replay")
    check(assets["renders"][0].tobytes()==assets["renders"][-1].tobytes(),"first/last exact RGBA")
    rgb = [public.rgb_stage(image,tuple(spec["background"])) for image in assets["renders"]]
    palette = public.GifPalette(assets["body_palette"],tuple(spec["background"]),rgb)
    previews = {}
    for name,factor,total in [("preview.gif",1,1400),("preview_slow.gif",2,2450)]:
        path = ROOT/name
        timing = public.gif_timing(assets["track"],assets["duration_ms"],assets["idle_ms"],assets["events"],factor)
        rebuilt,_=public.gif_bytes(rgb,timing,palette)
        check(path.read_bytes()==rebuilt,"GIF byte replay "+name)
        frames = []
        durations = []
        with Image.open(path) as gif:
            for frame in ImageSequence.Iterator(gif):
                frames.append(frame.convert("RGB").copy())
                durations.append(frame.info.get("duration",0))
        check(len(frames)==7,"GIF frame count "+name)
        check(sum(durations)==total,"GIF duration "+name)
        max_error = 0
        for index,(actual,expected) in enumerate(zip(frames,rgb)):
            error = int(np.abs(np.asarray(actual).astype(int)-np.asarray(expected).astype(int)).max())
            max_error = max(max_error,error)
            check(error==0,"GIF RGB error "+name+" stage "+str(index))
        check(frames[0].tobytes()==frames[-1].tobytes(),"GIF first/last "+name)
        previews[name]={"fully_decoded_frames":len(frames),"durations_ms":durations,
                        "total_ms":sum(durations),"maximum_rgb_channel_error":max_error,
                        "public_replay_byte_identical":path.read_bytes()==rebuilt,
                        "sha256":digest(path.read_bytes())}
    feet=[]
    for i,body in enumerate(bodies):
        a=np.asarray(body)
        foot = a[389:401,100:325]
        sole_equal = np.array_equal(foot,np.asarray(bodies[0])[389:401,100:325])
        check(sole_equal,"hoof sole pixels "+str(i))
        top_alpha_unchanged = np.array_equal(np.asarray(prepared[i])[:293,:,3],np.asarray(registered[i])[:293,:,3])
        check(top_alpha_unchanged,"prepared upper-body alpha untouched "+str(i))
        feet.append({"id":str(i),"sole_roi_equal_ready":sole_equal,"prepared_y_lt_293_alpha_equal_registered":top_alpha_unchanged})
    wrist_path = ROOT / "source/wrist_patch_spec.json"
    wrist_checks = None
    if wrist_path.exists():
        policy = json.loads(wrist_path.read_text())
        original_path = ROOT / policy["baseline_body3_file"]
        original = Image.open(original_path).convert("RGBA")
        check(digest(original_path.read_bytes())==policy["baseline_body3_sha256"],"wrist baseline witness hash")
        mask = prep.wrist_allowed_mask(policy,original)
        current = np.asarray(bodies[3])
        check(np.array_equal(current[~mask],np.asarray(original)[~mask]),"wrist outside mask RGBA")
        check(np.array_equal(current[:,:,3],np.asarray(original)[:,:,3]),"wrist alpha unchanged")
        for i,body in enumerate(bodies):
            if i!=3:
                check(digest(body.tobytes())==policy["before_body_pixel_hashes"][str(i)],"unchanged accepted body "+str(i))
        wrist_checks = preparation["wrist_patch"]
    for event in manifest["events"]:
        check(event["gameplay_binding"] is False,"event game binding")
    check((ROOT/".gdignore").exists(),"Godot ignore")
    result={"date":"2026-10-26","author":"pixel_asset_integrity / boar author",
            "result":"author_technical_pass_requires_independent_visual_gate" if not failures else "failed",
            "raw_png_available_during_audit":original_available,"raw_png_webp_all_rgba_equal":original_exact,
            "all_actual_prompt_hashes_match":all(prompt_checks),"shared_opaque_colors":len(color_set),
            "prepared_sheet_replay_equal":True,"public_builder_replay_equal":True,
            "body_records":records,"previews":previews,"stance_checks":feet,"wrist_patch":wrist_checks,
            "source_png_sha256":source["original_png_sha256"],"source_webp_sha256":source["sha256"],
            "source_rgba_pixel_sha256":source["rgba_pixel_sha256"],
            "public_builder_sha256":digest((ROOT.parent/"tools/build_attack.py").read_bytes()),
            "contact_ms":440,"slow_contact_ms":880,"event_preview_metadata_only":True,
            "failures":failures,"not_verified":["independent pose/adjacent-animation acceptance","owner approval",
                "human continuous playback","runtime integration","damage binding"]}
    (ROOT/"validation_author.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"result":result["result"],"failures":failures,"colors":len(color_set),"previews":previews},ensure_ascii=False))
    if failures:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
