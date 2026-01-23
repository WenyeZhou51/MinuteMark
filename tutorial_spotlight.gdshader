shader_type canvas_item;

uniform vec2 spotlight_position = vec2(0.5, 0.5); // Normalized screen coordinates (0-1)
uniform float spotlight_radius = 0.2; // Spotlight size
uniform float edge_softness = 0.15; // How soft the spotlight edge is
uniform float darkness = 0.85; // How dark the rest of the scene is (0-1)

void fragment() {
    // Get the distance from current pixel to spotlight center
    vec2 uv = SCREEN_UV;
    float distance_to_center = length(uv - spotlight_position);
    
    // Create smooth spotlight falloff
    float spotlight = 1.0 - smoothstep(spotlight_radius, spotlight_radius + edge_softness, distance_to_center);
    
    // Mix between dark and light based on spotlight
    float alpha = darkness * (1.0 - spotlight);
    
    // Output black color with calculated alpha
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

