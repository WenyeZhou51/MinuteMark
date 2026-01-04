shader_type canvas_item;

// Paint splatter mask parameters
uniform vec2 pendulum_position = vec2(0.0, 0.5);  // Normalized current pendulum position
uniform float accumulation_progress : hint_range(0.0, 1.0) = 0.0;  // Overall progress 0-1

// Arc parameters
uniform vec2 pivot_position = vec2(0.5, 0.0);
uniform float pendulum_length = 1.5;
uniform float start_angle_rad = 2.356;  // ~135 degrees
uniform float end_angle_rad = 0.785;    // ~45 degrees

// Splatter appearance
uniform float splatter_size : hint_range(0.01, 0.5) = 0.15;
uniform float edge_roughness : hint_range(0.0, 3.0) = 1.5;
uniform float noise_scale : hint_range(1.0, 20.0) = 5.0;
uniform float detail_noise_scale : hint_range(1.0, 30.0) = 12.0;
uniform float splatter_opacity : hint_range(0.0, 1.0) = 1.0;

// Droplets
uniform int droplet_count : hint_range(0, 50) = 25;
uniform float droplet_size_min : hint_range(0.001, 0.1) = 0.005;
uniform float droplet_size_max : hint_range(0.001, 0.1) = 0.02;

// Trail splatters
uniform int num_trail_splatters : hint_range(0, 10) = 4;

// ============================================================================
// NOISE FUNCTIONS
// ============================================================================

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

// ============================================================================
// MAIN SHADER
// ============================================================================

void fragment() {
    if (accumulation_progress <= 0.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    if (accumulation_progress >= 1.0) {
        COLOR = vec4(1.0, 1.0, 1.0, 1.0);
        return;
    }
    
    float mask_value = 0.0;
    
    // Calculate the pendulum sweep line
    // Pixels to the LEFT of the pendulum line should be white (revealed)
    
    // Current angle based on progress
    float current_angle = mix(start_angle_rad, end_angle_rad, accumulation_progress);
    
    // Vector from pivot to current pixel
    vec2 pixel_vec = UV - pivot_position;
    float pixel_angle = atan(pixel_vec.y, pixel_vec.x);
    
    // Determine if pixel is on the "revealed" side (left side of pendulum)
    // Since start_angle > end_angle, pixels with angles between end and current should be hidden
    // Pixels with angles between current and start should be revealed
    
    bool is_left_of_pendulum = false;
    
    // Normalize angles to handle wrapping
    if (start_angle_rad > end_angle_rad) {
        // Normal case: swinging from larger angle to smaller
        if (pixel_angle >= current_angle && pixel_angle <= start_angle_rad) {
            is_left_of_pendulum = true;
        }
        // Also need to handle pixels on the far left (angles > PI)
        if (pixel_angle > start_angle_rad || pixel_angle < end_angle_rad) {
            // Check which side more carefully
            if (pixel_angle > start_angle_rad) {
                is_left_of_pendulum = true;
            }
        }
    }
    
    if (is_left_of_pendulum) {
        // Base reveal - this pixel is in the swept area
        mask_value = 1.0;
        
        // Add paint splatter effect near the pendulum edge
        vec2 to_pendulum = UV - pendulum_position;
        float dist_to_pendulum = length(to_pendulum);
        
        // Generate noise for edge irregularity
        vec2 noise_pos = UV * noise_scale;
        float base_noise = noise(noise_pos);
        float detail_noise = noise(UV * detail_noise_scale);
        float combined_noise = base_noise * 0.7 + detail_noise * 0.3;
        
        // Create irregular edge near pendulum
        float edge_dist = splatter_size * (1.0 + combined_noise * edge_roughness);
        
        if (dist_to_pendulum < edge_dist) {
            // Near the edge - apply splatter pattern
            float edge_factor = dist_to_pendulum / edge_dist;
            float splatter_threshold = 0.3 + combined_noise * 0.4;
            
            if (edge_factor > splatter_threshold) {
                mask_value = smoothstep(splatter_threshold, 1.0, edge_factor);
            }
        }
    } else {
        // This pixel hasn't been swept yet
        // But add some paint droplets/splatters in front of the pendulum
        
        vec2 to_pendulum = UV - pendulum_position;
        float dist_to_pendulum = length(to_pendulum);
        
        // Add scattered droplets
        for (int i = 0; i < droplet_count; i++) {
            if (i >= droplet_count) break;
            
            vec2 seed = vec2(float(i) * 12.34, accumulation_progress * 100.0);
            vec2 offset = hash22(seed) * 0.3;  // Droplets within 0.3 normalized units
            vec2 droplet_pos = pendulum_position + offset;
            
            float droplet_size = mix(droplet_size_min, droplet_size_max, hash12(seed));
            float droplet_dist = length(UV - droplet_pos);
            
            if (droplet_dist < droplet_size) {
                // Add some noise to droplet edge
                float noise_val = noise(UV * detail_noise_scale + seed);
                float irregular_edge = droplet_size * (0.8 + noise_val * 0.4);
                
                if (droplet_dist < irregular_edge) {
                    mask_value = max(mask_value, smoothstep(irregular_edge, irregular_edge * 0.5, droplet_dist));
                }
            }
        }
        
        // Add trail splatters behind the pendulum
        for (int i = 1; i <= num_trail_splatters; i++) {
            if (i > num_trail_splatters) break;
            
            float trail_progress = accumulation_progress - float(i) * 0.05;
            if (trail_progress > 0.0) {
                float trail_angle = mix(start_angle_rad, end_angle_rad, trail_progress);
                vec2 trail_pos = pivot_position + vec2(cos(trail_angle), sin(trail_angle)) * pendulum_length;
                
                float trail_dist = length(UV - trail_pos);
                float trail_size = splatter_size * 0.6;
                
                vec2 trail_noise_pos = UV * noise_scale + vec2(float(i) * 50.0);
                float trail_noise = noise(trail_noise_pos);
                float trail_edge = trail_size * (1.0 + trail_noise * edge_roughness * 0.5);
                
                if (trail_dist < trail_edge) {
                    float fade = 1.0 - float(i) / float(num_trail_splatters + 1);
                    mask_value = max(mask_value, smoothstep(trail_edge, 0.0, trail_dist) * fade);
                }
            }
        }
    }
    
    mask_value *= splatter_opacity;
    mask_value = clamp(mask_value, 0.0, 1.0);
    
    // Output as grayscale mask (R channel will be used for alpha)
    COLOR = vec4(mask_value, mask_value, mask_value, 1.0);
}
