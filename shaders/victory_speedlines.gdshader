shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform vec4 line_color_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 line_color_black : source_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform float speed : hint_range(0.0, 20.0) = 5.0;
uniform float line_density : hint_range(1.0, 200.0) = 50.0;
uniform float line_thickness : hint_range(0.0, 1.0) = 0.4;
uniform float angle : hint_range(0.0, 360.0) = 30.0;

float random(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
    float angle_rad = radians(angle);
    
    // Create a rotation matrix for the UVs
    mat2 rot = mat2(vec2(cos(angle_rad), -sin(angle_rad)), vec2(sin(angle_rad), cos(angle_rad)));
    vec2 rotated_uv = rot * (UV - 0.5);
    
    // Coordinate along the lines (scrolling) and across the lines (density)
    float across = rotated_uv.y * line_density;
    float along = rotated_uv.x + TIME * speed;
    
    // Seed for randomness based on the 'across' coordinate
    float line_id = floor(across);
    float rand_val_w = random(line_id);
    float rand_val_b = random(line_id + 7.0);
    
    // Offset each line along its length for variety
    float line_pos = along + random(line_id * 13.0) * 10.0;
    
    // Create broken/dashing lines
    float dash = step(0.3, fract(line_pos * 0.5));
    
    // Determine white and black line presence
    float is_white = step(1.0 - line_thickness * 0.4, rand_val_w) * dash;
    float is_black = step(1.0 - line_thickness * 0.3, rand_val_b) * dash;
    
    vec4 color = bg_color;
    
    // Blend lines
    color = mix(color, line_color_black, is_black);
    color = mix(color, line_color_white, is_white);
    
    COLOR = color;
}
