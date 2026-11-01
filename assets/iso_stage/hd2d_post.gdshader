shader_type canvas_item;
// 等距测试场的画面后期（HD-2D 风格）：画面上下两条移轴模糊 + 暗角。
// 挂在显示 3D 画面的 SubViewportContainer 上，界面不受影响。角色在画面中间，始终清晰。

uniform bool enabled = true;
// 清晰带的中心和半高（0 是屏幕顶部，1 是底部）
uniform float focus_center = 0.5;
uniform float focus_half = 0.2;
// 从清晰到最模糊的过渡距离
uniform float blur_ramp = 0.3;
// 最大模糊半径（画面像素）
uniform float max_blur = 2.6;
uniform float vignette = 0.32;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (!enabled) {
		COLOR = base;
	} else {
		float amount = smoothstep(focus_half, focus_half + blur_ramp, abs(UV.y - focus_center));
		vec2 radius = TEXTURE_PIXEL_SIZE * max_blur * amount;
		vec4 sum = base * 0.2;
		// 两圈采样（8 + 8），近似圆形模糊
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			vec2 dir = vec2(cos(a), sin(a));
			sum += texture(TEXTURE, UV + dir * radius * 0.5) * 0.05;
			sum += texture(TEXTURE, UV + dir.yx * vec2(1.0, -1.0) * radius) * 0.05;
		}
		vec2 centered = UV - 0.5;
		float shade = 1.0 - vignette * smoothstep(0.35, 0.85, length(centered * vec2(1.1, 1.0)));
		COLOR = vec4(sum.rgb * shade, 1.0);
	}
}
