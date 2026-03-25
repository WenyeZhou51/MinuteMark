shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.45, 0.8, 1.0, 0.75);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.2, 3.0) = 1.0;
uniform float distortion : hint_range(0.0, 0.2) = 0.06;
uniform float streak_density : hint_range(6.0, 40.0) = 20.0;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.09;
uniform float flow_strength : hint_range(0.5, 6.0) = 3.2;
uniform float core_fill : hint_range(0.0, 1.0) = 0.82;
uniform float bottom_density_boost : hint_range(1.0, 2.5) = 1.35;

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;

	// Warp UV.x so streams wobble and break up naturally.
	float wobble_a = sin(uv.y * 38.0 + t * 7.0 + uv.x * 12.0) * distortion;
	float wobble_b = sin(uv.y * 96.0 - t * 13.0) * (distortion * 0.4);
	float warped_x = uv.x + wobble_a + wobble_b;

	// Vertical stream bands.
	float bands = 0.5 + 0.5 * sin((warped_x * streak_density + t * 2.8) * 6.28318);
	float micro = 0.5 + 0.5 * sin((warped_x * streak_density * 2.2 - t * 9.0 + uv.y * 16.0) * 6.28318);
	float stream_mask = mix(0.76, 1.0, bands) * mix(0.86, 1.0, micro);

	// Soft edge and vertical fade to avoid hard "beam" look.
	float edge_left = smoothstep(0.0, edge_softness, uv.x);
	float edge_right = 1.0 - smoothstep(1.0 - edge_softness, 1.0, uv.x);
	float edge_mask = edge_left * edge_right;
	float vertical_mask = smoothstep(0.0, 0.06, uv.y) * (1.0 - smoothstep(0.88, 1.0, uv.y) * 0.18);

	// Tiny random breakup to avoid perfect lines.
	float noise = fract(sin(dot(vec2(warped_x * 173.0, uv.y * 317.0), vec2(12.9898, 78.233))) * 43758.5453);
	float breakup = smoothstep(0.0, 0.72, noise + 0.36);

	float center_boost = 1.05 - abs(uv.x - 0.5) * 0.65;
	float continuity = mix(core_fill, 1.0, breakup);
	float bottom_boost = mix(1.0, bottom_density_boost, smoothstep(0.5, 1.0, uv.y));
	float alpha = water_color.a * intensity * flow_strength * stream_mask * edge_mask * vertical_mask * continuity * center_boost * bottom_boost;
	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(water_color.rgb, alpha);
}
