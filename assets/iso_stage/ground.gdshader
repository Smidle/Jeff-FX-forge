shader_type spatial;
// 等距测试场的地面：像素风草地，按线段混出泥土小路和空地。
// 小路边缘按 1/8 米的格子做抖动，看起来像像素画的过渡，而不是平滑渐变。
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_nearest_mipmap, repeat_enable;
// 石板贴图一块的边长（米）
uniform float stone_meters = 3.2;
// 石板的明暗对比压低一些，地面特效看得更清楚
uniform float stone_flatten = 0.3;
// 贴图每米 32 像素，128 像素一块 = 4 米
uniform float tile_meters = 4.0;
// 小路：xy 起点、zw 终点（世界坐标 x/z），宽度（米）
uniform vec4 paths[12];
uniform float path_width[12];
uniform int path_count = 0;
// 泥土空地：xy 中心、z 半径、w 强度
uniform vec4 patches[8];
uniform int patch_count = 0;
// 石板地面：xy 中心、z 半径（铺在泥土上面）
uniform vec4 stones[4];
uniform int stone_count = 0;
// 远处压暗，接到雾里
uniform vec3 far_tint : source_color = vec3(0.78, 0.8, 0.86);
uniform float far_start = 26.0;
uniform float far_end = 70.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 cell = (floor(p * 8.0) + 0.5) / 8.0;
	float wobble = value_noise(cell * 0.8) * 0.7 + value_noise(cell * 2.7) * 0.3 - 0.5;
	float dirt = 0.0;
	for (int i = 0; i < path_count; i++) {
		float d = segment_distance(cell, paths[i].xy, paths[i].zw) - path_width[i];
		dirt = max(dirt, 1.0 - smoothstep(-0.35, 0.45, d + wobble * 0.9));
	}
	for (int i = 0; i < patch_count; i++) {
		float d = length(cell - patches[i].xy) - patches[i].z;
		dirt = max(dirt, (1.0 - smoothstep(-0.5, 0.6, d + wobble * 1.2)) * patches[i].w);
	}
	float paved = 0.0;
	for (int i = 0; i < stone_count; i++) {
		float d = length(cell - stones[i].xy) - stones[i].z;
		paved = max(paved, 1.0 - smoothstep(-0.6, 0.3, d + wobble * 0.8));
	}
	// 按格子抖动成 0/1，边缘是像素块
	float mask = step(hash(cell * 1.37 + 0.11), dirt);
	float stone_mask = step(hash(cell * 2.11 + 0.37), paved);
	vec2 uv = p / tile_meters;
	vec3 grass = texture(grass_tex, uv).rgb;
	vec3 soil = texture(dirt_tex, uv + vec2(0.37, 0.61)).rgb;
	// 大块明暗起伏，打散平铺的重复感
	float macro = value_noise(p * 0.07) * 0.6 + value_noise(p * 0.21) * 0.4;
	grass *= mix(0.82, 1.1, macro);
	soil *= mix(0.9, 1.06, macro);
	vec3 stone = texture(stone_tex, p / stone_meters).rgb;
	stone = mix(stone, vec3(0.6, 0.5, 0.36), stone_flatten) * mix(0.86, 1.0, macro);
	vec3 color = mix(mix(grass, soil, mask), stone, stone_mask);
	float far = smoothstep(far_start, far_end, length(p));
	ALBEDO = color * mix(vec3(1.0), far_tint, far);
	ROUGHNESS = 1.0;
}
