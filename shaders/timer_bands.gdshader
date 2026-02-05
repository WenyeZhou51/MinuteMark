shader_type canvas_item;

uniform float speed = 2.0;
uniform float band_count = 10.0;
uniform float thickness = 0.1;
uniform float angle = 1.0;
uniform bool move_right = true;
uniform bool point_right = true;

void fragment() {
    vec2 uv = UV;
    
    // Move UV.x over time
    float time_offset = TIME * speed;
    float x_pos;
    
    if (move_right) {
        // Moving towards center from left
        x_pos = uv.x - time_offset;
    } else {
        // Moving towards center from right
        x_pos = uv.x + time_offset;
    }
    
    // Repeat the pattern
    float pattern_x = fract(x_pos * band_count);
    
    // Create chevron shape
    // If point_right is true, shape is >
    // If point_right is false, shape is <
    
    float chevron = abs(uv.y - 0.5) * angle;
    
    // The base math abs(uv.y - 0.5) creates a < shape (0 at center, higher at edges)
    // To get > (point right), we invert the pattern_x
    if (point_right) {
        pattern_x = 1.0 - pattern_x;
    }
    
    // Distance to the chevron line
    float dist = abs(pattern_x - chevron);
    
    // Antialiased line
    float line = smoothstep(thickness, thickness - 0.05, dist);
    
    COLOR = vec4(1.0, 1.0, 1.0, line * 0.6);
}
