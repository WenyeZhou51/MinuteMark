shader_type canvas_item;

uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.8, 0.35);
uniform float edge_softness : hint_range(0.0, 0.5) = 0.15;
uniform float top_fade : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	float center_dist = abs(UV.x - 0.5) * 2.0;
	float cone_width = mix(top_fade, 1.0, UV.y);
	float h_mask = 1.0 - smoothstep(cone_width - edge_softness, cone_width, center_dist);
	float v_fade = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	float alpha = h_mask * v_fade * light_color.a;
	COLOR = vec4(light_color.rgb, alpha);
}
