shader_type canvas_item;

// --- Uniform Parameters ---
uniform float beat_speed : hint_range(0.1, 10.0) = 1.0; 
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3; 
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5; 
uniform vec3 pulse_color : source_color = vec3(1.0, 0.2, 0.2); 
uniform bool use_glow = true;
uniform bool use_tint = false;

void fragment() {
    // 1. Base color sample
    // For ColorRect, we use COLOR instead of texture(TEXTURE, UV)
    vec4 tex_color = COLOR;
    
    // 2. Generate a sine-based pulse (0..1)
    float pulse = (sin(TIME * beat_speed * 2.0 * PI) * 0.5) + 0.5; 

    // 3. Apply pulse to base brightness
    float brightness = 1.0 + pulse * pulse_intensity;

    vec3 color_out = tex_color.rgb * brightness;

    // 4. Optional glow tint overlay
    if (use_tint) {
        color_out = mix(color_out, pulse_color, pulse * pulse_intensity);
    }

    // 5. Optional glow boost
    if (use_glow) {
        color_out += pulse * glow_intensity;
    }

    COLOR = vec4(color_out, tex_color.a);
}
