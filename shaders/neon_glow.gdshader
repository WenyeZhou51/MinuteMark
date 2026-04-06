shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float core_sharpness : hint_range(0.005, 0.08) = 0.025;
uniform float glow_falloff : hint_range(0.05, 0.5) = 0.45;
uniform float posterize_levels : hint_range(2.0, 12.0) = 5.0;
uniform float pulse_speed : hint_range(0.5, 8.0) = 3.0;
uniform float pulse_min : hint_range(0.3, 1.0) = 0.7;
uniform float flicker_intensity : hint_range(0.0, 0.3) = 0.1;
uniform float end_cap_fade : hint_range(0.01, 0.15) = 0.05;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	float dist_y = abs(UV.y - 0.5);
	float end_mask = smoothstep(0.0, end_cap_fade, UV.x) * smoothstep(1.0, 1.0 - end_cap_fade, UV.x);

	float core = 1.0 - smoothstep(0.0, core_sharpness, dist_y);

	float glow_norm = clamp(dist_y / glow_falloff, 0.0, 1.0);
	float glow_raw = 1.0 - glow_norm;
	float glow_banded = floor(glow_raw * posterize_levels + 0.5) / posterize_levels;

	float pulse = mix(pulse_min, 1.0, 0.5 + 0.5 * sin(TIME * pulse_speed));
	float flicker = 1.0 - flicker_intensity * hash(floor(TIME * 30.0));
	float brightness = pulse * flicker;

	float outer_mask = 1.0 - smoothstep(glow_falloff - 0.02, glow_falloff, dist_y);
	float intensity = max(core, glow_banded * 0.55) * brightness * end_mask * outer_mask;

	vec3 col = mix(neon_color.rgb, vec3(1.0), core * 0.6);
	COLOR = vec4(col, intensity);
}
