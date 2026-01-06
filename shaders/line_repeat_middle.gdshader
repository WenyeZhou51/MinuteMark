shader_type canvas_item;

uniform sampler2D main_texture : hint_default_white;
uniform float start_percent : hint_range(0.0, 1.0) = 0.35;
uniform float end_percent : hint_range(0.0, 1.0) = 0.75;
uniform bool is_finished = false;
uniform float line_length_px = 100.0;
uniform float texture_width_px = 256.0;

void fragment() {
    float x = UV.x;
    float mapped_x = 0.0;
    
    float start_w = start_percent;
    float mid_w = end_percent - start_percent;
    float end_w = 1.0 - end_percent;
    
    float start_px = texture_width_px * start_w;
    float end_px = texture_width_px * end_w;
    
    float start_t = clamp(start_px / line_length_px, 0.0, 0.4);
    float end_t = is_finished ? clamp(1.0 - (end_px / line_length_px), 0.6, 1.0) : 1.0;
    
    if (x < start_t) {
        mapped_x = (x / start_t) * start_w;
    } else if (x < end_t) {
        float mid_progress_px = (x - start_t) * line_length_px;
        mapped_x = start_w + mod(mid_progress_px / (texture_width_px * mid_w), 1.0) * mid_w;
    } else {
        float end_progress = (x - end_t) / (1.0 - end_t);
        mapped_x = end_percent + end_progress * end_w;
    }
    
    COLOR = texture(main_texture, vec2(mapped_x, UV.y));
}

