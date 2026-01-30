shader_type canvas_item;

// Glass window shader with sheen, reflections, and edge highlights
// Makes the window clearly distinguishable from walls

// Color properties
uniform vec4 glass_tint : source_color = vec4(0.7, 0.9, 1.0, 0.6);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.5;

// Reflection properties
uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float reflection_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec2 reflection_direction = vec2(1.0, -0.5);

// Shimmer/sheen properties
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 2.0;
uniform float shimmer_scale : hint_range(1.0, 20.0) = 8.0;

// Edge glow properties
uniform float edge_thickness : hint_range(0.0, 0.5) = 0.15;
uniform vec4 edge_color : source_color = vec4(0.8, 1.0, 1.0, 0.9);
uniform float edge_intensity : hint_range(0.0, 2.0) = 0.8;

// Distortion properties
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.01;
uniform float distortion_speed : hint_range(0.0, 5.0) = 1.0;

// Specular highlight
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float specular_intensity : hint_range(0.0, 2.0) = 0.7;
uniform float specular_size : hint_range(0.1, 10.0) = 3.0;
uniform vec2 light_position = vec2(0.3, 0.3);

// Noise function for procedural patterns
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

// Fractal noise for more complex patterns
float fractal_noise(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

void fragment() {
    vec2 uv = UV;
    
    // Calculate distance from edges for edge glow
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edge_factor = smoothstep(0.0, edge_thickness, edge_dist);
    edge_factor = 1.0 - edge_factor;
    
    // Animated reflection streaks
    vec2 reflection_uv = uv + reflection_direction * TIME * reflection_speed * 0.1;
    float reflection = fractal_noise(reflection_uv * 3.0);
    reflection = pow(reflection, 2.0) * reflection_intensity;
    
    // Animated shimmer/sheen effect (diagonal moving highlights)
    float shimmer_angle = (uv.x + uv.y) * shimmer_scale + TIME * shimmer_speed;
    float shimmer = sin(shimmer_angle) * 0.5 + 0.5;
    shimmer = pow(shimmer, 3.0) * shimmer_intensity;
    
    // Subtle distortion for glass refraction effect
    float distortion_noise = fractal_noise(uv * 4.0 + TIME * distortion_speed * 0.2);
    vec2 distorted_uv = uv + (distortion_noise - 0.5) * distortion_strength;
    
    // Specular highlight (light reflection)
    vec2 to_light = distorted_uv - light_position;
    float light_dist = length(to_light);
    float specular = exp(-light_dist * specular_size) * specular_intensity;
    
    // Combine base glass color with effects
    vec3 final_color = glass_tint.rgb;
    
    // Add reflection streaks (brighter areas)
    final_color += vec3(reflection);
    
    // Add shimmer/sheen
    final_color += vec3(shimmer);
    
    // Add specular highlight
    final_color += specular_color.rgb * specular;
    
    // Add edge glow
    final_color = mix(final_color, edge_color.rgb, edge_factor * edge_intensity);
    
    // Calculate final alpha
    float final_alpha = base_alpha;
    // Make edges slightly more visible
    final_alpha += edge_factor * edge_color.a * edge_intensity;
    
    // Clamp values
    final_color = clamp(final_color, vec3(0.0), vec3(1.0));
    final_alpha = clamp(final_alpha, 0.0, 1.0);
    
    // Output
    COLOR = vec4(final_color, final_alpha);
}

