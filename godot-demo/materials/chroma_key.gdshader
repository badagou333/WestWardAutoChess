shader_type canvas_item;

// 图像生成器可能把“透明背景”输出成青幕。本材质在运行时将青色转换为透明，
// 既保留角色边缘的抗锯齿，也避免把绿色叶片误删。
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float cyan_strength = min(source.g, source.b) - source.r;
	float cyan_brightness = min(source.g, source.b);
	float key_alpha = 1.0 - smoothstep(0.34, 0.58, cyan_strength) * smoothstep(0.50, 0.78, cyan_brightness);
	COLOR = vec4(source.rgb, source.a * key_alpha);
}

