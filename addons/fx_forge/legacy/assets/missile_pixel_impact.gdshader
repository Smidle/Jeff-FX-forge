shader_type spatial;
// 飞弹的像素命中：一张面向镜头的像素贴图（逐帧换贴图，fx_missile_impact.gd 渲染）。
// 命中效果画的是从左边打过来；来势在屏幕上朝左时左右翻转，碎屑仍然顺着来势飞。
// 命中点在贴图里的位置（origin）对准节点位置；整张图往镜头挪一点，打在目标身上时画在目标前面。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform sampler2D pixels : source_color, filter_nearest, repeat_disable;
uniform vec3 direction = vec3(1., 0., 0.);
// 贴图在世界里的宽高（米）
uniform vec2 size = vec2(1.);
// 命中点在贴图里的位置（0~1，左上为原点）
uniform vec2 origin = vec2(.5);
// 往镜头挪多少米
uniform float toward_camera = .35;
uniform float opacity = 1.;

void vertex() {
	vec3 x = INV_VIEW_MATRIX[0].xyz;
	vec3 y = INV_VIEW_MATRIX[1].xyz;
	vec3 z = INV_VIEW_MATRIX[2].xyz;
	vec3 hit = MODEL_MATRIX[3].xyz;
	float flip = dot(direction, x) < 0. ? -1. : 1.;
	vec3 to_camera = PROJECTION_MATRIX[3][3] == 1. ? z : normalize(CAMERA_POSITION_WORLD - hit);
	vec3 center = hit + x * flip * (.5 - origin.x) * size.x + y * (origin.y - .5) * size.y + to_camera * toward_camera;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x * flip * size.x, 0.), vec4(y * size.y, 0.), vec4(z, 0.), vec4(center, 1.));
}

void fragment() {
	vec4 c = texture(pixels, UV);
	if (c.a < .01 || opacity < .01) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * opacity;
}
