shader_type canvas_item;

// Time warning overlay shader - sketchy red overlay effect with frame
// Matches the hand-drawn art style of the game

uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform vec4 warning_color : source_color = vec4(1.0, 0.1, 0.1, 0.6);
uniform float edge_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float noise_scale : hint_range(1.0, 50.0) = 10.0;
uniform float frame_thickness : hint_range(0.0, 0.1) = 0.02;
uniform float frame_intensity : hint_range(0.0, 2.0) = 1.5;

// Simple noise function for sketchy edges
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for more organic patterns
float fractal_noise(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	
	return value;
}

void fragment() {
	vec2 uv = UV;
	
	// Calculate distance from edges for rough edge effect and frame
	float edge_dist_x = min(uv.x, 1.0 - uv.x);
	float edge_dist_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_dist_x, edge_dist_y);
	
	// Create rough, sketchy edges using noise
	float noise_val = fractal_noise(uv * noise_scale + TIME * 0.1);
	float rough_edge = smoothstep(edge_roughness * 0.1, edge_roughness * 0.3, edge_dist + noise_val * 0.05);
	
	// Create warning frame at screen edges (more intense, pulsing border)
	float frame_dist = min(edge_dist_x, edge_dist_y);
	float frame_noise = fractal_noise(uv * noise_scale * 0.5 + TIME * 0.2);
	float frame_mask = 1.0 - smoothstep(frame_thickness - 0.01, frame_thickness + 0.01, frame_dist + frame_noise * 0.02);
	
	// Pulsing effect - intensity varies over time (using TIME from shader)
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float final_intensity = intensity * (0.8 + pulse * 0.2);
	
	// Apply warning color with intensity and pulsing
	vec4 final_color = warning_color;
	final_color.a *= final_intensity * rough_edge;
	
	// Add frame effect - subtle red pulsing border
	vec4 frame_color = vec4(0.8, 0.1, 0.1, 1.0);  // Slightly less intense red
	float frame_pulse = sin(TIME * pulse_speed * 1.5) * 0.2 + 0.8;  // Less dramatic pulse
	frame_color.a = frame_mask * frame_intensity * frame_pulse;
	
	// Combine overlay and frame
	final_color = mix(final_color, frame_color, frame_mask);
	
	// Add subtle noise variation for hand-drawn feel
	float color_noise = noise(uv * noise_scale * 2.0 + TIME * 0.05) * 0.1;
	final_color.rgb += vec3(color_noise * 0.2);
	
	COLOR = final_color;
}
