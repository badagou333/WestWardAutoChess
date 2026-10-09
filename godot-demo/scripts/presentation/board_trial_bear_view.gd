extends "res://scripts/presentation/character_presentation.gd"
## Actual atlas0 faces left. Only the board opts into this frame-local correction;
## shared metadata/other frames, logical facing, clocks and sockets stay intact.
const RULE := "bear-frame0-source-left-d004"

func visual_transform() -> Transform2D:
	var result := super.visual_transform()
	if role=="bear_lord" and motion_frame<0 and frame_index==0:
		result.x *= -1
	return result
