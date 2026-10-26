#!/usr/bin/env python3
"""Rebuild protected diagonal wolf frames from archived imagegen artwork."""
from pathlib import Path
import subprocess,sys,json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(ROOT/'prepare_wolf.py')],check=True)
for d in ['se','ne']:
 folder=ROOT/d
 spec=json.loads((folder/'source/pack_spec.json').read_text())
 prepared=folder/'source/prepared_poses.webp'
 digest=hashlib.sha256(prepared.read_bytes()).hexdigest()
 spec['sources']['protected_ready_assembly']['sha256']=digest
 spec['sources']['protected_ready_assembly']['expected_pixel_sha256']=hashlib.sha256(Image.open(prepared).convert('RGBA').tobytes()).hexdigest()
 gate=ROOT/'REVIEW_STATUS.json'
 if gate.exists():
  review=json.loads(gate.read_text())['directions'][d]
  assert review['prepared_sha256']==digest,'Prepared artwork changed; visual review required'
  spec['status']='reviewed_candidate'
  spec['review_annotations']['visual_gate']='limited_offline_pass; see ../REVIEW_STATUS.json and REVIEW.md; human acceptance pending'
 (folder/'spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
 subprocess.run([sys.executable,str(ROOT.parent.parent/'pixel_attack_series_v1/tools/build_attack.py'),'--spec',str(folder/'spec.json')],check=True)
