shader_type spatial;
// 露台草地：草地贴图镜像平铺（接缝不明显），夜色调；烟花炸开时被照亮。
render_mode unshaded, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float tiles = 8.0;
uniform vec3 tint : source_color = vec3(0.3, 0.38, 0.5);
uniform vec3 flash = vec3(0.0);
// 靠近露台边缘的一段变暗（栏杆外是山坡，接到夜色里）
uniform float far_fade = 0.4;
// 变暗的这一段有多宽（占草地长度的比例）
uniform float fade_band = 0.05;

void fragment() {
	vec2 uv = UV * tiles;
	vec2 m = 1.0 - abs(mod(uv, 2.0) - 1.0);
	vec3 c = texture(tex, m).rgb;
	float dark = mix(1.0 - far_fade, 1.0, smoothstep(0.0, fade_band, UV.y));
	ALBEDO = c * (tint + flash * 0.55) * dark;
}
