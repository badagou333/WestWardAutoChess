#!/usr/bin/env python3
"""Protected-ready two-direction wolf attack preparation, no limb transforms.

Only explicit .50 whole source sampling is used. The ready support limbs,
hips and tail remain at their original pixel positions. Masks select actual
new imagegen head/neck/chest/raised-near-foreleg art from the same camera.
"""
from pathlib import Path
import hashlib
import json
import types
import numpy as np
from PIL import Image,ImageDraw,ImageFilter

ROOT=Path(__file__).resolve().parent
PUBLIC=ROOT.parents[1]/"pixel_attack_series_v1/tools/build_attack.py"
NAMES=["ready","coil","open_reach","clamp_contact","retract","settle"]

def sha(data):return hashlib.sha256(data).hexdigest()
def engine():
    m=types.ModuleType("diagonal_wolf_public")
    exec(compile(PUBLIC.read_text(),str(PUBLIC),"exec"),m.__dict__)
    return m
def polygon(points,size):
    image=Image.new("1",size)
    ImageDraw.Draw(image).polygon([tuple(p) for p in points],fill=1)
    return np.asarray(image).copy()

def prepare(root=ROOT):
    cfg=json.loads((root/"assembly_spec.json").read_text())
    public=engine();all_images=[];directions={}
    for direction,entry in cfg["directions"].items():
        folder=root/direction;path=folder/entry["source"]
        if sha(path.read_bytes())!=entry["source_file_sha256"]:
            raise ValueError("Raw direction source hash changed")
        source=Image.open(path).convert("RGBA")
        extracted=[];records=[]
        for pose in entry["poses"]:
            image,record=public.extract(source,pose,cfg["common_source_scale"],tuple(cfg["canvas"]),tuple(cfg["anchor"]))
            extracted.append(image);records.append(record)
        base=np.asarray(extracted[0]);images=[];masks=[];changes=[]
        for i,donor in enumerate(extracted):
            mask=np.zeros(base.shape[:2],dtype=bool)
            if i:
                upper=entry.get("upper_polygon_by_body",{}).get(str(i),entry["upper_polygon"])
                mask|=polygon(upper,tuple(cfg["canvas"]))
                if str(i) in entry["near_foreleg_airborne_bodies"]:
                    mask|=polygon(entry["near_foreleg_polygon"],tuple(cfg["canvas"]))
                elif entry["extra_grounded_near_protection"]:
                    mask&=~polygon(entry["extra_grounded_near_protection"],tuple(cfg["canvas"]))
                for protected in entry["protected_polygons"]+entry.get("protected_polygons_by_body",{}).get(str(i),[]):
                    mask&=~polygon(protected,tuple(cfg["canvas"]))
            result=base.copy()
            if i:
                # One complete old/new upper-body envelope removes every old
                # ear/head/back edge; a cropped half-head leaves visible ghosts.
                # All protected support regions keep ready pixels in place.
                result[mask]=np.asarray(donor)[mask]
                exclusions=list(entry.get("donor_exclusions_all",[]))+entry.get("donor_exclusions_by_body",{}).get(str(i),[])
                if str(i) in entry["near_foreleg_airborne_bodies"]:
                    exclusions+=entry.get("donor_exclusions_airborne",[])
                for points in exclusions:
                    excluded=polygon(points,tuple(cfg["canvas"])) & mask
                    result[excluded]=0
            patch=entry.get("patches_by_body",{}).get(str(i))
            if patch:
                patch_path=folder/patch["file"]
                assert sha(patch_path.read_bytes())==patch["sha256"]
                edit=np.array(Image.open(patch_path).convert("RGBA").resize(tuple(cfg["canvas"]),Image.Resampling.NEAREST))
                edit[:,:,3]=np.where(edit[:,:,3]>=128,255,0)
                x0,y0,x1,y1=patch["region"]
                old_alpha=result[:,:,3];new_alpha=edit[:,:,3]
                old_inner=np.asarray(Image.fromarray(old_alpha).filter(ImageFilter.MinFilter(17)))>0
                new_inner=np.asarray(Image.fromarray(new_alpha).filter(ImageFilter.MinFilter(17)))>0
                edge=((old_alpha>0)&~old_inner)|((new_alpha>0)&~new_inner)|((old_alpha>0)!=(new_alpha>0))
                region=np.zeros(edge.shape,dtype=bool);region[y0:y1,x0:x1]=True
                patch_mask=edge&region
                result[patch_mask]=edit[patch_mask]
                mask|=patch_mask
            result[result[:,:,3]==0]=0
            assert np.array_equal(result[~mask],base[~mask])
            changed=np.any(result!=base,axis=2);ys,xs=np.where(changed)
            images.append(Image.fromarray(result));masks.append(mask)
            changes.append({"id":str(i),"name":NAMES[i],"source_pose":str(i),
                "edit_target":"ready pose0, same direction",
                "changed_rgba_pixels_before_palette":int(changed.sum()),
                "change_bbox":None if not len(xs) else [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],
                "outside_explicit_mask_RGBA_exact":True,
                "near_foreleg":"airborne" if str(i) in entry["near_foreleg_airborne_bodies"] else "contact",
                "unquantized_pixel_sha256":sha(images[-1].tobytes())})
        directions[direction]={"images":images,"extracted":extracted,"masks":masks,"extraction":records,"changes":changes}
        all_images.extend(images)
    mapped,colors=public.train_body_palette(all_images,cfg["palette_colors"])
    cursor=0
    for direction,data in directions.items():
        data["mapped"]=mapped[cursor:cursor+len(data["images"])];cursor+=len(data["images"])
    return cfg,directions,colors

def main():
    cfg,directions,colors=prepare()
    for direction,data in directions.items():
        folder=ROOT/direction;debug=folder/"source/debug";debug.mkdir(parents=True,exist_ok=True)
        sheet=Image.new("RGBA",(1344,896));preview=Image.new("RGBA",(1344,896));mask_sheet=Image.new("L",(1344,896))
        for i,(image,raw,mask) in enumerate(zip(data["mapped"],data["extracted"],data["masks"])):
            offset=((i%3)*448,(i//3)*448);sheet.alpha_composite(image,offset);preview.alpha_composite(image,offset)
            mask_sheet.paste(Image.fromarray((mask*255).astype(np.uint8)),offset)
            image.save(debug/f"{i}.png");raw.save(debug/f"raw_{i}.png")
        path=folder/"source/prepared_poses.webp";sheet.save(path,lossless=True,exact=True,method=6)
        assert sheet.tobytes()==Image.open(path).convert("RGBA").tobytes()
        mask_sheet.save(folder/"source/assembly_masks.png");preview.save(debug/"assembly_sheet.png")
        report={"date":"2026-10-27","role":"author_protected_ready_assembly_not_independent_gate",
            "source":cfg["directions"][direction]["source"],"source_scale_common":cfg["common_source_scale"],
            "canvas":cfg["canvas"],"anchor":cfg["anchor"],"display_scale":cfg["character_display_scale"],
            "forward_screen":cfg["directions"][direction]["forward_screen"],"stance":cfg["stance"],
            "source_extraction":data["extraction"],"poses":data["changes"],"joint_palette_rgb":colors,
            "local_paw_translation_or_warp":False,"all_other_directions_mirrors_only":True,
            "prepared_file":"source/prepared_poses.webp","prepared_sha256":sha(path.read_bytes()),
            "prepared_rgba_pixel_sha256":sha(sheet.tobytes()),"author_visual_status":"draft_requires_full_pose_and_seam_review"}
        (folder/"source/preparation_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"directions":list(directions),"shared_palette":len(colors),"source_scale":cfg["common_source_scale"]}))

if __name__=="__main__":main()
