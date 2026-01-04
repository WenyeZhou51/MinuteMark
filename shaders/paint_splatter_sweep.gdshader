shader_type canvas_item;

// Main animation control
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

// Pendulum arc parameters
uniform vec2 pivot_position = vec2(0.5, 0.0);  // Normalized pivot point
uniform float pendulum_length = 1.5;  // Normalized length
uniform float start_angle_rad = 2.356;  // Starting angle in radians
uniform float end_angle_rad = 0.785;  // Ending angle in radians

// Edge appearance controls
uniform float edge_roughness : hint_range(0.0, 1.0) = 0.4;
uniform float detail_scale : hint_range(1.0, 20.0) = 8.0;
uniform float edge_softness : hint_range(0.0, 0.2) = 0.05;
uniform float noise_seed : hint_range(0.0, 100.0) = 1.0;

// Quality settings
uniform int octave_count : hint_range(1, 5) = 3;

// Optional performance optimization
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform bool use_noise_texture = false;

// ============================================================================
// NOISE FUNCTIONS
// ============================================================================

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = dot(hash22(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float b = dot(hash22(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(hash22(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(hash22(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float multi_octave_noise(vec2 pos, int octaves) {
    float total = 0.0;
    float amplitude = 1.0;
    float total_amplitude = 0.0;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        if (use_noise_texture) {
            total += texture(noise_texture, pos * frequency * 0.1).r * amplitude;
        } else {
            total += noise(pos * frequency) * amplitude;
        }
        
        total_amplitude += amplitude;
        amplitude *= 0.5;
        frequency *= 2.5;
    }
    
    return total / total_amplitude;
}

// ============================================================================
// MAIN SHADER
// ============================================================================

void fragment() {
    // Early exit optimization
    if (reveal_progress <= 0.0) {
        COLOR = vec4(0.0);
        return;
    }
    
    // Sample base texture
    vec4 tex_color = texture(TEXTURE, UV);
    
    // If fully revealed, just output the texture
    if (reveal_progress >= 1.0) {
        COLOR = tex_color;
        return;
    }
    
    // Calculate the current pendulum angle based on progress
    float current_angle = mix(start_angle_rad, end_angle_rad, reveal_progress);
    
    // Calculate current pendulum position
    vec2 current_pendulum = pivot_position + vec2(cos(current_angle), sin(current_angle)) * pendulum_length;
    
    // Calculate the angle from pivot to current pixel
    vec2 pixel_offset = UV - pivot_position;
    float pixel_angle = atan(pixel_offset.y, pixel_offset.x);
    
    // Normalize angles to be in same range for comparison
    // We need to handle the angle wrapping correctly
    float angle_diff = pixel_angle - start_angle_rad;
    float sweep_range = end_angle_rad - start_angle_rad;
    
    // Calculate how far along the sweep this pixel is (0 = start, 1 = end)
    float pixel_progress = angle_diff / sweep_range;
    
    // Generate noise for irregular edges
    // Use pixel position for noise to create paint splatter effect
    vec2 noise_pos = UV * detail_scale + vec2(noise_seed);
    
    float total_noise = 0.0;
    
    if (octave_count >= 1) {
        vec2 pos1 = noise_pos * 1.0;
        total_noise += multi_octave_noise(pos1, 1) * 1.0;
    }
    
    if (octave_count >= 2) {
        vec2 pos2 = noise_pos * 1.5 + vec2(100.0, 50.0);
        total_noise += multi_octave_noise(pos2, 1) * 0.5;
    }
    
    if (octave_count >= 3) {
        vec2 pos3 = noise_pos * 2.5 + vec2(200.0, 150.0);
        total_noise += multi_octave_noise(pos3, 1) * 0.25;
    }
    
    if (octave_count >= 4) {
        vec2 pos4 = noise_pos * 4.0 + vec2(300.0, 250.0);
        total_noise += multi_octave_noise(pos4, 1) * 0.125;
    }
    
    if (octave_count >= 5) {
        vec2 pos5 = noise_pos * 6.0 + vec2(400.0, 350.0);
        total_noise += multi_octave_noise(pos5, 1) * 0.0625;
    }
    
    // Add noise offset to the threshold
    float noise_offset = total_noise * edge_roughness;
    
    // Calculate if this pixel should be revealed
    // Revealed if the pendulum has swept past this angle
    float threshold = reveal_progress + noise_offset * 0.15;
    
    // Smooth transition at the edge
    float alpha = smoothstep(
        pixel_progress - edge_softness,
        pixel_progress + edge_softness,
        threshold
    );
    
    // Apply alpha to texture
    COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
}

