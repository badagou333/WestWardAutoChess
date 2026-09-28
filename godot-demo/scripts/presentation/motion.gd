extends RefCounted

# Trial presentation timings, not confirmed balance values. Seconds/pixels/radians.
const PROFILES := {
	"boar": {"windup":0.125,"strike":0.10,"recover":0.25,"walk":0.70,"lift":2.0,"reach":32.0,"lean":0.045},
	"mountain_wolf": {"windup":0.125,"strike":0.10,"recover":0.20,"walk":0.52,"lift":1.5,"reach":42.0,"lean":0.025},
	"guard_monk": {"windup":0.20,"strike":0.10,"recover":0.24,"walk":0.50,"lift":4.0,"reach":56.0,"lean":0.055},
	"wild_hunter": {"windup":0.14,"strike":0.08,"recover":0.22,"walk":0.42,"lift":5.0,"reach":70.0,"lean":0.075},
	"herbal_spirit_child": {"windup":0.26,"strike":0.12,"recover":0.28,"walk":0.58,"lift":3.0,"reach":9.0,"lean":0.025},
	"sparrow_spirit": {"windup":0.18,"strike":0.09,"recover":0.23,"walk":0.46,"lift":10.0,"reach":12.0,"lean":0.035},
	"foxfire_imp": {"windup":0.24,"strike":0.10,"recover":0.26,"walk":0.42,"lift":7.0,"reach":14.0,"lean":0.045},
	"bear_lord": {"windup":0.34,"strike":0.14,"recover":0.34,"walk":0.68,"lift":2.5,"reach":56.0,"lean":0.065},
}

static func release(profile: Dictionary) -> float:
	return profile.windup + profile.strike * 0.35

static func duration(profile: Dictionary) -> float:
	return profile.windup + profile.strike + profile.recover

static func attack_weight(time: float, profile: Dictionary) -> float:
	var windup: float = profile.windup
	var impact := release(profile)
	var recovery: float = windup + profile.strike
	if time < windup:
		return -0.12 * smoothstep(0, windup, time)
	if time < impact:
		return lerpf(-0.12, 1, smoothstep(windup, impact, time))
	if time < recovery:
		return 1
	return 1 - smoothstep(recovery, duration(profile), time)
