#!/usr/bin/env python3
"""Read all exported body/FX pixels, atlas cells and decoded GIF stages."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def foot_point(image,roi):
    left,top,right,bottom=roi
    a=np.asarray(image)[top:bottom,left:right,3]
    ys,xs=np.nonzero(a>=128);low=int(ys.max())
    return [int(np.median(xs[ys==low])+left),low+top]


def main():
    spec=json.loads((ROOT/'spec.json').read_text())
    manifest=json.loads((ROOT/'manifest.json').read_text())
    atlas=Image.open(ROOT/'atlas.png').convert('RGBA')
    images={};bodies=[]
    for index,entry in enumerate(manifest['bodies']):
        file=ROOT/entry['file'];im=Image.open(file).convert('RGBA');a=np.asarray(im)
        assert im.size==(448,448)
        assert sha(file.read_bytes())==entry['sha256']
        assert sha(im.tobytes())==entry['rgba_pixel_sha256']
        assert set(np.unique(a[:,:,3])).issubset({0,255})
        assert not any(np.any(side) for side in [a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])
        assert atlas.crop((index*448,0,(index+1)*448,448)).tobytes()==im.tobytes()
        assert not entry['source_crop_cuts_component']
        images[entry['id']]=im
        bodies.append({'id':entry['id'],'visible_bbox':list(im.getbbox()),
                       'atlas_rgba_exact':True,'transparent_edges':True,
                       'rear_claw_low_point':foot_point(im,[120,380,175,410]),
                       'front_claw_low_point':foot_point(im,[205,380,255,410]),
                       'sha256':entry['sha256']})
    assert len(images)==6
    assert len({im.tobytes() for im in images.values()})==6
    assert spec['track'][0]['body']==spec['track'][-1]['body']
    assert not spec['track'][0].get('layers') and not spec['track'][-1].get('layers')
    assert all(len(stage.get('layers',[]))<=1 for stage in spec['track'])
    gif_reports={}
    for name,factor in [('preview.gif',1),('preview_slow.gif',2)]:
        im=Image.open(ROOT/name);decoded=[];times=[]
        for index in range(im.n_frames):
            im.seek(index);decoded.append(im.convert('RGB').copy());times.append(im.info['duration'])
        bounds=[x['at_ms']*factor for x in spec['track']]+[spec['duration_ms']*factor+spec['idle_ms']]
        assert times==[b-a for a,b in zip(bounds,bounds[1:])]
        assert len(decoded)==len(manifest['renders'])
        max_fx_error=0;body_checked=0
        for stage,render,actual in zip(spec['track'],manifest['renders'],decoded):
            rgba=Image.open(ROOT/render['file']).convert('RGBA')
            wanted=Image.new('RGBA',(448,448),(35,40,48,255));wanted.alpha_composite(rgba)
            want=np.asarray(wanted.convert('RGB'));got=np.asarray(actual)
            body=np.asarray(images[stage['body']]);mask=body[:,:,3]==255
            assert np.array_equal(want[mask],body[:,:,:3][mask])
            exact=mask | (np.asarray(rgba)[:,:,3]==0)
            assert np.array_equal(want[exact],got[exact])
            body_checked+=int(mask.sum())
            if np.any(~exact):
                max_fx_error=max(max_fx_error,int(np.abs(want[~exact].astype(int)-got[~exact].astype(int)).max()))
        gif_reports[name]={'decoded_stages':len(decoded),'duration_ms':times,'total_ms':sum(times),
                           'opaque_body_and_background_rgb_exact':True,
                           'opaque_body_pixels_checked':body_checked,
                           'fx_only_max_rgb_quantization_error':max_fx_error,
                           'sha256':sha((ROOT/name).read_bytes())}
    src=spec['sources']['body'];file=ROOT/src['file']
    assert sha(file.read_bytes())==src['sha256']
    assert sha(Image.open(file).convert('RGBA').tobytes())==src['expected_pixel_sha256']
    prov=json.loads((ROOT/'source/provenance.json').read_text())
    for entry in prov['adopted_sources']:
        file=ROOT/entry['file'];assert sha(file.read_bytes())==entry['webp_sha256']
        assert sha(Image.open(file).convert('RGBA').tobytes())==entry['rgba_sha256']
    result={'result':'technical_pass_visual_review_separate','body_count':6,'stage_count':len(spec['track']),
            'bodies':bodies,'first_last_body_rgba_identical':True,'single_wind_layer_per_stage':True,
            'source_rgba_hashes_verified':True,'gif_roundtrip':gif_reports,
            'visual_review':'REVIEW.md','not_covered':['owner_realtime_continuous_playback','runtime_integration','gameplay_event_binding']}
    if spec.get('independent_review'):result['independent_review_summary_reported_by_root']=spec['independent_review']
    (ROOT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'result':result['result'],'bodies':6,'stages':result['stage_count'],
                      'normal_ms':gif_reports['preview.gif']['total_ms'],
                      'slow_ms':gif_reports['preview_slow.gif']['total_ms']},ensure_ascii=False))


if __name__=='__main__':
    main()
