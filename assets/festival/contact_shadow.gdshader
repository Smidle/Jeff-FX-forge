shader_type spatial;
// 人物脚下的影子：贴在地上的椭圆，中间一小团更深（脚和地面接触的地方），往外柔和地变淡。
// 椭圆比脚宽、前后也够深：低角度镜头看过去，影子在脚的两侧和身后都露得出来，人才像踩在地上。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float strength = .55;

void fragment() {
	float d = length(UV - .5) * 2.;
	if (d >= 1.) {
		discard;
	}
	float a = strength * (1. - smoothstep(.45, 1., d)) + .25 * (1. - smoothstep(0., .5, d));
	ALBEDO = vec3(0.);
	ALPHA = clamp(a, 0., 1.);
}
