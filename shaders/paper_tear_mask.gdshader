shader_type canvas_item;

uniform sampler2D prev_frame;
uniform float fade_speed = 0.5;

void fragment() {
    vec4 prev = texture(prev_frame, SCREEN_UV);
    // Slowly fade the white mask to black
    float new_alpha = max(0.0, prev.r - fade_speed * TIME); 
    // Wait, simple subtraction might not work well with TIME in this context if not reset.
    // Usually persistence is done by blending the current drawing with a slightly darkened version of the previous frame.
    COLOR = vec4(new_alpha, new_alpha, new_alpha, 1.0);
}

