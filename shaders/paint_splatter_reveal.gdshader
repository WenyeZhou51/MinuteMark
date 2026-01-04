shader_type canvas_item;

// Main animation control
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;

// Reveal configuration
uniform vec2 center_position = vec2(0.5, 0.5);
uniform float center_reveal_size : hint_range(0.0, 1.0) = 0.4; // Initial instant reveal size
uniform float edge_roughness : hint_range(0.0, 1.0) = 0.3;
uniform float detail_scale : hint_range(1.0, 50.0) = 8.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.05;
uniform float aspect_ratio = 1.0;
uniform float noise_seed : hint_range(0.0, 100.0) = 1.0;

// Outline configuration
uniform float outline_thickness : hint_range(0.0, 0.2) = 0.03;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Debug/Utility
uniform bool shader_active_check = false;
uniform bool debug_show_mask_only = false;

// Unique names for noise functions
vec3 mod289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute_3(vec3 x) { return mod289_3(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289_2(i);
    vec3 p = permute_3(permute_3(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m; m = m * m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float multi_octave_noise(vec2 pos) {
    float total = 0.0;
    float amp = 1.0;
    float scale = 1.0;
    for (int i = 0; i < 3; i++) {
        total += snoise(pos * scale) * amp;
        amp *= 0.5;
        scale *= 2.0;
    }
    return total;
}

void fragment() {
    // 1. Hard Discard Failsafe
    if (reveal_progress <= 0.0001) {
        discard;
    }
    
    vec4 tex = texture(TEXTURE, UV);
    
    // 2. Setup Distance Math
    vec2 uv_offset = UV - center_position;
    uv_offset.x *= aspect_ratio;
    float dist = length(uv_offset);
    
    // 3. Noise Generation
    float angle = atan(uv_offset.y, uv_offset.x);
    float n = multi_octave_noise(vec2(angle * detail_scale, dist * detail_scale + noise_seed));
    float noise_val = n * edge_roughness;
    
    // 4. Reveal Calculation (Instant Center + Sprawl)
    // Map reveal_progress 0..1 to radius center_reveal_size..1.5
    float radius = mix(center_reveal_size, 1.5, reveal_progress);
    float threshold = radius + noise_val;
    
    // 5. Create Masks for Image and Outline
    // Inner mask (the image)
    float inner_mask = 1.0 - smoothstep(threshold - edge_softness, threshold + edge_softness, dist);
    
    // Outer mask (the outline)
    float outer_threshold = threshold + outline_thickness;
    float outer_mask = 1.0 - smoothstep(outer_threshold - edge_softness, outer_threshold + edge_softness, dist);
    
    // 6. Composition
    if (outer_mask < 0.001) {
        discard; // Fully hidden
    }
    
    vec3 final_rgb;
    float final_a;
    
    if (inner_mask > 0.5) {
        // Pixel is inside the image reveal
        final_rgb = tex.rgb;
        final_a = tex.a;
        
        // Debug Tint
        if (shader_active_check) {
            final_rgb.b = clamp(final_rgb.b + 0.2, 0.0, 1.0);
        }
    } else {
        // Pixel is in the outline area
        final_rgb = outline_color.rgb;
        final_a = outline_color.a * outer_mask;
    }
    
    if (debug_show_mask_only) {
        COLOR = vec4(vec3(inner_mask), 1.0);
    } else {
        COLOR = vec4(final_rgb, final_a);
    }
}
