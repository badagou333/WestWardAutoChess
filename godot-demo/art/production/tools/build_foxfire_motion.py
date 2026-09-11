"""Pack fox cast continuity frames with annotated per-frame flame attachment points."""
from build_melee_motion import run

SCALE = 124 / 372
PIVOTS = [(235,480),(612,481),(973,480),(1345,480),
          (229,944),(622,945),(1005,945),(1371,945)]
HANDS = [(353,296),(584,306),(1028,334),(1465,274),
         (395,746),(767,750),(979,773),(1491,785)]
NAMES = ['cast_ready','cast_gather','cast_charge','cast_extend',
         'cast_release','cast_follow','cast_recover','cast_settle']
TRACK = [('windup',0,0),('windup',.18,1),('windup',.45,2),('windup',.78,3),
         ('release',0,4),('recover',0,5),('recover',.32,6),('recover',.72,7)]

if __name__ == '__main__':
    run({'foxfire_imp':(SCALE,PIVOTS)}, NAMES, {
        'idle':0, 'move':[],
        'attack':{'windup':1,'accelerate':3,'impact':4,'recover':6},
        'attack_track':[{'phase':p,'fraction':f,'frame':i} for p,f,i in TRACK],
        'hand_sockets':[[round(128+(h[0]-p[0])*SCALE,2),round(218+(h[1]-p[1])*SCALE,2)] for h,p in zip(HANDS,PIVOTS)],
        'hand_source_points':HANDS,
        'notes':['Tail stays on the same side from ready through release/recovery.',
                 'Original demo_v1 preserved; generated neutral checker removed locally.',
                 'Per-frame hand points drive charge effect and projectile origin.',
                 'Move/hit/retreat retain original poses; full directional continuity remains pending.']
    })
