shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float posterize_levels : hint_range(2.0, 12.0) = 5.0;
uniform float radius : hint_range(0.0, 1.0) = 0.45;
uniform float edge_softness : hint_range(0.0, 0.3) = 0.08;
uniform vec4 tint_color : source_color = vec4(1.0, 0.3, 0.6, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);

	vec3 posterized = floor(screen_col.rgb * posterize_levels + 0.5) / posterize_levels;
	posterized = mix(posterized, posterized * tint_color.rgb, tint_strength);

	float dist = distance(UV, vec2(0.5));
	float mask = 1.0 - smoothstep(radius - edge_softness, radius + edge_softness, dist);

	vec3 final_col = mix(screen_col.rgb, posterized, mask);
	COLOR = vec4(final_col, 1.0);
}
