#!/usr/bin/env python3
"""Set the declared fast downstroke, contact hold and short behind-body trails."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parent
for direction,crop,target in [('se',[360,40,745,792],[288,132,403,362]),('ne',[950,418,1664,662],[328,120,445,178])]:
 path=ROOT/direction/'spec.json';s=json.loads(path.read_text())
 s['layers']={'staff_trail':{'file':'../source/staff_trails.webp','crop':crop,'target_rect':target,'order':'behind'}}
 s['duration_ms']=1070;s['idle_ms']=400
 s['track']=[{'at_ms':t,'body':b} for t,b in [(0,'0'),(130,'1'),(260,'2'),(370,'3'),(410,'3'),(450,'3'),(600,'4'),(760,'5'),(950,'0')]]
 for index,opacity in [(3,.38),(4,.16)]:s['track'][index]['layers']=[{'id':'staff_trail','opacity':opacity,'offset':[0,0]}]
 s['events']=[{'name':'preview_contact_only','at_ms':370}]
 review_path=ROOT/'REVIEW_STATUS.json'
 if review_path.exists():
  review=json.loads(review_path.read_text())['directions'][direction]
  assert review['prepared_sha256']==s['sources']['prepared']['sha256'],'Prepared artwork changed; visual review required'
  assert review['trail_sha256']==hashlib.sha256((ROOT/'source/staff_trails.webp').read_bytes()).hexdigest(),'Trail artwork changed; visual review required'
  s['status']='reviewed_candidate'
  s['review_annotations']={'author_visual_review':'limited_offline_pass; all poses, adjacent stages and fixed-scale diamond views inspected','independent_visual_review':'limited_offline_pass; see ../REVIEW_STATUS.json and REVIEW.md','human_acceptance':'pending','runtime_integration':False}
 path.write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n')
