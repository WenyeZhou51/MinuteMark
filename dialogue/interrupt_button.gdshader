shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White
uniform vec4 base_color_ref : source_color = vec4(0.85, 0.1, 0.1, 1.0); // Red
uniform float tolerance : hint_range(0.0, 1.0) = 0.4;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sheen_progress : hint_range(-1.0, 2.0) = -1.0;
uniform float sheen_width : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec4 curr_color = COLOR;
    
    // Calculate distance to the base red color
    float dist = distance(curr_color.rgb, base_color_ref.rgb);
    
    // Only replace if it matches the base color (preserving text and borders)
    if (dist < tolerance) {
        // Fade from right to left means if UV.x > (1.0 - progress) we change color
        // But user asked "fade to white from right to left"
        // Standard progress usually goes 0 -> 1.
        // If progress=0, no white. If progress=1, all white.
        // "From right to left" implies the white starts at the right edge and moves left.
        // So if UV.x > (1.0 - progress), it should be white.
        
        if (UV.x > (1.0 - progress)) {
            curr_color.rgb = target_color.rgb;
        }
        
        // Apply flash
        curr_color.rgb = mix(curr_color.rgb, vec3(1.0), flash_amount);
        
        // Apply metallic sheen
        // Diagonal line equation: x + y = sheen_progress * 2.0 (approx)
        float sheen_pos = (UV.x + UV.y) * 0.5;
        float sheen = smoothstep(sheen_progress - sheen_width, sheen_progress, sheen_pos) * 
                     (1.0 - smoothstep(sheen_progress, sheen_progress + sheen_width, sheen_pos));
        
        curr_color.rgb += sheen * 0.4;
    }
    
    COLOR = curr_color;
}
