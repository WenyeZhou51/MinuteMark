shader_type canvas_item;

uniform float roll_amount : hint_range(0.0, 1.0) = 0.0;
uniform float cylinder_radius = 0.15;

void fragment() {
    vec2 uv = UV;
    
    // The point where the paper is being lifted and rolled
    float split_x = 1.0 - roll_amount;
    
    if (uv.x > split_x) {
        // This is the rolled part
        float dist_into_roll = (uv.x - split_x);
        
        // Circular wrap
        float angle = (dist_into_roll / cylinder_radius);
        
        // Projection of the circle onto the flat plane
        float projected_x = split_x + sin(angle) * cylinder_radius;
        
        // Hide if it's turned away too far (back of the roll)
        if (angle > PI * 1.5) discard;
        
        // Sample the texture at the point that was "pulled" into this position
        // We simulate the paper being pulled from the right
        vec2 rolled_uv = vec2(split_x + angle * cylinder_radius, uv.y);
        
        if (rolled_uv.x > 1.0) discard;
        
        vec4 col = texture(TEXTURE, rolled_uv);
        
        // Shading: lighten the top of the curve, darken the inside
        float shading = cos(angle);
        if (shading > 0.0) {
            col.rgb *= (1.0 + shading * 0.3);
        } else {
            col.rgb *= (0.5 + abs(shading) * 0.2); // Inside is darker
        }
        
        COLOR = col;
    } else {
        // Flat part of the paper
        COLOR = texture(TEXTURE, uv);
    }
}
