extends "res://scripts/presentation/board_trial_audio.gd"
## Trial-only output isolation. Shared events/serial consumption remain unchanged.
var listen_friendly := true
var listen_enemy := true
var event_allowed := true
var filtered_count := 0
var warning_filtered := 0

func _team_allowed(node) -> bool:
	if not is_instance_valid(node): return false
	return listen_friendly if node.get_meta("audio_trial_friendly",true) else listen_enemy

func _role_event(event: Dictionary, trigger: String) -> void:
	var saved: bool=event_allowed
	event_allowed=_team_allowed(event.get("source"))
	super._role_event(event,trigger)
	event_allowed=saved

func _play_primary(key: String) -> String:
	if not event_allowed:
		filtered_count+=1
		return "muted" # Base still consumes this exact instance/serial, no catch-up.
	return super._play_primary(key)

func hit_event(target, ranged: bool, is_escort: bool, event: Dictionary, effective_amount: float) -> void:
	if is_escort and effective_amount>0 and not _team_allowed(target):
		warning_filtered+=1
		return
	super.hit_event(target,ranged,is_escort,event,effective_amount)

func stop_all(reset_pause := true) -> void:
	super.stop_all(reset_pause)
	if reset_pause:
		filtered_count=0
		warning_filtered=0
