shader_type sky;
// 夏日花火大会的夜空：地平线附近偏亮的蓝，往天顶渐暗；像素点状的星星缓慢闪烁。
// 地平线以下是远处海面的深蓝（分层远景之间露出的缝隙用它补上）。

uniform vec3 horizon_color : source_color = vec3(0.25, 0.4, 0.63);
uniform vec3 middle_color : source_color = vec3(0.08, 0.16, 0.36);
uniform vec3 zenith_color : source_color = vec3(0.012, 0.022, 0.07);
uniform vec3 below_color : source_color = vec3(0.04, 0.09, 0.18);
// 中间色所在的仰角（EYEDIR.y）
uniform float middle_height = 0.14;
uniform float star_amount = 0.006;
// 烟花炸开时整片天空被照亮一下（脚本每帧设置）
uniform vec3 flash = vec3(0.0);

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	float e = EYEDIR.y;
	vec3 col;
	if (e < 0.0) {
		col = mix(horizon_color, below_color, smoothstep(0.0, 0.08, -e));
	} else if (e < middle_height) {
		col = mix(horizon_color, middle_color, smoothstep(0.0, middle_height, e));
	} else {
		col = mix(middle_color, zenith_color, smoothstep(middle_height, 0.55, e));
	}
	// 星星：把方向分成小格，少数格子中心画一个点；越靠近地平线越少
	vec3 d = EYEDIR * 300.0;
	vec3 cell = floor(d);
	float h = hash(cell);
	if (e > 0.05 && h < star_amount) {
		float dist = length(fract(d) - 0.5);
		float twinkle = 0.55 + 0.45 * sin(TIME * (1.5 + h * 300.0) + h * 900.0);
		float k = (1.0 - smoothstep(0.12, 0.3, dist)) * twinkle * smoothstep(0.05, 0.3, e);
		col += vec3(0.75, 0.8, 1.0) * k;
	}
	COLOR = col + flash * (0.2 + 0.35 * smoothstep(-0.05, 0.4, e));
}
