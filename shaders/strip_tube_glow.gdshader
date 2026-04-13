shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float core_width : hint_range(0.005, 0.1) = 0.03;
uniform float glow_falloff : hint_range(0.05, 0.5) = 0.4;
uniform float core_brightness : hint_range(1.0, 5.0) = 3.0;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
uniform float pulse_min : hint_range(0.5, 1.0) = 0.8;
uniform float end_fade : hint_range(0.01, 0.15) = 0.05;

void fragment() {
	float dist_y = abs(UV.y - 0.5);
	float end_mask = smoothstep(0.0, end_fade, UV.x) * smoothstep(1.0, 1.0 - end_fade, UV.x);

	// Bright white-hot core
	float core = 1.0 - smoothstep(0.0, core_width, dist_y);

	// Smooth glow falloff (no posterization)
	float glow = 1.0 - smoothstep(0.0, glow_falloff, dist_y);
	glow = glow * glow;

	float pulse = mix(pulse_min, 1.0, 0.5 + 0.5 * sin(TIME * pulse_speed));

	float outer_mask = 1.0 - smoothstep(glow_falloff - 0.02, glow_falloff, dist_y);
	float intensity = max(core * core_brightness, glow * 0.6) * pulse * end_mask * outer_mask;

	vec3 col = mix(glow_color.rgb, vec3(1.0), core * 0.7);
	vec3 hdr_col = col * intensity;
	float alpha = clamp(intensity, 0.0, 1.0);
	COLOR = vec4(hdr_col, alpha);
}
