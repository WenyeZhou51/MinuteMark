shader_type canvas_item;

// Outline and glow settings
uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.0, 0.8);
uniform float glow_strength : hint_range(0.0, 5.0) = 2.0;

// Wavy distortion settings
uniform float wave_speed : hint_range(0.0, 10.0) = 3.0;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.05;
uniform float wave_frequency : hint_range(0.0, 20.0) = 10.0;

// Energy pulse settings
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.7;
uniform float pulse_max : hint_range(0.0, 2.0) = 1.3;

void fragment() {
	// Calculate pulsing effect
	float pulse = mix(pulse_min, pulse_max, (sin(TIME * pulse_speed) + 1.0) / 2.0);
	
	// Apply wavy distortion to UV coordinates
	vec2 distorted_uv = UV;
	distorted_uv.x += sin(UV.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
	distorted_uv.y += cos(UV.x * wave_frequency * 0.7 + TIME * wave_speed * 1.3) * wave_amplitude * 0.5;
	
	// Sample texture with distorted UV
	vec4 color = texture(TEXTURE, distorted_uv);
	
	// Apply pulse to color intensity
	color.rgb *= pulse;
	
	// Outline detection using offset sampling
	float outline = 0.0;
	vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;
	
	// Sample surrounding pixels to detect edges
	for(float x = -1.0; x <= 1.0; x += 1.0) {
		for(float y = -1.0; y <= 1.0; y += 1.0) {
			if(x == 0.0 && y == 0.0) continue;
			vec2 offset = vec2(x, y) * pixel_size;
			float sample_alpha = texture(TEXTURE, UV + offset).a;
			outline = max(outline, sample_alpha);
		}
	}
	
	// If we're on the edge (outline detected but current pixel is transparent)
	if(outline > 0.0 && color.a < 0.5) {
		color = outline_color;
		color.a = outline * pulse;
	}
	
	// Add glow effect around the sprite
	if(color.a > 0.1) {
		color.rgb += glow_color.rgb * glow_strength * pulse * 0.3;
	}
	
	COLOR = color;
}
