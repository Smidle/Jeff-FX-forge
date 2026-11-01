shader_type spatial;
// 弹头的光：一团面向镜头的叠加光（pixelfx 的光缓冲），中心一小团接近白、往外平滑变暗，亮度随时间轻轻闪动。
// 像素画里只有光可以是平滑的渐变；它不画实体像素，叠在弹头后面把周围照亮。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(1., .6, .2, 1.);
uniform vec4 core_color : source_color = vec4(1., .95, .8, 1.);
// 直径（米）
uniform float size = 1.;
uniform float strength = .5;
uniform float flicker = .25;
uniform float effect_time = 0.;
uniform float seed = 0.;
uniform float opacity = 1.;

void vertex() {
	vec3 x = INV_VIEW_MATRIX[0].xyz * size;
	vec3 y = INV_VIEW_MATRIX[1].xyz * size;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x, 0.), vec4(y, 0.), vec4(INV_VIEW_MATRIX[2].xyz, 0.), vec4(MODEL_MATRIX[3].xyz, 1.));
}

void fragment() {
	float d = length(UV - .5) * 2.;
	if (d >= 1. || opacity < .01) {
		discard;
	}
	float t = effect_time;
	float f = 1. - flicker * (.5 + .5 * sin(t * 23. + seed) * sin(t * 9.7 + seed * 1.7));
	float k = strength * f * opacity;
	float glow = pow(1. - d, 2.2) * k;
	float core = pow(max(0., 1. - d * 2.8), 2.) * k;
	ALBEDO = color.rgb * glow + core_color.rgb * core;
	ALPHA = 1.;
}
