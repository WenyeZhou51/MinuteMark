shader_type canvas_item;

uniform sampler2D mask_texture : repeat_disable;
uniform sampler2D noise_texture : repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;
uniform float edge_thickness : hint_range(0.0, 0.05) = 0.01;
uniform vec4 edge_color : source_color = vec4(0.92, 0.92, 0.85, 1.0); // Off-white pulp

void fragment() {
    // 1. Get the base mask value (0 = world, 1 = tear)
    float mask = texture(mask_texture, SCREEN_UV).r;
    
    // 2. Sample noise and use it to perturb the mask threshold
    float noise = texture(noise_texture, SCREEN_UV).r;
    float tear_threshold = 0.5 + (noise - 0.5) * noise_strength;
    
    // 3. Calculate the actual tear area
    float tear = step(tear_threshold, mask);
    
    // 4. Calculate the "pulp" edge area
    float edge = step(tear_threshold - edge_thickness, mask) - tear;
    
    vec4 world_color = texture(screen_texture, SCREEN_UV);
    vec4 void_color = vec4(0.0, 0.0, 0.0, 1.0); // Black gap
    
    // 5. Final Composite
    vec4 final_color = mix(world_color, edge_color, edge);
    final_color = mix(final_color, void_color, tear);
    
    COLOR = final_color;
}
