shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 target_color : source_color = vec4(0.1, 0.6, 0.1, 1.0); // Green
uniform vec4 base_color_ref : source_color = vec4(0.85, 0.1, 0.1, 1.0); // Red
uniform float tolerance : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    vec4 curr_color = COLOR;
    
    // Calculate distance to the base red color
    float dist = distance(curr_color.rgb, base_color_ref.rgb);
    
    // Only replace if it matches the base color (preserving text and borders)
    if (dist < tolerance) {
        if (UV.x <= progress) {
            COLOR.rgb = target_color.rgb;
        }
    }
}

