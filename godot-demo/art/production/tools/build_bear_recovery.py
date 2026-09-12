"""Pack four planted, two-handed club recovery poses for the art trial."""
from build_monk_recovery import ART, build_recovery

if __name__ == '__main__':
    build_recovery(
        ART/'production/bear_lord', 148/450,
        [(415,469),(1093,469),(420,968),(1098,968)],
        ['club_retract','club_lower','return_settle','ready_settled'],
        [(790,307),(1383,374),(702,860),(1373,858)],
        unfold_scale=.96,
    )
