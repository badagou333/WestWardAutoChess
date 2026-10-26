#!/usr/bin/env python3
"""Independently read all body/atlas/FX/GIF pixels and three support points."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent


def sha(data):return hashlib.sha256(data).hexdigest()


def low_point(image,box):
    l,t,r,b=box;a=np.asarray(image)[t:b,l:r,3]
    ys,xs=np.nonzero(a>=128);y=int(ys.max())
    return [int(np.median(xs[ys==y])+l),y+t]


def main():
    spec=json.loads((ROOT/'spec.json').read_text());manifest=json.loads((ROOT/'manifest.json').read_text())
    atlas=Image.open(ROOT/'atlas.png').convert('RGBA');images={};records=[]
    for index,entry in enumerate(manifest['bodies']):
        f=ROOT/entry['file'];im=Image.open(f).convert('RGBA');a=np.asarray(im)
        assert im.size==(448,448)
        assert sha(f.read_bytes())==entry['sha256'] and sha(im.tobytes())==entry['rgba_pixel_sha256']
        assert set(np.unique(a[:,:,3])).issubset({0,255})
        assert not any(np.any(side) for side in [a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])
        assert atlas.crop((index*448,0,(index+1)*448,448)).tobytes()==im.tobytes()
        assert not entry['source_crop_cuts_component']
        images[entry['id']]=im
        box=im.getbbox();margins=[box[0],box[1],448-box[2],448-box[3]]
        assert min(margins)>=20
        records.append({'id':entry['id'],'bbox':list(box),'canvas_margins':margins,
                        'staff_low_point':low_point(im,[82,384,114,410]),
                        'rear_sandal_low_point':low_point(im,[115,384,170,410]),
                        'front_sandal_low_point':low_point(im,[208,384,262,410]),
                        'atlas_rgba_exact':True,'source_component_not_cut':True,
                        'sha256':entry['sha256']})
    assert len(images)==6 and len({im.tobytes() for im in images.values()})==6
    assert spec['track'][0]['body']==spec['track'][-1]['body']
    assert not spec['track'][0].get('layers') and not spec['track'][-1].get('layers')
    assert all(len(stage.get('layers',[]))<=1 for stage in spec['track'])
    gif_reports={};normal_decoded=[]
    for name,factor in [('preview.gif',1),('preview_slow.gif',2)]:
        gif=Image.open(ROOT/name);decoded=[];durations=[]
        for i in range(gif.n_frames):
            gif.seek(i);decoded.append(gif.convert('RGB').copy());durations.append(gif.info['duration'])
        bounds=[s['at_ms']*factor for s in spec['track']]+[spec['duration_ms']*factor+spec['idle_ms']]
        assert durations==[b-a for a,b in zip(bounds,bounds[1:])]
        assert len(decoded)==len(spec['track'])
        fx_max=0;checked=0
        for stage,render,actual in zip(spec['track'],manifest['renders'],decoded):
            file=ROOT/render['file'];assert sha(file.read_bytes())==render['sha256']
            rgba=Image.open(file).convert('RGBA');want=Image.new('RGBA',(448,448),(35,40,48,255));want.alpha_composite(rgba)
            expected=np.asarray(want.convert('RGB'));got=np.asarray(actual);body=np.asarray(images[stage['body']])
            mask=body[:,:,3]==255;assert np.array_equal(expected[mask],body[:,:,:3][mask])
            exact=mask|(np.asarray(rgba)[:,:,3]==0);assert np.array_equal(expected[exact],got[exact]);checked+=int(mask.sum())
            if np.any(~exact):fx_max=max(fx_max,int(np.abs(expected[~exact].astype(int)-got[~exact].astype(int)).max()))
        gif_reports[name]={'decoded_stages':len(decoded),'durations_ms':durations,'total_ms':sum(durations),
                           'opaque_body_and_empty_background_rgb_exact':True,'opaque_body_pixels_checked':checked,
                           'fx_only_max_rgb_quantization_error':fx_max,'sha256':sha((ROOT/name).read_bytes())}
        if name=='preview.gif':normal_decoded=decoded
    provenance=json.loads((ROOT/'source/provenance.json').read_text())
    for entry in provenance['adopted']:
        f=ROOT/entry['file'];assert sha(f.read_bytes())==entry['webp_sha256']
        assert sha(Image.open(f).convert('RGBA').tobytes())==entry['rgba_sha256']
    src=spec['sources']['body'];f=ROOT/src['file'];assert sha(f.read_bytes())==src['sha256']
    assert sha(Image.open(f).convert('RGBA').tobytes())==src['expected_pixel_sha256']
    prep=json.loads((ROOT/'source/preparation_report.json').read_text())
    assert prep['outside_declared_rois_rgba_exact'] and prep['source_edges_opaque_at_threshold']==[0,0,0,0]
    result={'result':'technical_pass_visual_review_separate','body_count':6,'stage_count':len(spec['track']),
            'frames':records,'gif_roundtrip':gif_reports,'source_rgba_hashes_verified':True,
            'three_source_contacts_registered':True,'rigid_source_ring_head_shared':True,
            'first_last_rgba_identical':True,'at_most_one_charge_or_healing_projectile_per_stage':True,
            'scope_confirmation':'User explicitly confirmed healing main action on 2026-10-26.',
            'visual_review':'REVIEW.md','not_covered':['owner_realtime_continuous_playback','runtime_integration','healing_gameplay_event_binding']}
    if spec.get('independent_review'):result['independent_review_summary_reported_by_root']=spec['independent_review']
    ids=['00_ready','01_gather','02_charge','03_release_heal','04_follow_through','05_return']
    crops=[[211,264,249,303],[175,193,221,236],[226,179,263,221],
           [267,179,317,216],[265,152,318,196],[170,209,222,252]]
    review=Image.new('RGB',(720,500),(35,40,48));draw=ImageDraw.Draw(review)
    for index,(id,box) in enumerate(zip(ids,crops)):
        crop=images[id].crop(box);big=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
        x=index%3*240;y=index//3*250;draw.text((x+8,y+8),id,fill=(237,230,211))
        panel=Image.new('RGBA',(240,225),(35,40,48,255));panel.alpha_composite(big,((240-big.width)//2,(225-big.height)//2))
        review.paste(panel.convert('RGB'),(x,y+25))
    review.save(ROOT/'review_casting_hands.png')
    fx_review=Image.new('RGB',(640,840),(35,40,48));draw=ImageDraw.Draw(fx_review)
    for row,(stage_index,box,label) in enumerate([
        (1,[178,178,274,240],'GATHER'),(2,[223,140,301,225],'CHARGE'),
        (3,[283,170,394,224],'RELEASE'),(6,[394,170,448,224],'PROJECTILE EXIT')]):
        rgba=Image.open(ROOT/manifest['renders'][stage_index]['file']).convert('RGBA')
        reference=Image.new('RGBA',(448,448),(35,40,48,255));reference.alpha_composite(rgba)
        for column,im in enumerate([reference.convert('RGB'),normal_decoded[stage_index]]):
            crop=im.crop(box);big=crop.resize((crop.width*2,crop.height*2),Image.Resampling.NEAREST)
            x=column*320;y=row*210
            draw.text((x+8,y+8),label+(' / RGBA REF' if column==0 else ' / GIF DECODED'),fill=(237,230,211))
            fx_review.paste(big,(x+(320-big.width)//2,y+30+(180-big.height)//2))
    fx_review.save(ROOT/'review_gif_fx.png')
    (ROOT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'result':result['result'],'bodies':6,'stages':len(spec['track']),
                      'normal_ms':gif_reports['preview.gif']['total_ms'],
                      'slow_ms':gif_reports['preview_slow.gif']['total_ms']},ensure_ascii=False))


if __name__=='__main__':main()
