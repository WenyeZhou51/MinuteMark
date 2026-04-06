shader_type canvas_item;

uniform vec4 light_color : source_color = vec4(1.0, 0.3, 0.6, 0.5);
uniform float posterize_levels : hint_range(2.0, 12.0) = 5.0;
uniform float outer_radius : hint_range(0.01, 0.5) = 0.48;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	float dist = distance(UV, vec2(0.5));

	float pulse = pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float effective_radius = outer_radius + pulse;

	float norm_dist = clamp(dist / effective_radius, 0.0, 1.0);
	float intensity = 1.0 - norm_dist;

	float banded = floor(intensity * posterize_levels + 0.5) / posterize_levels;

	float mask = 1.0 - smoothstep(effective_radius - 0.02, effective_radius, dist);

	COLOR = vec4(light_color.rgb, light_color.a * banded * mask);
}
