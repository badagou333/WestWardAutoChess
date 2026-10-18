#!/usr/bin/env python3
"""Offline packaging/verification only: preserves source RGBA; no anatomy redraw."""
from pathlib import Path
import json, hashlib, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
SPEC = json.loads((ROOT / "annotations.json").read_text())
POSES = ["idle", "move_a", "move_b", "attack_prepare", "attack_contact"]
DIRECTIONS = ["SE", "SW", "NE", "NW"]
SOURCES = {
 "monk-initial.png": "exec-fcc1d5b2-0af6-40cd-88e1-25976fc16e90.png",
 "wolf-initial.png": "exec-7ee927c4-73f4-4934-a97d-21e8d8a95763.png",
 "monk-revised.png": "exec-4fd22d60-1513-43fc-9bc2-613268da46ae.png",
 "wolf-revised.png": "exec-62419496-5318-4ebe-87fa-4839ccad8a8d.png",
}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def point(p,a,s): return [round((p[0]-a[0])*s,4),round((p[1]-a[1])*s,4)]
def boxpoints(b): return [[b[0],b[1]],[b[2],b[1]],[b[2],b[3]],[b[0],b[3]]]
def convex(points):
 pts=sorted(set(map(tuple,points)))
 if len(pts)<3:return [list(p) for p in pts]
 def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
 low=[]; high=[]
 for p in pts:
  while len(low)>=2 and cross(low[-2],low[-1],p)<=0: low.pop()
  low.append(p)
 for p in reversed(pts):
  while len(high)>=2 and cross(high[-2],high[-1],p)<=0:high.pop()
  high.append(p)
 return [list(p) for p in low[:-1]+high[:-1]]
def diamond_metric(points):
 return max((abs(x)/96+abs(y)/48 for x,y in points),default=0)
def components(alpha):
 # Run-length union-find, 8-connected. Avoids unavailable scipy dependency.
 a=alpha>=8; labels=np.zeros(a.shape,dtype=np.int32); parents=[0]; prev=[]
 def root(i):
  while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
  return i
 for y,row in enumerate(a):
  edges=np.diff(np.r_[False,row,False].astype(np.int8))
  starts=np.flatnonzero(edges==1); ends=np.flatnonzero(edges==-1)
  cur=[]; pi=0
  for x0,x1 in zip(starts,ends):
   while pi<len(prev) and prev[pi][1]<x0:pi+=1
   overlap=[];j=pi
   while j<len(prev) and prev[j][0]<=x1:overlap.append(root(prev[j][2]));j+=1
   if overlap:
    v=min(overlap)
    for r in overlap:parents[r]=v
   else:v=len(parents);parents.append(v)
   labels[y,x0:x1]=v;cur.append((x0,x1,v))
  prev=cur
 lookup=np.array([root(i) for i in range(len(parents))]);labels=lookup[labels]
 ids,counts=np.unique(labels,return_counts=True)
 large=[]
 for i,c in zip(ids,counts):
  if i and c>1000:
   yy,xx=np.where(labels==i)
   large.append({"label":int(i),"count":int(c),"bbox":[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]})
 assert len(large)==10, ("unexpected disconnected body count",len(large))
 # Two rows by y, then five bodies by x; no equal-width cutting.
 by_y=sorted(large,key=lambda c:c["bbox"][1])
 return labels, sorted(by_y[:5],key=lambda c:c["bbox"][0])+sorted(by_y[5:],key=lambda c:c["bbox"][0])

for sub in ["frames","previews"]: (ROOT/sub).mkdir(exist_ok=True)
manifest={
 "schema":"rect-iso-duel-v1","status":"limited_key_pose_candidate_not_complete_animation",
 "decision":"D-20261018-002","created":"2026-10-18",
 "design_cell":{"width":192,"height":96,"safe_inset":0.90,"vertices":[[0,-48],[96,0],[0,48],[-96,0]]},
 "coordinates":{"source":"top-left continuous-edge pixels; x right, y down",
 "sample_rect":"[x,y,width,height] in source atlas; per-frame PNG is this rectangle after isolating its connected silhouette",
 "crop":"source minus sample_rect origin",
 "design":"(source-anchor_source)*uniform_scale_to_design; anchor is cell center",
 "mirror":"SW from SE; NW from NE; design x -> -x. Crop anchor x -> image_width-anchor_x; edge coordinates, no minus one",
 "feet":"manual visible-foot image envelopes and bottom-edge contact proxies; NOT calibrated 3D footprints; hidden outlines stay null",
 "attack_contact":"visual staff-tip/muzzle point; not combat range, hitbox or damage timing",
 "anchor":"manual staging ground reference; not measured skeletal root; frame-to-frame interpolation remains unverified"},
 "readiness":{"static_idle_visual_placement":"candidate; four idle views plus mirrors inspected",
 "monk_SE_move":"two distinguishable key poses, no complete smooth cycle",
 "monk_NE_move":"failed_same_leg_phase",
 "wolf_move":"failed_no_clear_diagonal_pair_exchange",
 "full_footprint_all_frames":False,"runtime_tested":False,"owner_visual_approved":False,
 "recommended_integration":"isolated prototype only; keep supplied limitations visible; do not label smooth animation"},
 "reference_images":[
  {"path":"godot-demo/art/concepts/guard_monk/nine_sols_v1/guard-monk-nine-sols-candidate.png","sha256":"304a21515f7f5579b9b9cecb1e9d687b3da944816e82304664e476bebefe4582"},
  {"path":"godot-demo/art/concepts/mountain_wolf/nine_sols_v1/mountain-wolf-nine-sols-candidate.png","sha256":"9c2a29db71a9a6a477054a2d36c1cbac8e3d316cd3d1cb2622727188a1d89585"}],
 "generation":{"tool":"Codex built-in imagegen","calls_per_actor":2,"additional_generation_performed":False,"prompt_file":"PROMPTS.md","requested_size":[2500,1000],"actual_size":"see sources; output differs from request","camera":"approximately 30 degrees intended; not calibrated"},
 "sources":[], "actors":{}, "frames":[]
}
report={"checks":{},"segmentation":{},"frames":[],"warnings":[]}
for name,original in SOURCES.items():
 path=ROOT/"sources"/name;im=Image.open(path)
 manifest["sources"].append({"path":"sources/"+name,"original_generated_filename":original,
 "sha256":sha(path),"size":list(im.size),"mode":im.mode,"role":"current_candidate" if "revised" in name else "history"})
assert all(s["mode"]=="RGBA" for s in manifest["sources"])
for actor in ["monk","wolf"]:
 srcpath=ROOT/"sources"/(actor+"-revised.png");src=Image.open(srcpath).convert("RGBA")
 rgba=np.asarray(src);labels,groups=components(rgba[:,:,3]);major=[g["label"] for g in groups]
 anymajor=np.isin(labels,major);used=np.zeros(labels.shape,dtype=bool)
 specs=[f for f in SPEC["frames"] if f["actor"]==actor]
 scale=SPEC["scale_to_design"][actor]
 manifest["actors"][actor]={"uniform_scale_to_design":scale,"source_directions":["SE","NE"],"mirrored_directions":{"SW":"SE","NW":"NE"},
 "natural_overhang":"staff may extend beyond cell; excluded from monk body bbox" if actor=="monk" else "tail may extend beyond cell; excluded from wolf body bbox",
 "no_per_frame_scale":True}
 for spec,group in zip(specs,groups):
  own=labels==group["label"]
  # Retain original antialias pixels within two pixels of own silhouette.
  halo=np.asarray(Image.fromarray((own*255).astype("uint8")).filter(ImageFilter.MaxFilter(5)))>0
  keep=own | (halo & ~anymajor)
  assert not np.any(used & keep & (rgba[:,:,3]>=8)), "overlap"
  used|=keep
  isolated=np.array(rgba);isolated[~keep]=0
  isolate=Image.fromarray(isolated);bb=isolate.getbbox()
  x0=max(0,bb[0]-2);y0=max(0,bb[1]-2);x1=min(src.width,bb[2]+2);y1=min(src.height,bb[3]+2)
  frame=isolate.crop((x0,y0,x1,y1));name=spec["id"]+".png";frame.save(ROOT/"frames"/name)
  anchor=spec["anchor_source"];cropanchor=[anchor[0]-x0,anchor[1]-y0]
  feet=[];known=[];allvisible=[];complete=True;allground=True
  for foot in spec["feet"]:
   out=dict(foot);b=foot["visible_bounds_source"];poly=None;sole=None
   if b is not None:
    poly=[point(p,anchor,scale) for p in boxpoints(b)];allvisible+=poly
    if foot["support"]=="contact" and foot["full_outline_visible"]:
     # Contact proxy uses visible bottom strip; includes entire width conservatively.
     sole_source=[[b[0],b[3]-6],[b[2],b[3]-6],[b[2],b[3]],[b[0],b[3]]]
     sole=[point(p,anchor,scale) for p in sole_source];known+=sole
   if foot["support"]=="uncertain" or (foot["support"]=="contact" and not foot["full_outline_visible"]):complete=False
   if foot["support"]!="contact" or not foot["full_outline_visible"]:allground=False
   out.update({"visible_envelope_design":poly,"contact_proxy_design":sole,
    "ground_projection_design":None if foot["support"]!="contact" or sole is None else sole,
    "annotation_confidence":"manual_2d_visible_proxy" if sole else "unknown_ground_projection"})
   feet.append(out)
  hull=convex(known);body=spec["body_bbox_source"];bodydesign=[point([body[0],body[1]],anchor,scale),point([body[2],body[3]],anchor,scale)]
  contact=spec["attack_contact_source"]
  entry={**spec,"source":"sources/"+actor+"-revised.png","image":"frames/"+name,"image_size":list(frame.size),
   "sha256":sha(ROOT/"frames"/name),"source_component_label":group["label"],
   "sample_rect":[x0,y0,x1-x0,y1-y0],"anchor_crop":cropanchor,"uniform_scale_to_design":scale,
   "body_bbox_design":bodydesign,"body_size_design":[round((body[2]-body[0])*scale,2),round((body[3]-body[1])*scale,2)],
   "feet":feet,"known_contact_proxy_hull_design":hull,
   "support_footprint_design":hull if complete else None,"support_complete":complete,
   "all_feet_ground_envelope_design":convex(allvisible) if allground else None,"all_feet_ground_complete":allground,
   "visible_feet_envelope_metric":round(diamond_metric(allvisible),5),"contact_proxy_metric":round(diamond_metric(hull),5),
   "visible_feet_inside_safe_diamond":diamond_metric(allvisible)<=.9,
   "attack_contact_crop":None if contact is None else [contact[0]-x0,contact[1]-y0],
   "attack_contact_design":None if contact is None else point(contact,anchor,scale),
   "prototype_use":"hold_for_foot_visibility" if spec["id"]=="wolf_se_move_b" else "redundant_same_phase_not_recommended" if spec["id"] in ["monk_ne_move_b","wolf_ne_move_b"] else "limited_movement_pose" if spec["pose"].startswith("move") else "attack_key_pose_with_listed_limits" if spec["pose"].startswith("attack") else "static_idle_placement_checked",
   "full_animation_approved":False}
  assert len(feet)==(2 if actor=="monk" else 4)
  assert all(0<=v<=lim for v,lim in zip(cropanchor,frame.size))
  assert entry["body_size_design"][0] <=192
  # Every kept nonzero pixel equals original, including alpha. No recolor/repaint.
  outa=np.asarray(frame);region=rgba[y0:y1,x0:x1];nz=outa[:,:,3]>0
  assert np.array_equal(outa[nz],region[nz])
  assert diamond_metric([[-p[0],p[1]] for p in allvisible])==diamond_metric(allvisible)
  manifest["frames"].append(entry)
  report["frames"].append({"id":spec["id"],"safe_visible_foot_envelope":entry["visible_feet_inside_safe_diamond"],
   "all_ground_known":allground,"support_complete":complete,"visible_metric":entry["visible_feet_envelope_metric"],
   "body_size_design":entry["body_size_design"],"preserved_rgba":True,"mirror_metric_equal":True,"issues":spec["issues"]})
 omitted=rgba[:,:,3][~used]
 significant=int(np.count_nonzero(omitted>=8));maxa=int(omitted.max(initial=0))
 report["segmentation"][actor]={"large_connected_bodies":len(groups),"retained_pixels":int(np.count_nonzero(used&(rgba[:,:,3]>0))),
 "omitted_alpha_ge_8_pixels":significant,"max_omitted_alpha":maxa,"method":"8-connected alpha>=8; two-pixel halo; all source originals retained"}
 if significant:report["warnings"].append(actor+": disconnected alpha>=8 flecks omitted; inspect omission count, source remains intact.")

font=ImageFont.load_default()
def preview_card(frame,direction,overlay=False):
 card=Image.new("RGB",(256,256),(231,235,231));d=ImageDraw.Draw(card);cx,cy=128,191
 verts=[(cx,cy-48),(cx+96,cy),(cx,cy+48),(cx-96,cy)]
 d.polygon(verts,fill=(198,207,195),outline=(70,88,78))
 inset=[(cx,cy-43.2),(cx+86.4,cy),(cx,cy+43.2),(cx-86.4,cy)]
 d.line(inset+[inset[0]],fill=(142,157,143),width=1)
 im=Image.open(ROOT/frame["image"]);mirror=direction in ["SW","NW"];s=frame["uniform_scale_to_design"]
 # Map original crop through exactly the requested scale; output grid stays 192x96.
 ax,ay=frame["anchor_crop"]; origin_x=cx-ax*s; origin_y=cy-ay*s
 affine=(1/s,0,-origin_x/s,0,1/s,-origin_y/s)
 full=im.transform(card.size,Image.Transform.AFFINE,affine,Image.Resampling.BICUBIC)
 if mirror:full=full.transpose(Image.Transpose.FLIP_LEFT_RIGHT) # pixel center mirror around x=128 in edge coords
 card=Image.alpha_composite(card.convert("RGBA"),full).convert("RGB");d=ImageDraw.Draw(card)
 sign=-1 if mirror else 1
 if overlay:
  for foot in frame["feet"]:
   poly=foot["visible_envelope_design"]
   if poly:
    q=[(cx+sign*x,cy+y) for x,y in poly]
    d.line(q+[q[0]],fill=(25,101,177),width=1)
   sole=foot["contact_proxy_design"]
   if sole:
    q=[(cx+sign*x,cy+y) for x,y in sole]
    d.polygon(q,fill=(36,155,91),outline=(12,82,46))
  if frame["attack_contact_design"]:
   x,y=frame["attack_contact_design"];p=(cx+sign*x,cy+y);d.ellipse((p[0]-3,p[1]-3,p[0]+3,p[1]+3),fill=(186,54,47))
  d.line((cx-4,cy,cx+4,cy),fill=(182,36,53));d.line((cx,cy-4,cx,cy+4),fill=(182,36,53))
 d.text((10,10),frame["actor"]+" / "+direction+" / "+frame["pose"],font=font,fill=(30,43,35))
 status="visible contact proxies" if frame["all_feet_ground_complete"] else "partial / airborne / uncertain"
 d.text((10,237),status,font=font,fill=(50,64,54))
 return card
for actor in ["monk","wolf"]:
 for overlay in [False,True]:
  sheet=Image.new("RGB",(1024,1280),(231,235,231))
  for r,pose in enumerate(POSES):
   for c,direction in enumerate(DIRECTIONS):
    source_dir={"SW":"SE","NW":"NE"}.get(direction,direction)
    f=next(f for f in manifest["frames"] if f["actor"]==actor and f["direction"]==source_dir and f["pose"]==pose)
    sheet.paste(preview_card(f,direction,overlay),(c*256,r*256))
  sheet.save(ROOT/"previews"/(actor+("-footprints" if overlay else "-1x")+".png"))
overview=Image.new("RGB",(1024,512),(231,235,231))
for r,actor in enumerate(["monk","wolf"]):
 for c,direction in enumerate(DIRECTIONS):
  source_dir={"SW":"SE","NW":"NE"}.get(direction,direction)
  f=next(f for f in manifest["frames"] if f["actor"]==actor and f["direction"]==source_dir and f["pose"]=="idle")
  overview.paste(preview_card(f,direction,False),(c*256,r*256))
overview.save(ROOT/"previews"/"idle-four-directions-1x.png")
report["checks"]={"sources":4,"isolated_frames":len(manifest["frames"]),"design_cell":[192,96],"common_scale_per_actor":True,
 "all_idle_full_visible_foot_envelopes_inside_safe_diamond":all(f["all_feet_ground_complete"] and f["visible_feet_inside_safe_diamond"] for f in manifest["frames"] if f["pose"]=="idle"),
 "all_known_contact_proxies_inside_safe_diamond":all(f["contact_proxy_metric"]<=.9 for f in manifest["frames"]),
 "all_visible_foot_envelopes_inside_90_percent_diamond":all(f["visible_feet_inside_safe_diamond"] for f in manifest["frames"]),
 "source_pixel_preservation":True,"mirror_geometry":True,"preview_grid_is_actual_pixels":True,
 "runtime_tested":False,"full_animation_passed":False}
(ROOT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
(ROOT/"validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(report["checks"],ensure_ascii=False))
print(json.dumps(report["segmentation"],ensure_ascii=False))
print("warnings:",report["warnings"])
