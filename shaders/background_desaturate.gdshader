shader_type canvas_item;

// Background desaturation and contrast adjustment shader
uniform float saturation : hint_range(0.0, 1.0) = 0.3;
uniform float contrast : hint_range(0.0, 2.0) = 0.7;
uniform float brightness : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Convert to grayscale for desaturation
	float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Mix between original and grayscale based on saturation
	vec3 desaturated = mix(vec3(gray), tex_color.rgb, saturation);
	
	// Apply contrast (center at 0.5)
	desaturated = (desaturated - 0.5) * contrast + 0.5;
	
	// Apply brightness
	desaturated *= brightness;
	
	// Clamp to valid range
	desaturated = clamp(desaturated, 0.0, 1.0);
	
	COLOR = vec4(desaturated, tex_color.a);
}
