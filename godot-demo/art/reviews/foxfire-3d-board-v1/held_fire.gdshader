shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// This effect is driven only by the caller's clock. No TIME means pause,
// seeking and deterministic frame capture all keep the exact same flame.
uniform float effect_time = 0.0;
uniform float seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.62;
uniform float wobble : hint_range(0.0, 0.5) = 0.18;
uniform float tip_stretch : hint_range(0.5, 2.5) = 1.65;
uniform vec4 lower_color : source_color = vec4(1.0, 0.44, 0.045, 1.0);
uniform vec4 upper_color : source_color = vec4(0.98, 0.095, 0.012, 1.0);
varying float vertical_fraction;
varying vec3 local_point;

void vertex() {
	float height = VERTEX.y;
	vertical_fraction = clamp((height + 1.0) * 0.5, 0.0, 1.0);
	float tip = pow(max(height, 0.0), 2.0);
	VERTEX.xz *= 1.0 - 0.24 * max(height, 0.0);
	VERTEX.y *= height < 0.0 ? 0.66 : tip_stretch;
	VERTEX.x += sin(effect_time * 4.1 + seed + height * 2.7) * wobble * tip;
	VERTEX.z += cos(effect_time * 3.7 + seed * 1.31 + height * 2.1) * wobble * tip;
	local_point = VERTEX;
}

void fragment() {
	float facing = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 0.42);
	float flow = sin(local_point.y * 10.0 - effect_time * 6.2 + seed + sin(local_point.x * 5.0 + local_point.z * 4.0));
	float warmth = clamp(vertical_fraction * 0.78 + flow * 0.055, 0.0, 1.0);
	vec3 tint = mix(lower_color.rgb, upper_color.rgb, warmth);
	ALBEDO = tint;
	ALPHA = opacity * facing * (0.91 + 0.09 * flow);
}
