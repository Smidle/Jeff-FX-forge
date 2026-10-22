shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D mask_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool palette_hue_shift = false;
uniform vec4 palette_reference : source_color = vec4(1.0);
uniform vec4 palette_target : source_color = vec4(1.0);
uniform bool face_camera = true;
// Pivot around the connection axis, keeping both world endpoints anchored.
uniform bool face_path_axis = false;
uniform bool particle = false;
uniform bool field = false;
uniform bool ground_particle = false;
uniform bool hard_edge = false;
uniform int atlas_frames = 1;
uniform float shape_angle = 0.0;
uniform float shape_frame = 0.0;
uniform float animation_cycles = 1.0;
uniform bool animation_loop = false;
uniform float arc_span = 6.2831853;
uniform int branch_count = -1;
uniform int motif_count = -1;
varying vec4 instance_tint;
varying vec2 effect_uv;

vec3 to_hsv(vec3 color) {
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

vec3 from_hsv(vec3 color) {
	vec3 sectors = mod(color.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0);
	vec3 channels = clamp(abs(sectors - 3.0) - 1.0, 0.0, 1.0);
	return color.z * mix(vec3(1.0), channels, color.y);
}

void vertex() {
	effect_uv = UV;
	float phase = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
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
		float c = cos(angle);
		float s = sin(angle);
		VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	}
	if (ground_particle) { VERTEX = vec3(VERTEX.x, 0.0, -VERTEX.y); }
	if (atlas_frames > 1) {
		float progress = animation_loop ? fract(phase * animation_cycles) : min(phase * animation_cycles, 0.9999);
		float frame = field ? INSTANCE_CUSTOM.z : (particle ? floor(progress * float(atlas_frames)) : shape_frame);
		UV.x = (UV.x + frame) / float(atlas_frames);
	}
}

void fragment() {
	// Masks remove native pixels; the authored silhouettes are never filtered.
	vec2 centered = effect_uv - vec2(0.5);
	float angle = mod(atan(centered.y, centered.x) + 3.14159265, 6.2831853);
	if (angle > arc_span) { discard; }
	if (branch_count >= 0 && abs(centered.x) > 0.16) {
		if (branch_count == 0 || (branch_count == 1 && centered.x > 0.0)) { discard; }
	}
	if (motif_count >= 0 && length(centered) > 0.14 && length(centered) < 0.37) {
		float sector = floor(mod(atan(centered.y, centered.x) + 2.0943951, 6.2831853) / 1.04719755);
		if (floor((sector + 1.0) * float(motif_count) / 6.0) == floor(sector * float(motif_count) / 6.0)) { discard; }
	}
	vec4 sampled = texture(mask_texture, UV);
	if (palette_hue_shift) {
		vec3 pixel = to_hsv(sampled.rgb);
		vec3 reference = to_hsv(palette_reference.rgb);
		vec3 target = to_hsv(palette_target.rgb);
		pixel.x = fract(pixel.x + target.x - reference.x + 1.0);
		pixel.y = clamp(pixel.y * target.y / max(reference.y, 0.001), 0.0, 1.0);
		pixel.z *= target.z / max(reference.z, 0.001);
		sampled.rgb = from_hsv(pixel);
	}
	vec4 sample_color = sampled * tint * instance_tint;
	if (hard_edge) {
		sample_color.a = floor(sample_color.a * 4.0 + 0.01) / 4.0;
	}
	if (sample_color.a < 0.01) { discard; }
	ALBEDO = sample_color.rgb;
	ALPHA = sample_color.a;
}
