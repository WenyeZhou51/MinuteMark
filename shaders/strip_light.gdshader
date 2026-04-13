shader_type canvas_item;

uniform vec4 light_color : source_color = vec4(0.2, 0.6, 1.0, 0.5);
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	float dist_y = UV.y;
	float dist_x = abs(UV.x - 0.5) * 2.0;

	float h_mask = 1.0 - smoothstep(0.85, 1.0, dist_x);

	float v_intensity = 1.0 - dist_y;
	v_intensity = clamp(v_intensity, 0.0, 1.0);
	v_intensity = v_intensity * v_intensity;

	float v_mask = smoothstep(0.0, 0.03, dist_y) * (1.0 - smoothstep(0.92, 1.0, dist_y));

	float raw = v_intensity * h_mask;

	float pulse = pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));

	float alpha = v_mask * (raw + pulse) * light_color.a;
	COLOR = vec4(light_color.rgb, alpha);
}
