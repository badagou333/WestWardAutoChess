"""Pack the sparrow's standing wing-cast candidate and annotated feather-tip origins."""
from build_melee_motion import run

SCALE = 120 / 427
PIVOTS = [(225,502),(583,502),(952,502),(1323,503),
          (176,965),(570,963),(954,963),(1345,963)]
TIPS = [(83,444),(704,379),(1092,314),(1506,324),
        (422,750),(770,827),(1117,789),(1213,916)]
NAMES = ['cast_ready','cast_lift','cast_gather','cast_extend',
         'cast_release','cast_follow','cast_retract','cast_lower']
TRACK = [('windup',0,0),('windup',.18,1),('windup',.45,2),('windup',.78,3),
         ('release',0,4),('recover',0,5),('recover',.28,6),
         ('recover',.56,7),('recover',.84,0)]

if __name__ == '__main__':
    run({'sparrow_spirit':(SCALE,PIVOTS)}, NAMES, {
        'idle':0, 'move':[],
        'attack':{'windup':1,'accelerate':3,'impact':4,'recover':6},
        'attack_track':[{'phase':p,'fraction':f,'frame':i} for p,f,i in TRACK],
        'emission_sockets':[[round(128+(t[0]-p[0])*SCALE,2),round(218+(t[1]-p[1])*SCALE,2)] for t,p in zip(TIPS,PIVOTS)],
        'emission_source_points':TIPS,
        'socket_offset':[0,0],
        'notes':['Standing wing-cast trial only; two avian wings, no new weapon or formal skill decision.',
                 'An independent existing wind-blade placeholder starts at the leading feather tip on release.',
                 'No attached charge effect or baked projectile on the wing.',
                 'Last recovery, idle and next windup share frame 0.',
                 'Generated neutral checker removed by the established authorized workflow; demo_v1 preserved.',
                 'Uniform source scale; manually marked foot projections are independent of wing span.',
                 'Existing attack timing, damage, projectile travel and old move/hit/retreat remain unchanged.']
    })
