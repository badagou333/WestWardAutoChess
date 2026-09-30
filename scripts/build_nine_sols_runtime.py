"""Deterministic runtime packing only. Never redraws source concept art.

Manual per-pose extraction/ground anchors are recorded in each manifest.
Run with the bundled Python (Pillow); --review writes a temporary contact sheet.
"""
from pathlib import Path
import json
import hashlib
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "godot-demo"
SOURCES = {
    "guard_monk": "guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png",
    "wild_hunter": "wild_hunter/nine_sols_archer_v1/wild-hunter-archer-candidate.png",
    "herbal_spirit_child": "herbal_spirit_child/nine_sols_v1/herbal-child-nine-sols-candidate.png",
    "sparrow_spirit": "sparrow_spirit/nine_sols_v1/sparrow-nine-sols-candidate.png",
    "foxfire_imp": "foxfire_imp/nine_sols_v1/foxfire-nine-sols-sample.png",
    "bear_lord": "bear_lord/nine_sols_v1/bear-lord-nine-sols-candidate.png",
    "tangseng": "tangseng/nine_sols_v1/tangseng-nine-sols-candidate.png",
    "mountain_wolf": "mountain_wolf/nine_sols_v1/mountain-wolf-nine-sols-candidate.png",
    "gray_rat": "gray_rat/nine_sols_v1/gray-rat-nine-sols-candidate.png",
    "boar": "mountain_boar/nine_sols_v1/mountain-boar-nine-sols-candidate.png",
}

if "--review" in sys.argv:
    out = Image.new("RGB", (1600, 760), "#63716d")
    draw = ImageDraw.Draw(out)
    for i, (key, source) in enumerate(SOURCES.items()):
        im = Image.open(ROOT / "art/concepts" / source).convert("RGBA")
        print(key, im.size, im.getbbox())
        im.thumbnail((300, 325))
        x, y = (i % 5) * 320, (i // 5) * 380
        out.paste(im, (x, y + 28), im)
        draw.text((x + 6, y + 8), key, fill="white")
    out.save("/tmp/nine-sols-source-review.png")
    sys.exit()

# Body-ground annotations, not weapon/tail bounding-box normalisation.
IDLE = {
    "guard_monk": ((580, 1235), .090, "right"),
    "wild_hunter": ((630, 1260), .082, "right"),
    "herbal_spirit_child": ((565, 1490), .064, "right"),
    "sparrow_spirit": ((600, 1280), .067, "right"),
    "foxfire_imp": ((610, 1200), .085, "left"),
    "bear_lord": ((630, 1260), .115, "right"),
    "tangseng": ((520, 1490), .075, "right"),
    "mountain_wolf": ((760, 955), .075, "left"),
    "gray_rat": ((815, 940), .079, "right"),
    "boar": ((800, 1100), .090, "left"),
}
# Individually inspected boxes, ground projections and scales; none is a 2x2 split.
POSES = {
    "herbal_spirit_child": [((60, 0, 610, 636), (330, 619), .155), ((620, 70, 1254, 631), (884, 610), .155), ((55, 635, 615, 1230), (414, 1214), .155), ((720, 640, 1230, 1235), (945, 1210), .155)],
    "sparrow_spirit": [((20, 35, 636, 632), (380, 620), .148), ((646, 35, 1248, 635), (885, 618), .148), ((40, 636, 627, 1230), (401, 1208), .148), ((700, 730, 1160, 1230), (958, 1205), .148)],
    "bear_lord": [((55, 6, 623, 640), (360, 624), .230), ((626, 100, 1248, 645), (883, 626), .230), ((55, 650, 650, 1240), (409, 1219), .230), ((653, 714, 1248, 1240), (999, 1197), .230)],
}
PROJECTILES = {
    "wild_hunter": ("arrow", [38,-62]), "gray_rat": ("stone", [28,-53]),
    "herbal_spirit_child": ("heal", [40,-59]), "sparrow_spirit": ("wind", [34,-49]),
    "foxfire_imp": ("flame", [31,-62]),
}

def aligned(im, box, anchor, scale):
    crop = im.crop(box)
    crop = crop.resize((round(crop.width*scale), round(crop.height*scale)), Image.Resampling.LANCZOS)
    x = round(128-(anchor[0]-box[0])*scale)
    y = round(218-(anchor[1]-box[1])*scale)
    assert x >= 0 and y >= 0 and x+crop.width <= 256 and y+crop.height <= 256, (box, anchor, scale, x, y)
    frame = Image.new("RGBA", (256,256))
    frame.alpha_composite(crop, (x,y))
    return frame

for role, source in SOURCES.items():
    path = ROOT / "art/concepts" / source
    # A cleaned fox derivative is supplied separately by 05; no threshold keying.
    if role == "foxfire_imp":
        path = ROOT / "art/production/foxfire_imp/nine_sols_v1/source-clean.png"
        if not path.exists():
            print("PENDING: fox transparent derivative")
            continue
    im = Image.open(path).convert("RGBA")
    anchor, scale, facing = IDLE[role]
    frames = [aligned(im, (0,0,*im.size), anchor, scale)]
    records = [{"source":str(path.relative_to(ROOT)), "source_box":[0,0,*im.size], "ground":anchor,"scale":scale}]
    if role in POSES:
        sheet_path = ROOT / f"art/concepts/{role}/nine_sols_actions_v1/four-action-keyposes.png"
        sheet = Image.open(sheet_path).convert("RGBA")
        for box, ground, factor in POSES[role]:
            frames.append(aligned(sheet, box, ground, factor))
            records.append({"source":str(sheet_path.relative_to(ROOT)), "source_box":box,"ground":ground,"scale":factor})
    else:
        frames += [frames[0].copy() for _ in range(4)]
        records += [{"reuse_idle":True} for _ in range(4)]
    base = ROOT / f"art/production/{role}/nine_sols_v1"
    base.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (1280,256))
    for i, frame in enumerate(frames):
        frame.save(base / f"{['idle','move','attack','hit','retreat'][i]}.png")
        atlas.paste(frame,(i*256,0))
    atlas.save(base / "body-atlas.png")
    manifest = {
        "version":1, "character":role, "source_facing":facing,
        "status":"keyposes_and_procedural_transitions" if role in POSES else "static_new_skin_with_procedural_transitions",
        "source_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
        "frame":{"width":256,"height":256,"foot_anchor":[128,218]},
        "atlases":{"body":"body-atlas.png"}, "standalone_vfx":{}, "frames":records,
        "actions":{"idle":{"body_frames":[0]},"move":{"body_frames":[1]},"basic_attack":{"body_frames":[2]},"hit":{"body_frames":[3],"hold_seconds":.18},"retreat":{"body_frames":[4],"hold_seconds":.35,"fade_seconds":.3}},
    }
    if role in PROJECTILES:
        projectile, socket = PROJECTILES[role]
        manifest["actions"]["basic_attack"]["projectile"] = projectile
        manifest["emission_socket"] = socket
    (base / "manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print("PACKED",role)
