"""Pack reviewed same-hand knife recovery frames using the shared recovery pipeline."""
from build_monk_recovery import ART, build_recovery

if __name__ == '__main__':
    build_recovery(
        ART/'production/wild_hunter', 136/466,
        [(463,487),(1108,487),(466,994),(1104,994)],
        ['knife_retract','knife_lower','return_settle','ready_settled'],
        [(655,209),(1170,323),(441,859),(1080,859)],
        unfold_scale=.96,
    )
