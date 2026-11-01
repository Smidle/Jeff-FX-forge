shader_type spatial;
// 分层远景的一层：一张面向参考镜头的平面贴图，不受灯光影响。
// 天空、远山、海面左右镜像延伸（u_range 超出 0~1 的部分按镜像取样），镜头平移、画面更宽时两边不露空；
// fade_top > 0 时贴图最上面这一段渐隐，接到夜空的渐变里；
// fade_side 是左右两端渐隐的宽度（占贴图宽度的比例）：城市贴图的右端是切开的，镜头往右摇时淡入海面，不露切边；
// 烟花炸开时 flash 照亮这一层（flash_gain：海面反光多，远山少）。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 u_range = vec2(0.0, 1.0);
uniform float fade_top = 0.0;
uniform vec2 fade_side = vec2(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 flash = vec3(0.0);
uniform float flash_gain = 1.0;

void fragment() {
	float u = mix(u_range.x, u_range.y, UV.x);
	u = 1.0 - abs(mod(u, 2.0) - 1.0);
	vec4 c = texture(tex, vec2(u, UV.y));
	float a = c.a;
	if (fade_top > 0.0) {
		a *= smoothstep(0.0, fade_top, UV.y);
	}
	if (fade_side.x > 0.0) {
		a *= smoothstep(0.0, fade_side.x, UV.x);
	}
	if (fade_side.y > 0.0) {
		a *= smoothstep(0.0, fade_side.y, 1.0 - UV.x);
	}
	ALBEDO = c.rgb * (tint + flash * flash_gain);
	ALPHA = a;
}
