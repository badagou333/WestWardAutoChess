extends "res://scripts/presentation/character_presentation.gd"
## Board-only sample adapter. Combat, pose clocks and source textures stay shared.
const PLAYBACK_KEYS := ["pose","pose_time","animation_clock","attack_serial","attack_direction","facing","visual_alpha","dead",
	"move_start","move_end","move_left","position","hit_pulse","hit_cooldown","impact_stop","landing","sample_walk_time","events"]
var board_actor := {}
var board_delta := 0.0
var board_advancing := false

func sync_board_step(actor: Dictionary, delta: float, advancing: bool) -> void:
	board_actor=actor
	board_delta=delta if advancing else 0.0
	board_advancing=advancing

func end_board_tick() -> void:
	# The controller commits move.time immediately after Hero.tick_visual. Later
	# same-tick play_attack/move_to calls must not count this visual STEP twice.
	board_delta=0.0

func _sync_gait() -> void:
	if board_actor.is_empty(): return
	var completed: float=float(board_actor.step_completed)*float(board_actor.walk)
	if not board_actor.move.is_empty():
		var at: float=minf(float(board_actor.move.duration),float(board_actor.move.time)+board_delta)
		sample_walk_time=completed+at
	elif completed+0.00000001>=sample_walk_time or board_actor.step_serial==0:
		sample_walk_time=completed
	# An interrupted/dead partial segment retains its last visual gait time;
	# only the existing explicit reset_visual/new actor lifecycle resets it.

func _sample_pose() -> String:
	if board_actor.is_empty() or pose not in ["idle","move"]: return pose
	if board_advancing and not board_actor.move.is_empty() and not dead:
		if float(board_actor.move.time)+board_delta+0.00000001<float(board_actor.move.duration): return "move"
	return "idle"

func _select_sample_frame() -> void:
	if not motion_sample_enabled or sample_track==null: return
	motion_frame=-1
	frame_index=sample_track.frame_at(_sample_pose(),pose_time,sample_walk_time)

func update_frame() -> void:
	# Shared hitstop still freezes attack/hit clocks. Board roots do not freeze
	# while walking, so drawn foot phases follow the real committed segment.
	_sync_gait()
	super.update_frame()
	_select_sample_frame()

func set_motion_sample(enabled: bool) -> bool:
	var saved := {}
	for key in PLAYBACK_KEYS:
		var value=get(key)
		saved[key]=value.duplicate(true) if value is Dictionary else value
	var accepted: bool=super.set_motion_sample(enabled)
	# update_frame may cross a lifecycle boundary while changing the source.
	# A display switch must never consume that boundary, reset clocks or events.
	for key in PLAYBACK_KEYS: set(key,saved[key])
	_select_sample_frame()
	return accepted
