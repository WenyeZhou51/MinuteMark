shader_type canvas_item;

uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.8, 0.35);
uniform float edge_softness : hint_range(0.0, 0.5) = 0.15;
uniform float top_fade : hint_range(0.0, 1.0) = 0.1;
uniform float posterize_levels : hint_range(2.0, 12.0) = 5.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 0.15) = 0.04;

void fragment() {
	float center_dist = abs(UV.x - 0.5) * 2.0;
	float cone_width = mix(top_fade, 1.0, UV.y);

	float cone_relative = center_dist / max(cone_width, 0.001);
	float cone_intensity = clamp(1.0 - cone_relative, 0.0, 1.0);
	float banded = floor(cone_intensity * posterize_levels + 0.5) / posterize_levels;

	float h_mask = 1.0 - smoothstep(cone_width - edge_softness, cone_width, center_dist);
	float v_fade = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));

	float pulse = pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));

	float alpha = light_color.a * banded * h_mask * v_fade + pulse * h_mask * v_fade;
	COLOR = vec4(light_color.rgb, clamp(alpha, 0.0, light_color.a));
}
