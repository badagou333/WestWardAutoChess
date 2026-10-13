"""Small stdlib-only checks for the delivered glTF rotation patch."""
import hashlib, json, math
from pathlib import Path

HERE=Path(__file__).resolve().parent
path=HERE/'dual-fire-animations.json'
data=json.loads(path.read_text())
build=json.loads((HERE/'build-report.json').read_text())
expected={prefix+'.'+side for side in ('L','R') for prefix in ('upper_arm','forearm','hand')}
assert set(data['replace_only_bones'])==expected
assert abs(data['source_time_offset']-1/30)<1e-12
assert data['quaternion_order']=='xyzw'
clips={}
for name,duration,count in [('DualFireIdle',3,91),('DualFireRun',2/3,21)]:
    clip=data['clips'][name]
    assert clip['duration']==duration
    assert len(clip['tracks'])==6 and {t['bone'] for t in clip['tracks']}==expected
    variations={}
    for track in clip['tracks']:
        assert track['path']=='rotation' and track['interpolation']=='LINEAR'
        times,values=track['times'],track['values']
        assert len(times)==len(values)==count
        assert times[0]==0 and times[-1]==duration
        assert all(b>a for a,b in zip(times,times[1:]))
        assert all(abs(sum(x*x for x in q)-1)<1e-5 for q in values)
        assert abs(abs(sum(a*b for a,b in zip(values[0],values[-1])))-1)<1e-5
        variation=max(math.degrees(2*math.acos(min(1,abs(sum(a*b for a,b in zip(values[0],q)))))) for q in values)
        assert variation>.1, (name,track['bone'],'frozen arm')
        variations[track['bone']]=variation
    evidence=build['evidence'][name]
    assert evidence['non_arm_curves_exact'] and evidence['loop_mesh_error']<1e-5
    assert evidence['minimum_palm_separation']>.5
    assert evidence['high_minus_low_palm_z_range'][0]>.09
    assert all(v['maximum_wrist_direction_change_degrees']<30 for v in evidence['hands'].values())
    clips[name]={'duration':duration,'keys_per_bone':count,'arm_rotation_variation_degrees':variations,
                 'non_arm_curves_exact':True,'loop_mesh_error':evidence['loop_mesh_error']}
report={'passed':True,'json_bytes':path.stat().st_size,'json_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'clips':clips,'limits':'Numeric export/pose checks only; actual flame and board-camera appearance require engine visual review.'}
(HERE/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
