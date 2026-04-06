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
	float edge = edge_softness * max(UV.y, 0.05);
	float h_mask = 1.0 - smoothstep(cone_width - edge, cone_width, center_dist);

	float v_fade = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));

	float cone_dist = center_dist / max(cone_width, 0.001);
	float raw_intensity = (1.0 - cone_dist) * (1.0 - UV.y * 0.7);
	raw_intensity = clamp(raw_intensity, 0.0, 1.0);

	float banded = floor(raw_intensity * posterize_levels + 0.5) / posterize_levels;

	float pulse = pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));

	float alpha = h_mask * v_fade * (banded + pulse) * light_color.a;
	COLOR = vec4(light_color.rgb, alpha);
}
