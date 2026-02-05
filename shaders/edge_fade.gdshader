shader_type canvas_item;

uniform float left_fade_width = 0.2;
uniform float right_fade_width = 0.2;

void fragment() {
    // Basic color from the node (modulate or stylebox color)
    vec4 color = COLOR;
    
    // Calculate edge fade
    float left_alpha = 1.0;
    if (left_fade_width > 0.0) {
        left_alpha = clamp(UV.x / left_fade_width, 0.0, 1.0);
    }
    
    float right_alpha = 1.0;
    if (right_fade_width > 0.0) {
        right_alpha = clamp((1.0 - UV.x) / right_fade_width, 0.0, 1.0);
    }
    
    float edge_fade = min(left_alpha, right_alpha);
    
    COLOR = vec4(color.rgb, color.a * edge_fade);
}
