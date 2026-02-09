shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Calculate how far from center: 0.0 at edges, 0.5 at center
	float dist_from_edge = min(UV.x, 1.0 - UV.x);
	// The blackout boundary moves inward as progress increases
	// At progress=0: boundary=0 (nothing black), at progress=1: boundary=0.5 (everything black)
	float boundary = progress * 0.5;
	// If pixel is outside the boundary, turn it black but keep original alpha
	if (dist_from_edge < boundary) {
		tex.rgb = vec3(0.0);
	}
	COLOR = tex;
}
