shader_type canvas_item;

// ============================================================================
// MASTER CONTROL
// ============================================================================
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

// ============================================================================
// OUTLINE
// ============================================================================
uniform float outline_width : hint_range(0.0, 50.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0);

// ============================================================================
// GLOW
// ============================================================================
uniform float glow_size : hint_range(0.0, 100.0) = 10.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);

// ============================================================================
// SCREEN-SPACE CHROMATIC DISTORTION (OPTIONAL)
// ============================================================================
uniform bool enable_screen_space = false;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.0;
uniform float chromatic_strength : hint_range(0.0, 0.05) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// ============================================================================
// PULSE CONTROL
// ============================================================================
uniform float pulse_speed : hint_range(0.1, 10.0) = 1.0;
uniform float pulse_strength : hint_range(0.0, 0.25) = 0.05;

// ============================================================================
// FRAGMENT
// ============================================================================
void fragment() {
	// Calculate pulse (0.0 to 1.0)
	float pulse = (sin(TIME * pulse_speed * TAU) * 0.5) + 0.5;
	
	// Shrink the letter slightly so the pulse and glow have room to expand 
	// without hitting the label's texture boundaries
	float margin_scale = 0.8; 
	float scale = (1.0 + (pulse * pulse_strength)) * margin_scale;
	
	// Scale UVs from center
	vec2 scaled_uv = (UV - 0.5) / scale + 0.5;

	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, scaled_uv);
	float alpha = base.a;

	vec4 color = base;

	// Skip heavy work when intensity is zero
	bool active = intensity > 0.0;

	// ------------------------------------------------------------------------
	// OUTLINE
	// ------------------------------------------------------------------------
	float outline = 0.0;

	if (active && outline_width > 0.0 && alpha < 1.0) {
		int radius = int(ceil(outline_width));
		float max_alpha = 0.0;

		for (int x = -radius; x <= radius; x++) {
			for (int y = -radius; y <= radius; y++) {
				if (x == 0 && y == 0) continue;

				float dist = length(vec2(float(x), float(y))
);
				if (dist > outline_width) continue;

				vec2 offset = vec2(float(x), float(y)) * pixel;
				max_alpha = max(
					max_alpha,
					texture(TEXTURE, scaled_uv + offset).a
				);
			}
		}

		outline = max_alpha * (1.0 - alpha);
	}

	// ------------------------------------------------------------------------
	// GLOW
	// ------------------------------------------------------------------------
	float glow = 0.0;

	if (active && glow_size > 0.0 && alpha < 1.0) {
		int radius = int(ceil(glow_size));
		float weight_sum = 0.0;

		for (int x = -radius; x <= radius; x++) {
			for (int y = -radius; y <= radius; y++) {
				float dist = length(vec2(float(x), float(y)));
				if (dist > glow_size || dist <= outline_width) continue;

				vec2 offset = vec2(float(x), float(y)) * pixel;
				float a = texture(TEXTURE, scaled_uv + offset).a;

				float weight = exp(
					- (dist * dist) / (glow_size * glow_size * 0.5)
				);

				glow += a * weight;
				weight_sum += weight;
			}
		}

		if (weight_sum > 0.0) {
			glow = (glow / weight_sum) * glow_intensity * (1.0 - alpha);
		}
	}

	// ------------------------------------------------------------------------
	// SCREEN-SPACE CHROMATIC DISTORTION
	// ------------------------------------------------------------------------
	vec4 screen_color = vec4(0.0);

	if (active && enable_screen_space && distortion_strength > 0.0 && alpha > 0.0) {
		vec2 center = vec2(0.5);
		vec2 to_center = SCREEN_UV - center;
		float dist = length(to_center);

		vec2 distortion = to_center * distortion_strength * dist;

		vec2 uv_r = SCREEN_UV - distortion - to_center * chromatic_strength;
		vec2 uv_g = SCREEN_UV - distortion;
		vec2 uv_b = SCREEN_UV - distortion + to_center * chromatic_strength;

		screen_color = vec4(
			texture(screen_texture, uv_r).r,
			texture(screen_texture, uv_g).g,
			texture(screen_texture, uv_b).b,
			1.0
		);
	}

	// ------------------------------------------------------------------------
	// COMPOSITION
	// ------------------------------------------------------------------------

	// Screen-space blend
	if (active && enable_screen_space && distortion_strength > 0.0 && alpha > 0.0) {
		color.rgb = mix(
			color.rgb,
			screen_color.rgb,
			alpha * intensity
		);
	}

	// Outline blend
	if (outline > 0.0) {
		float amt = outline * intensity * outline_color.a;
		color.rgb = mix(color.rgb, outline_color.rgb, amt);
		color.a = max(color.a, amt);
	}

	// Glow blend
	if (glow > 0.0) {
		float amt = glow * intensity * glow_color.a;
		color.rgb = mix(color.rgb, glow_color.rgb, amt);
		color.a = max(color.a, amt);
	}

	COLOR = color;
}
