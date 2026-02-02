shader_type canvas_item;

// Advanced laser beam shader with energy distortion and glow
uniform vec4 core_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);  // Bright red core
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 0.8);  // Orange edges
uniform vec4 glow_color : source_color = vec4(1.0, 0.0, 0.0, 0.5);  // Red glow
uniform float beam_width : hint_range(0.1, 1.0) = 0.4;  // Core beam width
uniform float glow_width : hint_range(1.0, 5.0) = 3.0;  // Glow spread
uniform float pulse_speed : hint_range(0.5, 10.0) = 3.0;
uniform float distortion_speed : hint_range(0.5, 10.0) = 2.0;
uniform float distortion_amount : hint_range(0.0, 0.2) = 0.05;
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;

// Simple noise function
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise
float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	for (int i = 0; i < 4; i++) {
		value += amplitude * smooth_noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	
	return value;
}

void fragment() {
	// Calculate distance from center line
	float dist_from_center = abs(UV.y - 0.5) * 2.0;
	
	// Animated distortion along the beam
	vec2 distortion_uv = vec2(UV.x * noise_scale + TIME * distortion_speed, UV.y * noise_scale);
	float distortion = fbm(distortion_uv) * 2.0 - 1.0;
	dist_from_center += distortion * distortion_amount;
	
	// Pulsing effect
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;
	
	// Energy flow along the beam
	float flow = fbm(vec2(UV.x * 3.0 - TIME * 2.0, UV.y * 3.0));
	flow = pow(flow, 1.5);
	
	// Core beam intensity
	float core_intensity = 1.0 - smoothstep(0.0, beam_width, dist_from_center);
	core_intensity = pow(core_intensity, 2.0);
	
	// Outer glow
	float glow_intensity = 1.0 - smoothstep(0.0, 1.0, dist_from_center);
	glow_intensity = pow(glow_intensity, glow_width);
	
	// Combine core and edge colors
	vec4 beam_color = mix(edge_color, core_color, core_intensity);
	beam_color.rgb += flow * 0.4 * core_intensity;  // Add energy flow brightness
	beam_color.rgb *= pulse;  // Apply pulse
	
	// Add glow
	vec3 final_color = beam_color.rgb + glow_color.rgb * glow_intensity * 0.8;
	
	// Calculate final alpha
	float alpha = max(core_intensity, glow_intensity * 0.6);
	
	// Brighten the center more
	final_color += core_color.rgb * core_intensity * 0.5;
	
	COLOR = vec4(final_color, alpha);
}
