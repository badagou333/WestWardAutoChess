extends "res://scripts/presentation/character_presentation.gd"
## 05/06 verified atlas0 faces LEFT; atlas1/2/3 face RIGHT. Shared metadata
## stays untouched. Retreat4 is occluded/ambiguous, so retain its old behavior.
func visual_transform() -> Transform2D:
	var result := super.visual_transform()
	if role=="herbal_spirit_child" and motion_frame<0 and frame_index==0:
		result.x *= -1 # Only sprite X basis; logical facing/socket/foot never flip twice.
	return result
