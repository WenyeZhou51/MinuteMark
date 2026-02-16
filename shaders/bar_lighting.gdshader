shader_type canvas_item;

// Bar-style lighting: vertical beam(s) from above. Light can open (widen), sparkle, and close (narrow).
// Feels like overhead bar lights, not a camera spotlight.

uniform float beam_center_x : hint_range(0.0, 1.0) = 0.5;
uniform float beam_half_width : hint_range(0.0, 0.5) = 0.15;  // half-width of vertical strip in UV
uniform vec4 dark_color : source_color = vec4(0.01, 0.01, 0.02, 0.97);
uniform float soft_edge : hint_range(0.0, 0.2) = 0.02;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.0;  // 0 = no sparkle, 1 = full flicker
uniform float top_brightness : hint_range(0.0, 1.0) = 1.0;  // optional: dimmer toward bottom (1 = even)

// Fire/torch point lights (in UV 0-1). radius 0 = disabled.
uniform vec2 fire_1_pos = vec2(-1.0, -1.0);
uniform float fire_1_radius : hint_range(0.0, 0.5) = 0.0;
uniform vec2 fire_2_pos = vec2(-1.0, -1.0);
uniform float fire_2_radius : hint_range(0.0, 0.5) = 0.0;

// Quick noise for sparkle flicker
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float dist_from_center = abs(uv.x - beam_center_x);
	// Cone: narrow at top (light source), wide at bottom. Half-width grows with uv.y.
	float effective_half_width = beam_half_width * uv.y;
	float edge = soft_edge * max(uv.y, 0.05);
	float lit = 1.0 - smoothstep(effective_half_width - edge, effective_half_width + edge, dist_from_center);
	// Slightly brighter at top (light from above) - optional gradient
	float from_top = 1.0 - uv.y;
	lit *= mix(1.0, 0.4 + 0.6 * from_top, 1.0 - top_brightness);
	// Sparkle: rapid flicker when sparkle_amount > 0
	float sparkle = 1.0;
	if (sparkle_amount > 0.01) {
		float n = hash(floor(uv * 80.0) + floor(TIME * 20.0));
		sparkle = 1.0 - sparkle_amount * (0.3 + 0.5 * n);
	}
	lit *= sparkle;
	// Fire lights: circular lit areas that lighten the overlay
	if (fire_1_radius > 0.001) {
		float d1 = distance(uv, fire_1_pos);
		lit = max(lit, 1.0 - smoothstep(fire_1_radius - 0.02, fire_1_radius + 0.02, d1));
	}
	if (fire_2_radius > 0.001) {
		float d2 = distance(uv, fire_2_pos);
		lit = max(lit, 1.0 - smoothstep(fire_2_radius - 0.02, fire_2_radius + 0.02, d2));
	}
	lit = clamp(lit, 0.0, 1.0);
	// Outside = dark, inside = transparent
	COLOR = vec4(dark_color.rgb, dark_color.a * (1.0 - lit));
}
