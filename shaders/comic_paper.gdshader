shader_type canvas_item;

// Comic book paper background shader
uniform vec4 paper_color : source_color = vec4(0.98, 0.96, 0.92, 1.0);
uniform float paper_texture_strength : hint_range(0.0, 1.0) = 0.15;
uniform float halftone_dot_size : hint_range(1.0, 50.0) = 8.0;
uniform float halftone_intensity : hint_range(0.0, 0.3) = 0.05;

// Simple noise function for paper texture
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

// Halftone dot pattern
float halftone_dots(vec2 uv) {
    vec2 grid = floor(uv * halftone_dot_size);
    vec2 cell = fract(uv * halftone_dot_size);
    vec2 center = vec2(0.5);
    float dist = distance(cell, center);
    float dot = smoothstep(0.3, 0.2, dist);
    return dot * halftone_intensity;
}

void fragment() {
    vec2 uv = UV;
    
    // Paper texture noise
    float paper_noise = noise(uv * 2.0);
    paper_noise = mix(0.0, paper_texture_strength, paper_noise);
    
    // Halftone dots
    float dots = halftone_dots(uv);
    
    // Combine paper color with texture and dots
    vec3 final_color = paper_color.rgb;
    final_color += paper_noise;
    final_color -= dots; // Subtle halftone effect
    
    // Clamp to valid range
    final_color = clamp(final_color, 0.0, 1.0);
    
    COLOR = vec4(final_color, paper_color.a);
}
