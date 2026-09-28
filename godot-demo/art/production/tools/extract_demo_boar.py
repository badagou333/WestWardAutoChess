"""Exact user-specified Demo boar reference crop; no redesign or recoloring."""
from pathlib import Path
from PIL import Image
ART = Path(__file__).resolve().parents[2]
source = Image.open(ART/'demo/enemy_atlas_keyed.png')
out = ART/'concepts/mountain_boar/demo_boar_reference_crop.png'
source.crop((768,0,1536,470)).save(out)
print(out)
