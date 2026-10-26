#!/usr/bin/env python3
"""Rebuild from saved imagegen sources and explicit assembly instructions."""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parent
for name in ['prepare_se.py','prepare_ne.py','finish_specs.py']:
 subprocess.run([sys.executable,str(ROOT/name)],check=True)
builder=ROOT.parent.parent/'pixel_attack_series_v1/tools/build_attack.py'
for direction in ['se','ne']:
 subprocess.run([sys.executable,str(builder),'--spec',str(ROOT/direction/'spec.json')],check=True)
