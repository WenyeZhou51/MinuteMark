shader_type canvas_item;

// Crusher hazard shader with warning stripes and pulsing effect
uniform vec4 stripe_color_1 : source_color = vec4(1.0, 0.8, 0.0, 1.0);  // Yellow
uniform vec4 stripe_color_2 : source_color = vec4(0.1, 0.1, 0.1, 1.0);  // Dark gray
uniform float stripe_width : hint_range(0.05, 0.5) = 0.15;  // Width of each stripe
uniform float stripe_angle : hint_range(-180.0, 180.0) = -45.0;  // Angle of stripes in degrees
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.2;

void fragment() {
	// Convert angle to radians
	float angle_rad = radians(stripe_angle);
	
	// Rotate UV coordinates
	vec2 rotated_uv;
	rotated_uv.x = UV.x * cos(angle_rad) - UV.y * sin(angle_rad);
	rotated_uv.y = UV.x * sin(angle_rad) + UV.y * cos(angle_rad);
	
	// Create repeating stripe pattern
	float stripe_pattern = fract(rotated_uv.x / stripe_width);
	
	// Pulse effect
	float pulse = sin(TIME * pulse_speed) * pulse_intensity + (1.0 - pulse_intensity);
	
	// Determine which stripe color to use
	vec4 base_color = stripe_pattern < 0.5 ? stripe_color_1 : stripe_color_2;
	
	// Apply pulse to yellow stripes only
	if (stripe_pattern < 0.5) {
		base_color.rgb *= pulse;
	}
	
	// Edge darkening for depth effect
	float edge_factor = 1.0 - smoothstep(0.0, 0.1, min(UV.x, min(UV.y, min(1.0 - UV.x, 1.0 - UV.y))));
	base_color.rgb *= 1.0 - edge_factor * 0.3;
	
	COLOR = base_color;
}
