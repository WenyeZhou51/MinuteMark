shader_type canvas_item;

uniform sampler2D mask_texture : repeat_disable;
uniform sampler2D noise_texture : repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;
uniform float edge_thickness : hint_range(0.0, 0.05) = 0.02;
uniform vec4 edge_color : source_color = vec4(0.92, 0.92, 0.85, 1.0);

void fragment() {
    // 1. Get the base reveal from the mask viewport
    // In Godot 4, SubViewport textures are always vertically flipped
    vec2 mask_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
    vec4 mask_color = texture(mask_texture, mask_uv);
    float mask_alpha = mask_color.a;
    
    // 2. Sample noise and use it to perturb the mask threshold
    float noise = texture(noise_texture, SCREEN_UV).r;
    float tear_threshold = 0.5 + (noise - 0.5) * noise_strength;
    
    // 3. Calculate the actual tear area
    float tear = step(tear_threshold, mask_alpha);
    
    // 4. Calculate the "pulp" edge area
    float edge = step(tear_threshold - edge_thickness, mask_alpha) - tear;
    
    vec4 world_color = texture(screen_texture, SCREEN_UV);
    
    // 5. Final Composite
    vec4 final_color = mix(world_color, edge_color, edge);
    final_color = mix(final_color, mask_color, tear);
    
    COLOR = vec4(final_color.rgb, 1.0);
}
