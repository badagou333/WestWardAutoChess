#!/usr/bin/env python3
"""Read exported pixels and timelines independently of the common packer."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    spec = json.loads((ROOT/'spec.json').read_text())
    manifest = json.loads((ROOT/'manifest.json').read_text())
    atlas = Image.open(ROOT/'atlas.png').convert('RGBA')
    records, images = [], {}
    for index, entry in enumerate(manifest['bodies']):
        file = ROOT/entry['file']
        image = Image.open(file).convert('RGBA')
        a = np.asarray(image)
        assert image.size == (448,448)
        assert sha(file.read_bytes()) == entry['sha256']
        assert sha(image.tobytes()) == entry['rgba_pixel_sha256']
        assert set(np.unique(a[:,:,3])).issubset({0,255})
        assert not any(np.any(side) for side in [a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])
        assert atlas.crop((index*448,0,(index+1)*448,448)).tobytes() == image.tobytes()
        assert not entry['source_crop_cuts_component']
        assert max(abs(v) for v in entry['anchor_rounding_error_px']) <= .5 + 1e-9
        images[entry['id']] = image
        records.append({'id':entry['id'], 'visible_bbox':list(image.getbbox()),
                        'selected_components':entry['selected_components'],
                        'transparent_canvas_edges':True,'atlas_rgba_exact':True,
                        'sha256':entry['sha256']})
    assert len(images) == 6
    assert len({im.tobytes() for im in images.values()}) == 6
    track = spec['track']
    assert images[track[0]['body']].tobytes() == images[track[-1]['body']].tobytes()
    gif_reports = {}
    for name,factor in [('preview.gif',1),('preview_slow.gif',2)]:
        gif = Image.open(ROOT/name)
        decoded, durations = [], []
        for i in range(gif.n_frames):
            gif.seek(i);decoded.append(gif.convert('RGB').copy());durations.append(gif.info['duration'])
        boundaries = [x['at_ms']*factor for x in track]+[spec['duration_ms']*factor+spec['idle_ms']]
        expected = [b-a for a,b in zip(boundaries,boundaries[1:])]
        assert durations == expected
        assert len(decoded) == len(track)
        for stage, actual in zip(track,decoded):
            wanted = Image.new('RGBA',(448,448),(35,40,48,255))
            wanted.alpha_composite(images[stage['body']])
            assert wanted.convert('RGB').tobytes() == actual.tobytes()
        gif_reports[name] = {'decoded_frames':len(decoded),'durations_ms':durations,
                             'total_ms':sum(durations),'every_stage_rgb_exact':True,
                             'sha256':sha((ROOT/name).read_bytes())}
    source_reports = []
    for id,entry in spec['sources'].items():
        file=ROOT/entry['file'];im=Image.open(file).convert('RGBA')
        assert sha(file.read_bytes()) == entry['sha256']
        assert sha(im.tobytes()) == entry['expected_pixel_sha256']
        source_reports.append({'id':id,'decoded_rgba_hash_verified':True,'scale':entry['scale']})
    result = {'result':'technical_pass_visual_review_separate','body_count':len(images),
              'frames':records,'first_last_rgba_exact':True,'sources':source_reports,
              'gif_roundtrip':gif_reports,'visual_review':'REVIEW.md',
              'not_covered':['owner_realtime_experience','runtime_integration','gameplay_hit_timing']}
    if spec.get('independent_review'):
        result['independent_review_summary_reported_by_root'] = spec['independent_review']
    (ROOT/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'result':result['result'],'bodies':len(images),'gif_stages':len(track)},ensure_ascii=False))


if __name__ == '__main__':
    main()
