shader_type canvas_item;

// Moving spotlight: dark overlay with a circular "lit" area (transparent hole).
// spotlight_center and spotlight_radius are in UV space (0-1).

uniform vec2 spotlight_center = vec2(0.5, 0.5);
uniform float spotlight_radius : hint_range(0.0, 1.0) = 0.25;
uniform vec4 dark_color : source_color = vec4(0.02, 0.02, 0.04, 0.92);
uniform float soft_edge : hint_range(0.0, 0.5) = 0.03;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, spotlight_center);
	// Soft falloff at the edge of the spotlight
	float lit = 1.0 - smoothstep(spotlight_radius - soft_edge, spotlight_radius + soft_edge, d);
	// Outside = dark, inside = transparent so scene shows through
	COLOR = vec4(dark_color.rgb, dark_color.a * (1.0 - lit));
}
