shader_type canvas_item;

// Grayscale overlay shader - converts screen to black and white
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Sample the screen texture using the uniform with hint_screen_texture
	// SCREEN_UV provides the correct UV coordinates for the screen texture
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	
	// Convert to grayscale using standard luminance weights
	float gray = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Blend between original color and grayscale based on intensity
	vec3 final_color = mix(screen_color.rgb, vec3(gray), intensity);
	
	// Output with full alpha
	COLOR = vec4(final_color, 1.0);
}

