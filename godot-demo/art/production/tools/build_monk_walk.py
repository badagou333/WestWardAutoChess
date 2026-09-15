"""Select intact reviewed poses from generated candidates, then append to the current monk pack."""
from PIL import Image
from build_walk_cycle import ART, build_walk

ROOT = ART/'production/guard_monk/motion_v3'
PIVOTS = [(225,453),(597,456),(984,458),(1372,456),
          (224,924),(602,924),(984,924),(1372,924)]
FEET = [((75,443),(334,450)),((477,451),(677,454)),
        ((904,433),(1020,456)),((1215,444),(1432,454)),
        ((97,916),(324,922)),((522,920),(626,882)),
        ((879,920),(1104,881)),((1252,920),(1451,907))]

if __name__ == '__main__':
    # The last full-sheet edit fixed the passing pose but incorrectly changed the next leg.
    # Select only its intact third cell. Keep the other seven from the two-leg repair.
    source = Image.open(ROOT/'source-two-leg-repair.png').convert('RGB')
    passing = Image.open(ROOT/'source-pass-repair.png').convert('RGB')
    assert source.size == passing.size == (1536,1024)
    source.paste(passing.crop((768,0,1152,512)),(768,0))
    source.save(ROOT/'generated-walk-sheet.png')
    build_walk('guard_monk',140/365,PIVOTS,FEET)
