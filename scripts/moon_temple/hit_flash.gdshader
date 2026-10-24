shader_type canvas_item;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex.rgb, vec3(1.0), hit_flash), tex.a);
}
