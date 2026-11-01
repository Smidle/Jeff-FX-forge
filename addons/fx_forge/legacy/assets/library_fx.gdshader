shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Opt-in library material. Existing recipes continue using pixel_fx.gdshader.
// All motion is driven by the instance clock: deliberately no shader TIME.
uniform sampler2D mask_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D smooth_texture : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 secondary_tint : source_color = vec4(0.4, 0.65, 0.8, 1.0);
uniform bool palette_hue_shift = false;
uniform vec4 palette_reference : source_color = vec4(1.0);
uniform vec4 palette_target : source_color = vec4(1.0);
uniform bool face_camera = true;
uniform bool face_path_axis = false;
uniform bool particle = false;
uniform bool field = false;
uniform bool ground_particle = false;
uniform bool hard_edge = false;
uniform int atlas_frames = 1;
uniform int atlas_columns = 1;
uniform int atlas_rows = 1;
uniform float shape_angle = 0.0;
uniform float shape_frame = 0.0;
uniform float animation_cycles = 1.0;
uniform bool animation_loop = false;
uniform float arc_span = 6.2831853;
uniform int branch_count = -1;
uniform int motif_count = -1;
uniform int material_mode = 0;
uniform int pattern = 0;
uniform int pixel_grid = 96;
uniform vec2 pattern_aspect = vec2(1.0);
uniform int pattern_count = 6;
uniform float pattern_detail = 0.65;
uniform float pattern_motion = 1.0;
uniform float pattern_width = 0.5;
uniform float pattern_variation = 0.4;
uniform float pattern_phase = 0.0;
uniform float pattern_seed = 42.0;
uniform float effect_time = 0.0;
uniform float effect_duration = 1.0;
uniform bool looping = false;
varying vec4 instance_tint;
varying vec2 effect_uv;
varying float atlas_index;
varying float particle_phase;

const float PI_FX = 3.14159265359;
const float TAU_FX = 6.28318530718;

vec2 rotate_fx(vec2 point, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, s), vec2(-s, c)) * point;
}

float hash_fx(vec2 value) {
	return fract(sin(dot(value + vec2(pattern_seed * 0.013, pattern_seed * 0.007), vec2(127.1, 311.7))) * 43758.5453);
}

float noise_fx(vec2 value) {
	vec2 cell = floor(value);
	vec2 f = fract(value);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_fx(cell), hash_fx(cell + vec2(1.0, 0.0)), f.x), mix(hash_fx(cell + vec2(0.0, 1.0)), hash_fx(cell + vec2(1.0)), f.x), f.y);
}

float edge_fx(float distance_value) {
	float edge = material_mode == 1 ? 0.0015 : 0.006;
	return 1.0 - smoothstep(-edge, edge, distance_value);
}

float disc_fx(vec2 point, float radius) {
	return edge_fx(length(point) - radius);
}

float line_fx(vec2 point, vec2 a, vec2 b, float width) {
	vec2 delta = b - a;
	float along = clamp(dot(point - a, delta) / max(dot(delta, delta), 0.000001), 0.0, 1.0);
	return edge_fx(length(point - a - along * delta) - width);
}

float ring_fx(vec2 point, float radius, float width) {
	return edge_fx(abs(length(point) - radius) - width);
}

// Coverage and palette position; front layers keep their own tone.
vec2 over_fx(vec2 under, float coverage, float tone) {
	coverage = clamp(coverage, 0.0, 1.0);
	float alpha = coverage + under.x * (1.0 - coverage);
	return vec2(alpha, (tone * coverage + under.y * under.x * (1.0 - coverage)) / max(alpha, 0.00001));
}

float star_fx(vec2 point, float radius, float rotation) {
	float angle = atan(point.y, point.x) - rotation;
	float radial = radius * (0.45 + 0.55 * pow(0.5 + 0.5 * cos(angle * 5.0), 1.8));
	return edge_fx(length(point) - radial);
}

vec2 spring_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	vec2 pool = vec2(point.x, (point.y - 0.29) * 2.8);
	float opening = looping ? 1.0 : smoothstep(0.0, 0.22, phase);
	float radius = 0.20 + 0.055 * sin(clock * 2.2);
	result = over_fx(result, ring_fx(pool, radius * opening, 0.008 + pattern_width * 0.010) * 0.68, 0.45);
	result = over_fx(result, ring_fx(pool, (radius + 0.07) * opening, 0.004) * pattern_detail * 0.55, 0.78);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 3.2));
		float drift = (fi / max(float(pattern_count - 1), 1.0) - 0.5) * 0.48;
		float travel = fract(clock * (0.50 + h * 0.16 * pattern_variation) + fi * 0.618);
		vec2 droplet = vec2(drift * (0.5 + 0.5 * travel) + sin(travel * 4.3 + fi) * 0.025 * pattern_variation, 0.26 - travel * 0.66);
		float taper = sin(travel * PI_FX) * (looping ? 1.0 : 1.0 - smoothstep(0.61 + h * 0.14, 0.98, phase));
		float width = (0.005 + pattern_width * 0.008) * (0.45 + taper * 0.55);
		float streak = line_fx(point, droplet + vec2(0.012 * sin(fi), 0.052), droplet, width);
		result = over_fx(result, streak * taper * opening, 0.78 + 0.15 * h);
		if (pattern_detail > 0.25) {
			vec2 bead = droplet + vec2(sin(fi + clock) * 0.06, -0.045);
			result = over_fx(result, disc_fx(point - bead, 0.007) * taper * pattern_detail, 1.0);
		}
	}
	// Two opposed ribbons give the spring a readable body without filling the
	// character's center. Their highlights follow the same continuous clock.
	float stem_y = clamp((0.29 - point.y) / 0.65, 0.0, 1.0);
	float ribbon_life = sin(stem_y * PI_FX);
	for (int side_index = 0; side_index < 2; side_index++) {
		float side = side_index == 0 ? -1.0 : 1.0;
		float bend = side * (0.065 + stem_y * 0.055) + sin(stem_y * 6.0 - clock * 2.1 + side) * 0.035 * pattern_variation;
		float width = (0.008 + pattern_width * 0.026) * ribbon_life;
		float withdraw = looping ? 0.0 : smoothstep(0.62 + float(side_index) * 0.07, 1.0, phase);
		float taper_out = smoothstep(withdraw - 0.08, withdraw + 0.08, stem_y);
		float ribbon = edge_fx(abs(point.x - bend) - width) * step(-0.36, point.y) * step(point.y, 0.29) * opening * taper_out;
		result = over_fx(result, ribbon * 0.66, 0.16 + 0.13 * stem_y);
		float middle = edge_fx(abs(point.x - bend) - width * 0.58);
		result = over_fx(result, middle * ribbon * 0.85, 0.62);
		float crest = edge_fx(abs(point.x - bend + side * width * 0.25) - width * 0.17);
		float shine = 0.55 + 0.45 * smoothstep(0.1, 0.9, sin(stem_y * 8.0 - clock * 3.0 + side));
		result = over_fx(result, crest * ribbon * pattern_detail * shine, 1.0);
	}
	float basin = disc_fx(pool, radius * opening) * 0.12 * opening;
	return over_fx(result, basin, 0.55);
}

vec2 laser_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	vec2 muzzle = point - vec2(-0.31, 0.0);
	float charging = (1.0 - smoothstep(0.30, 0.42, phase)) * smoothstep(0.0, 0.12, phase);
	float firing = smoothstep(0.24, 0.30, phase) * (1.0 - smoothstep(0.72, 0.96, phase));
	float charge_radius = 0.12 * (1.0 - phase * 1.4);
	result = over_fx(result, ring_fx(muzzle, max(0.028, charge_radius), 0.009) * charging, 0.70);
	result = over_fx(result, disc_fx(muzzle, 0.017 + phase * 0.065) * charging, 1.0);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count || pattern_detail <= 0.001 || charging <= 0.001) { break; }
		float fi = float(i);
		float angle = fi * TAU_FX / float(pattern_count) + clock * 1.4 + (hash_fx(vec2(fi, 7.8)) - 0.5) * pattern_variation;
		vec2 direction = vec2(cos(angle), sin(angle));
		float radius = 0.07 + fract(1.0 - clock * 1.5 + fi * 0.27) * 0.14;
		result = over_fx(result, line_fx(muzzle, direction * radius, direction * (radius + 0.025), 0.004) * charging * pattern_detail, 0.88);
	}
	float front = mix(-0.27, 0.45, smoothstep(0.25, 0.34, phase));
	float along = clamp((point.x + 0.31) / 0.76, 0.0, 1.0);
	float thickness = (0.012 + pattern_width * 0.065) * (0.35 + 0.65 * pow(max(0.0, sin(along * PI_FX)), 0.55));
	float wiggle = sin(point.x * 48.0 - clock * 13.0) * 0.006 * pattern_variation;
	float beam = step(-0.31, point.x) * step(point.x, front) * edge_fx(abs(point.y + wiggle) - thickness * firing);
	result = over_fx(result, beam * firing, 0.42);
	result = over_fx(result, beam * edge_fx(abs(point.y) - thickness * 0.27) * firing, 1.0);
	float rails = edge_fx(abs(abs(point.y) - thickness * 1.8) - 0.004) * step(-0.2, point.x) * step(point.x, front - 0.03);
	result = over_fx(result, rails * firing * pattern_detail, 0.78);
	float impact = disc_fx(point - vec2(front, 0.0), 0.022 + 0.038 * firing);
	return over_fx(result, impact * firing, 1.0);
}

vec2 flame_sigil_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float angle = atan(point.y, point.x);
	float bloom = looping ? 1.0 : smoothstep(0.03, 0.36, phase);
	float ring_radius = mix(0.08, 0.22, bloom);
	float ring_life = looping ? 1.0 : 1.0 - smoothstep(0.78, 1.0, phase);
	float broken = step(0.22, fract((angle / TAU_FX + 1.0) * float(pattern_count) - clock * 0.10));
	result = over_fx(result, ring_fx(point, ring_radius, 0.0045) * broken * ring_life * 0.65, 0.86);
	result = over_fx(result, ring_fx(point, ring_radius * 0.71, 0.0025) * pattern_detail * ring_life * 0.55, 0.98);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 5.8));
		float direction = fi * TAU_FX / float(pattern_count) + clock * 0.30 + (h - 0.5) * pattern_variation * 0.43;
		vec2 q = rotate_fx(point, -direction);
		float extent = 0.16 + h * 0.06;
		float u = clamp((q.x - ring_radius * 0.61) / extent, 0.0, 1.0);
		float curl = u * u * (0.04 + pattern_variation * 0.065) + sin(u * 4.0 - clock * 2.3 + fi) * 0.018 * u;
		float width = (0.015 + 0.060 * pattern_width) * pow(max(0.0, sin(u * PI_FX)), 1.1) * bloom * (0.65 + h * 0.5);
		float life = looping ? 1.0 : 1.0 - smoothstep(0.58 + h * 0.16, 0.93, phase);
		float gate = step(ring_radius * 0.61, q.x) * step(q.x, ring_radius * 0.61 + extent);
		float tongue = edge_fx(abs(q.y - curl) - width) * gate;
		if (tongue > 0.001) {
			float brush = noise_fx(vec2(q.x * 42.0 - clock * 0.6, q.y * 85.0) + fi);
			float dry = 0.5 + 0.5 * smoothstep(0.16, 0.72, brush);
			result = over_fx(result, tongue * life * dry * 0.70, 0.08 + u * 0.43);
			float core = edge_fx(abs(q.y - curl + width * 0.20) - width * 0.24) * gate;
			result = over_fx(result, core * life * dry * (1.0 - u * 0.25), 0.85 + u * 0.15);
		}
		float flight = looping ? fract(clock * 0.48 + fi * 0.27) : clamp((phase - 0.38 - h * 0.12) / 0.58, 0.0, 1.0);
		vec2 spark = vec2(cos(direction + 0.28), sin(direction + 0.28)) * (0.24 + flight * 0.19);
		float spark_life = sin(flight * PI_FX);
		result = over_fx(result, disc_fx(point - spark, 0.004 + 0.003 * h) * pattern_detail * spark_life, 1.0);
	}
	return result;
}

vec2 bouncing_star_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float travel = smoothstep(0.02, 0.88, phase);
	float bounce = abs(sin(travel * PI_FX * 2.0));
	vec2 center = vec2(mix(-0.30, 0.29, travel), 0.19 - bounce * 0.46);
	float squash = 0.72 + 0.28 * smoothstep(0.0, 0.25, bounce);
	vec2 q = point - center;
	q *= vec2(squash, 1.0 / squash);
	float radius = 0.09 + pattern_width * 0.065;
	float turn = travel * TAU_FX * (0.5 + pattern_variation) + (hash_fx(vec2(9.0, 4.0)) - 0.5) * 0.35;
	for (int i = 0; i < 4; i++) {
		if (pattern_detail <= 0.001) { break; }
		float lag = 0.028 * float(i + 1);
		float old = max(0.0, travel - lag);
		vec2 past = vec2(mix(-0.30, 0.29, old), 0.19 - abs(sin(old * PI_FX * 2.0)) * 0.46);
		result = over_fx(result, star_fx(point - past, radius * (0.7 - float(i) * 0.10), turn - lag * 6.0) * (0.24 - float(i) * 0.035) * pattern_detail, 0.38);
	}
	result = over_fx(result, star_fx(q, radius + 0.012, turn), 0.05);
	result = over_fx(result, star_fx(q, radius, turn), 0.78);
	result = over_fx(result, star_fx(q + vec2(0.02, 0.025), radius * 0.40, turn), 1.0);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count || pattern_detail <= 0.001) { break; }
		float fi = float(i);
		float angle = fi * TAU_FX / float(pattern_count) + 0.3;
		float burst = fract(travel * 2.0);
		float activation = smoothstep(0.0, 0.07, burst) * (1.0 - smoothstep(0.15, 0.42, burst));
		vec2 at = vec2(mix(-0.30, 0.29, floor(travel * 2.0) * 0.5), 0.22) + vec2(cos(angle), sin(angle) * 0.45) * burst * 0.7;
		result = over_fx(result, star_fx(point - at, 0.018 * (1.0 - burst), fi) * activation * pattern_detail, 0.90);
	}
	return result;
}

vec2 ink_lotus_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float opening = looping ? 0.9 + 0.1 * sin(clock * 0.7) : smoothstep(0.03, 0.67, phase);
	vec2 origin = vec2(0.0, 0.25);
	// Separated elliptical arcs suggest water; the former straight baseline is gone.
	for (int r = 0; r < 2; r++) {
		float fr = float(r);
		vec2 water = vec2(point.x + fr * 0.025, (point.y - 0.29) * (3.8 + fr));
		float angle = atan(water.y, water.x);
		float gap = smoothstep(0.2, 0.55, sin(angle * 2.0 + fr * 2.3));
		float radius = (0.22 + fr * 0.09) * (0.70 + opening * 0.3);
		result = over_fx(result, ring_fx(water, radius, 0.0035) * gap * opening * 0.45, 0.38);
	}
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 31.0));
		float side = fi / max(float(pattern_count - 1), 1.0) * 2.0 - 1.0;
		float unfurl = smoothstep(h * 0.12, 0.70, opening);
		float angle = side * (0.24 + unfurl * 0.83) + (h - 0.5) * 0.24 * pattern_variation;
		vec2 q = rotate_fx(point - origin - vec2(side * 0.012, 0.0), angle);
		float height = (0.42 - abs(side) * 0.10 + (h - 0.5) * 0.07) * (0.54 + unfurl * 0.46);
		float u = clamp(-q.y / max(height, 0.001), 0.0, 1.0);
		float width = (0.022 + pattern_width * 0.045) * pow(max(0.0, sin(u * PI_FX)), 0.9) * (0.75 + h * 0.42);
		if (q.y < -height || q.y > 0.0 || abs(q.x) > width + 0.01) { continue; }
		float grain = noise_fx(vec2(q.x * 95.0, q.y * 16.0) + fi * 2.4);
		float dry = smoothstep(0.20, 0.68, grain + (1.0 - u) * 0.12);
		float petal = edge_fx(abs(q.x) - width);
		float rim = smoothstep(0.45, 1.0, abs(q.x) / max(width, 0.001));
		float wash = (0.10 + rim * 0.47 + (1.0 - u) * 0.18) * mix(1.0, dry, 0.45 + pattern_variation * 0.5);
		result = over_fx(result, petal * wash * unfurl, 0.10 + u * 0.45 + h * 0.10);
		float vein = line_fx(q, vec2(-0.002, -height * 0.84), vec2(0, -0.025), 0.0018);
		result = over_fx(result, vein * petal * dry * pattern_detail * 0.45, 0.10);
	}
	return result;
}

vec2 stone_dust_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float h = hash_fx(vec2(fi, 4.0));
		float age = clamp((phase - h * 0.14) / (0.84 - h * 0.08), 0.0, 1.0);
		float fade = smoothstep(0.0, 0.13, age) * (1.0 - smoothstep(0.35, 1.0, age));
		float side = fi / 4.0 * 2.0 - 1.0;
		vec2 at = vec2(side * (0.035 + age * 0.25) + sin(age * 3.0 + h * 6.0) * 0.022, 0.27 - age * (0.15 + h * 0.21));
		vec2 cloud = (point - at) / vec2(0.80 + h * 0.24, 0.85 + (1.0 - h) * 0.35);
		float radius = (0.028 + sqrt(age) * (0.065 + pattern_width * 0.075)) * (0.78 + h * 0.35);
		float d = length(cloud) / max(radius, 0.001);
		if (d < 1.3 && fade > 0.001) {
			float billow = noise_fx(cloud * 24.0 + vec2(fi * 3.0, clock * -0.10));
			float shape = 1.0 - smoothstep(0.15, 1.0 + (billow - 0.5) * 0.55, d);
			float holes = 0.30 + 0.70 * smoothstep(0.18, 0.72, noise_fx(point * 15.0 + fi * 4.6));
			float alpha = shape * holes * fade * (0.20 + pattern_detail * 0.28);
			float light = clamp(0.34 + (-cloud.y / radius) * 0.20 + billow * 0.12, 0.14, 0.68);
			result = over_fx(result, alpha, light);
		}
	}
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 2.0));
		float horizontal = (h - 0.5) * (0.28 + pattern_variation * 0.40);
		float ballistic = min(phase * 1.65, 1.0);
		float rise = max(0.0, (0.18 + h * 0.17) * ballistic - 0.72 * ballistic * ballistic);
		vec2 at = vec2(horizontal * (1.0 - pow(1.0 - ballistic, 2.0)), 0.27 - rise);
		vec2 q = rotate_fx(point - at, fi * 2.3);
		float radius = (0.003 + h * 0.007) * (0.70 + pattern_width * 0.5);
		float rock = edge_fx(max(abs(q.x) * 0.80 + abs(q.y) * 0.50, abs(q.y) * 1.25 - q.x * 0.20) - radius);
		float lifespan = smoothstep(0.0, 0.025, phase) * (1.0 - smoothstep(0.25, 0.52, phase));
		result = over_fx(result, rock * lifespan, q.x + q.y < 0.0 ? 0.62 : 0.19);
	}
	return result;
}

// Staggered crystal ridge: every spike has a separate emergence and facet.
vec2 crystal_spikes_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 17.0));
		float unit = (fi + 0.5) / float(pattern_count);
		float side = unit * 2.0 - 1.0;
		float hero = pow(1.0 - abs(side), 1.5);
		float start = abs(side) * 0.17 + h * 0.06;
		float grow = smoothstep(start, start + 0.23, phase);
		float sink = 1.0 - smoothstep(0.78 + h * 0.04, 1.0, phase);
		vec2 base = vec2(side * 0.35 + (h - 0.5) * 0.025, 0.28 + (h - 0.5) * 0.025);
		vec2 q = rotate_fx(point - base, side * (0.14 + h * 0.24) * pattern_variation);
		float height = (0.15 + hero * 0.36 + h * 0.11 * pattern_variation) * grow * sink;
		float width = (0.014 + pattern_width * 0.038) * (0.55 + hero * 0.95 + h * 0.25) * min(1.0, 9.0 / float(pattern_count));
		float u = clamp(-q.y / max(height, 0.001), 0.0, 1.0);
		float cap = u < 0.68 ? 0.72 + u * 0.30 : (1.0 - u) / 0.32;
		float silhouette = edge_fx(abs(q.x) - width * cap) * step(-height, q.y) * step(q.y, 0.0) * grow * sink;
		float seam = width * (0.12 - u * 0.28);
		float facet = q.x < seam ? 0.20 + h * 0.13 : 0.69;
		if (u > 0.68) { facet = q.x < seam ? 0.48 : 0.96; }
		result = over_fx(result, silhouette * (0.75 + hero * 0.25), facet);
		float ridge = edge_fx(abs(q.x - seam) - 0.0025) * silhouette;
		result = over_fx(result, ridge * pattern_detail, 1.0);
		vec2 chip = point - base - vec2(width * 0.7, 0.006);
		float rubble = edge_fx(abs(chip.x) + abs(chip.y) * 1.8 - width * 0.85);
		result = over_fx(result, rubble * grow * sink * pattern_detail * 0.8, 0.38);
	}
	return result;
}

// Square floor fragments ascend in staggered arcs and contract into a portal.
vec2 portal_tiles_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float opening = smoothstep(0.0, 0.16, phase);
	float closing = 1.0 - smoothstep(0.78, 1.0, phase);
	vec2 floor_point = vec2(point.x, (point.y - 0.29) * 3.2);
	float diamond = abs(floor_point.x) + abs(floor_point.y);
	result = over_fx(result, edge_fx(abs(diamond - 0.31 * opening) - 0.006) * closing, 0.6);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 22.0));
		float angle = fi * TAU_FX / float(pattern_count);
		float delay = (0.04 + h * 0.20) * (0.4 + pattern_variation * 0.6);
		float lift = clamp((phase - delay) / 0.62, 0.0, 1.0);
		float squeeze = 1.0 - smoothstep(0.28, 1.0, lift);
		vec2 base = vec2(cos(angle) * 0.29, 0.29 + sin(angle) * 0.075);
		vec2 center = vec2(base.x * squeeze, base.y - lift * 0.59);
		float scale = (0.010 + pattern_width * 0.025) * (1.0 - lift * 0.66);
		vec2 q = rotate_fx(point - center, 0.785398 + lift * (h - 0.5) * 2.0);
		float square = edge_fx(max(abs(q.x), abs(q.y)) - scale);
		float visible = smoothstep(0.0, 0.05, lift) * (1.0 - smoothstep(0.82, 1.0, lift));
		if (pattern_detail > 0.001) {
			float beam = line_fx(point, center + vec2(0.0, 0.065 * lift), center, 0.0025) * visible * pattern_detail;
			result = over_fx(result, beam * 0.45, 0.62);
		}
		result = over_fx(result, square * visible, q.y < -scale * 0.35 ? 1.0 : 0.57);
	}
	return result;
}

// Thin arc shell, with light travelling around the contour rather than filling it.
vec2 aegis_shell_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float open = looping ? 1.0 : smoothstep(0.0, 0.22, phase);
	vec2 q = vec2(point.x / 0.78, point.y + 0.035);
	float radius = 0.38 * (0.84 + 0.16 * open);
	float distance_value = length(q);
	float angle = atan(q.y, q.x);
	float inside = 1.0 - smoothstep(radius - 0.008, radius, distance_value);
	float bottom = 1.0 - smoothstep(0.26, 0.30, point.y);
	float rim_width = 0.0025 + 0.006 * pattern_width;
	float left_light = pow(max(0.0, cos(angle + 2.0)), 4.0);
	float right_light = pow(max(0.0, cos(angle - 0.25)), 8.0) * 0.65;
	float light = 0.12 + left_light * 0.68 + right_light;
	// A translucent surface spans the shell, with a broad upper-left reflection.
	float fresnel = pow(clamp(distance_value / radius, 0.0, 1.0), 3.0);
	float reflection = exp(-pow((q.x + 0.16 + q.y * 0.34) / 0.10, 2.0)) * (1.0 - smoothstep(0.05, 0.26, q.y));
	result = over_fx(result, inside * bottom * open * (0.025 + 0.09 * fresnel + reflection * 0.10), 0.38 + reflection * 0.44);
	result = over_fx(result, ring_fx(q, radius, rim_width) * bottom * light * open, 0.90);
	// Broad, sparse swept glints avoid high-frequency concentric interference.
	if (pattern_detail > 0.001) {
		for (int i = 0; i < 16; i++) {
			if (i >= pattern_count) { break; }
			float fi = float(i);
			float h = hash_fx(vec2(fi, 26.0));
			float travel = fract(clock * (0.09 + h * 0.045 * pattern_variation) + fi / float(pattern_count));
			float curve_x = mix(-0.34, 0.34, travel) + sin(q.y * 4.0 + fi) * 0.035;
			float glint = exp(-pow((q.x - curve_x) / 0.012, 2.0)) * inside * bottom;
			float cap = smoothstep(0.0, 0.15, travel) * (1.0 - smoothstep(0.75, 1.0, travel));
			result = over_fx(result, glint * cap * pattern_detail * 0.15, 0.77);
		}
	}
	vec2 foot = vec2(point.x, (point.y - 0.285) * 4.0);
	float footprint = ring_fx(foot, 0.20, 0.0035) * step(point.x, 0.1);
	return over_fx(result, footprint * open * 0.22, 0.63);
}

// A chain of round soap bubbles crosses the card and breaks at its leading end.
vec2 bubble_shot_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 33.0));
		float delay = fi / max(float(pattern_count - 1), 1.0) * 0.52;
		float travel = clamp((phase - delay) / 0.45, 0.0, 1.0);
		vec2 center = vec2(mix(-0.36, 0.36, travel), sin(travel * PI_FX * 2.0 + fi * 1.7) * 0.065 * pattern_variation);
		float radius = (0.022 + h * 0.018) * (0.70 + pattern_width) * (1.0 + 0.12 * sin(travel * 10.0));
		float present = smoothstep(0.0, 0.055, travel) * (1.0 - smoothstep(0.80, 0.92, travel));
		vec2 q = (point - center) * vec2(pattern_aspect.x / max(pattern_aspect.y, 0.01), 1.0);
		result = over_fx(result, disc_fx(q, radius) * present * 0.065, 0.60);
		result = over_fx(result, (1.0 - smoothstep(0.002, 0.0055, abs(length(q) - radius))) * present, 0.80);
		float highlight = ring_fx(q, radius * 0.70, 0.004) * step(q.x + q.y, -radius * 0.28);
		result = over_fx(result, highlight * present * pattern_detail, 1.0);
		float pop = smoothstep(0.81, 0.88, travel) * (1.0 - smoothstep(0.90, 1.0, travel));
		float broken = step(0.64, fract(atan(q.y, q.x) * 0.95 + h));
		result = over_fx(result, ring_fx(q, radius * (1.0 + (travel - 0.8) * 5.0), 0.002) * broken * pop, 0.78);
	}
	return result;
}

// Separate vertical brush strokes form a porous cage, retaining a readable center.
vec2 brush_prison_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float opening = smoothstep(0.0, 0.20, phase);
	float dissolve = 1.0 - smoothstep(0.70, 1.0, phase);
	vec2 ground = vec2(point.x, (point.y - 0.28) * 3.8);
	float angle_at_floor = atan(ground.y, ground.x);
	float broken = smoothstep(-0.15, 0.45, sin(angle_at_floor * 3.0 + 0.8));
	float floor_ink = ring_fx(ground, 0.29, 0.006 + pattern_width * 0.006) * broken;
	result = over_fx(result, floor_ink * opening * dissolve * 0.38, 0.24);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 41.0));
		float angle = fi * TAU_FX / float(pattern_count) + 0.18;
		float depth = sin(angle);
		vec2 root = vec2(cos(angle) * 0.29, 0.28 + depth * 0.055);
		float grow = smoothstep(h * 0.14, 0.40 + h * 0.10, phase);
		float height = (0.45 + (h - 0.5) * 0.22 * pattern_variation) * grow;
		vec2 q = point - root;
		float u = clamp(-q.y / max(height, 0.001), 0.0, 1.0);
		float bend = sin(u * 2.8 + fi) * 0.024 * pattern_variation;
		float width = (0.007 + 0.019 * pattern_width) * (1.0 - u * 0.48) * (0.65 + h * 0.6);
		float pressure = 0.60 + 0.40 * sin(u * PI_FX);
		float stroke = edge_fx(abs(q.x - bend) - width * pressure) * step(-height, q.y) * step(q.y, 0.0);
		float ink_depth = depth > 0.0 ? 0.65 : 0.36;
		if (stroke > 0.001) {
			float dry = smoothstep(0.23, 0.66, noise_fx(vec2(q.x * 120.0, q.y * 9.0) + fi * 2.3));
			result = over_fx(result, stroke * (0.18 + dry * 0.82) * dissolve * ink_depth, 0.12 + u * 0.20);
		}
		float segment = u * (2.0 + floor(h * 2.0));
		float joint = 1.0 - smoothstep(0.015, 0.055, abs(fract(segment) - 0.45));
		float band = edge_fx(abs(q.x - bend) - width * 1.35) * joint * step(-height, q.y) * step(q.y, 0.0);
		result = over_fx(result, band * dissolve * pattern_detail * ink_depth, 0.10);
		if (pattern_detail > 0.001) {
			vec2 leaf_origin = root + vec2(sin(fi + 1.7) * 0.016, -height * 0.68);
			vec2 leaf = rotate_fx(point - leaf_origin, (h - 0.5) * 1.6 + 0.7);
			float leaf_u = clamp(leaf.x / 0.085, 0.0, 1.0);
			float leaf_shape = edge_fx(abs(leaf.y) - 0.010 * sin(leaf_u * PI_FX)) * step(0.0, leaf.x) * step(leaf.x, 0.085);
			result = over_fx(result, leaf_shape * grow * dissolve * pattern_detail * ink_depth, 0.18);
		}
	}
	return result;
}

// Directional ballistic metal sparks cool from white to amber; gravity bends tails.
vec2 metal_sparks_fx(vec2 point, float phase, float clock) {
	vec2 result = vec2(0.0);
	float progress = clamp(phase * 1.12, 0.0, 1.0);
	for (int i = 0; i < 16; i++) {
		if (i >= pattern_count) { break; }
		float fi = float(i);
		float h = hash_fx(vec2(fi, 48.0));
		float speed = 0.45 + h * 0.35;
		float angle = -0.25 + (hash_fx(vec2(fi, 9.0)) - 0.5) * (0.18 + pattern_variation * 1.15);
		vec2 velocity = vec2(cos(angle), sin(angle)) * speed;
		vec2 origin = vec2(-0.32, 0.04);
		float lag = mix(0.10, 0.018, progress);
		float old = max(0.0, progress - lag);
		vec2 head = origin + velocity * progress + vec2(0.0, 0.26 * progress * progress);
		vec2 tail = origin + velocity * old + vec2(0.0, 0.26 * old * old);
		float life = smoothstep(0.0, 0.025, phase) * (1.0 - smoothstep(0.40 + h * 0.22, 0.78 + h * 0.18, phase));
		float width = (0.0009 + pattern_width * 0.0032) * (0.6 + h * 0.4);
		result = over_fx(result, line_fx(point, tail, head, width * 1.8) * life * 0.5, 0.36 + (1.0 - progress) * 0.35);
		result = over_fx(result, line_fx(point, mix(tail, head, 0.45), head, width) * life, mix(0.98, 0.35, progress));
		result = over_fx(result, disc_fx(point - head, width * 1.5) * life * pattern_detail, 1.0 - progress * 0.45);
	}
	return result;
}

vec3 to_hsv_fx(vec3 color) {
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float delta = high - low;
	float hue = 0.0;
	if (delta > 0.00001) {
		if (high == color.r) { hue = (color.g - color.b) / delta; }
		else if (high == color.g) { hue = 2.0 + (color.b - color.r) / delta; }
		else { hue = 4.0 + (color.r - color.g) / delta; }
	}
	return vec3(fract(hue / 6.0 + 1.0), high > 0.00001 ? delta / high : 0.0, high);
}

vec3 from_hsv_fx(vec3 color) {
	vec3 sectors = mod(color.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0);
	vec3 channels = clamp(abs(sectors - 3.0) - 1.0, 0.0, 1.0);
	return color.z * mix(vec3(1.0), channels, color.y);
}

void vertex() {
	effect_uv = UV;
	float phase = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	particle_phase = phase;
	float fade = mix(0.5, 1.0, min(phase / 0.15, 1.0)) * (1.0 - smoothstep(0.65, 1.0, phase));
	instance_tint = vec4(1.0, 1.0, 1.0, particle ? fade : 1.0);
	if (field) { instance_tint.a = INSTANCE_CUSTOM.y; }
	if (face_path_axis) {
		vec3 axis = normalize(MODEL_MATRIX[0].xyz);
		vec3 side = cross(INV_VIEW_MATRIX[2].xyz, axis);
		if (length(side) < 0.001) { side = MODEL_MATRIX[1].xyz; }
		side = normalize(side) * length(MODEL_MATRIX[1].xyz);
		vec3 normal = normalize(cross(axis, side)) * length(MODEL_MATRIX[2].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MODEL_MATRIX[0], vec4(side, 0.0), vec4(normal, 0.0), MODEL_MATRIX[3]);
	} else if (face_camera) {
		vec3 sizes = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sizes.x, INV_VIEW_MATRIX[1] * sizes.y, INV_VIEW_MATRIX[2] * sizes.z, MODEL_MATRIX[3]);
		float angle = particle ? INSTANCE_CUSTOM.x : shape_angle;
		VERTEX.xy = rotate_fx(VERTEX.xy, angle);
	}
	if (ground_particle) { VERTEX = vec3(VERTEX.x, 0.0, -VERTEX.y); }
	float progress = animation_loop ? fract(phase * animation_cycles) : min(phase * animation_cycles, 0.9999);
	atlas_index = field ? INSTANCE_CUSTOM.z : (particle ? floor(progress * float(atlas_frames)) : shape_frame);
}

void fragment() {
	vec2 centered = effect_uv - vec2(0.5);
	float angle = mod(atan(centered.y, centered.x) + PI_FX, TAU_FX);
	if (angle > arc_span) { discard; }
	vec4 sample_color;
	if (pattern == 0) {
		if (branch_count >= 0 && abs(centered.x) > 0.16) {
			if (branch_count == 0 || (branch_count == 1 && centered.x > 0.0)) { discard; }
		}
		if (motif_count >= 0 && length(centered) > 0.14 && length(centered) < 0.37) {
			float sector = floor(mod(atan(centered.y, centered.x) + 2.0943951, TAU_FX) / 1.04719755);
			if (floor((sector + 1.0) * float(motif_count) / 6.0) == floor(sector * float(motif_count) / 6.0)) { discard; }
		}
		vec2 grid = vec2(float(max(atlas_columns, 1)), float(max(atlas_rows, 1)));
		float frame = clamp(floor(atlas_index), 0.0, max(1.0, min(float(atlas_frames), grid.x * grid.y)) - 1.0);
		vec2 cell = vec2(mod(frame, grid.x), floor(frame / grid.x));
		vec2 atlas_uv = (effect_uv + cell) / grid;
		vec4 sampled;
		if (material_mode == 2) {
			vec2 half_texel = min(0.5 / max(vec2(textureSize(smooth_texture, 0)), vec2(1.0)), 0.5 / grid);
			atlas_uv = clamp(atlas_uv, cell / grid + half_texel, (cell + vec2(1.0)) / grid - half_texel);
			sampled = texture(smooth_texture, atlas_uv);
		} else {
			// UV=1 must not select the neighbouring cell even with nearest sampling.
			vec2 half_texel = min(0.5 / max(vec2(textureSize(mask_texture, 0)), vec2(1.0)), 0.5 / grid);
			atlas_uv = clamp(atlas_uv, cell / grid + half_texel, (cell + vec2(1.0)) / grid - half_texel);
			sampled = texture(mask_texture, atlas_uv);
		}
		if (palette_hue_shift) {
			vec3 pixel = to_hsv_fx(sampled.rgb);
			vec3 reference = to_hsv_fx(palette_reference.rgb);
			vec3 target = to_hsv_fx(palette_target.rgb);
			pixel.x = fract(pixel.x + target.x - reference.x + 1.0);
			pixel.y = clamp(pixel.y * target.y / max(reference.y, 0.001), 0.0, 1.0);
			pixel.z *= target.z / max(reference.z, 0.001);
			sampled.rgb = from_hsv_fx(pixel);
		}
		sample_color = sampled * tint * instance_tint;
	} else {
		vec2 coordinates = effect_uv;
		if (material_mode == 1) {
			vec2 grid = max(vec2(8.0), float(pixel_grid) * pattern_aspect / max(pattern_aspect.x, pattern_aspect.y));
			coordinates = (floor(coordinates * grid) + vec2(0.5)) / grid;
		}
		vec2 point = coordinates - vec2(0.5);
		float clock = (particle ? particle_phase * effect_duration : effect_time) * pattern_motion + pattern_phase * effect_duration;
		float normalized = clock / max(effect_duration, 0.05);
		float phase = looping ? fract(normalized) : clamp(normalized, 0.0, 1.0);
		vec2 painted = vec2(0.0);
		if (pattern == 1) { painted = spring_fx(point, phase, clock); }
		else if (pattern == 2) { painted = laser_fx(point, phase, clock); }
		else if (pattern == 3) { painted = flame_sigil_fx(point, phase, clock); }
		else if (pattern == 4) { painted = bouncing_star_fx(point, phase, clock); }
		else if (pattern == 5) { painted = ink_lotus_fx(point, phase, clock); }
		else if (pattern == 6) { painted = stone_dust_fx(point, phase, clock); }
		else if (pattern == 7) { painted = crystal_spikes_fx(point, phase, clock); }
		else if (pattern == 8) { painted = portal_tiles_fx(point, phase, clock); }
		else if (pattern == 9) { painted = aegis_shell_fx(point, phase, clock); }
		else if (pattern == 10) { painted = bubble_shot_fx(point, phase, clock); }
		else if (pattern == 11) { painted = brush_prison_fx(point, phase, clock); }
		else if (pattern == 12) { painted = metal_sparks_fx(point, phase, clock); }
		float tone = clamp(painted.y, 0.0, 1.0);
		if (material_mode == 1) { tone = floor(tone * 3.0 + 0.5) / 3.0; }
		vec3 color = mix(secondary_tint.rgb * 0.65, tint.rgb, smoothstep(0.0, 0.78, tone));
		color = mix(color, mix(tint.rgb, vec3(1.0), 0.52), smoothstep(0.78, 1.0, tone));
		sample_color = vec4(color, painted.x * tint.a * instance_tint.a);
	}
	if (hard_edge && material_mode != 2) {
		sample_color.a = floor(sample_color.a * 4.0 + 0.01) / 4.0;
	}
	if (sample_color.a < 0.01) { discard; }
	ALBEDO = sample_color.rgb;
	ALPHA = sample_color.a;
}
