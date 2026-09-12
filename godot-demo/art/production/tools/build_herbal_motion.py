"""Rebuild the isolated herbal cast candidate with stable planted feet and palm sockets."""
from build_melee_motion import run

SCALE = 142 / 452
PIVOTS = [(212,482),(596,482),(980,482),(1364,482),
          (213,980),(597,980),(981,980),(1365,980)]
HANDS = [(250,329),(603,244),(985,236),(1472,227),
         (353,702),(727,730),(988,735),(1397,826)]
NAMES = ['cast_ready','cast_lift','cast_gather','cast_extend',
         'cast_release','cast_follow','cast_retract','cast_lower']
TRACK = [('windup',0,0),('windup',.18,1),('windup',.45,2),('windup',.78,3),
         ('release',0,4),('recover',0,5),('recover',.27,6),
         ('recover',.55,7),('recover',.84,0)]

if __name__ == '__main__':
    run({'herbal_spirit_child':(SCALE,PIVOTS)}, NAMES, {
        'idle':0, 'move':[],
        'attack':{'windup':1,'accelerate':3,'impact':4,'recover':6},
        'attack_track':[{'phase':p,'fraction':f,'frame':i} for p,f,i in TRACK],
        'hand_sockets':[[round(128+(h[0]-p[0])*SCALE,2),round(218+(h[1]-p[1])*SCALE,2)] for h,p in zip(HANDS,PIVOTS)],
        'hand_source_points':HANDS,
        'socket_offset':[0,0],
        'charge_effect':{'key':'idle_mist','size':[18,22],'idle':False},
        'notes':['Trial cast only; reference identity and demo_v1 are preserved.',
                 'Staff remains planted in the same hand; the free palm releases the existing healing projectile.',
                 'Last recovery, idle and next windup share frame 0 to avoid a loop seam.',
                 'Generated checker is removed by the established authorized matte workflow.',
                 'Existing timing, healing amounts, flight duration and movement/hit/retreat remain unchanged.']
    })
