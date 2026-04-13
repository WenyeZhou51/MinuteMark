shader_type canvas_item;

uniform float fire_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float char_amount : hint_range(0.0, 1.0) = 0.0;
uniform float speed : hint_range(0.5, 5.0) = 2.5;

uniform vec3 color_core : source_color = vec3(1.0, 0.95, 0.5);
uniform vec3 color_mid : source_color = vec3(1.0, 0.4, 0.05);
uniform vec3 color_tip : source_color = vec3(0.6, 0.08, 0.0);

uniform float fire_reach : hint_range(0.05, 0.6) = 0.35;
uniform float fire_width : hint_range(0.0, 0.5) = 0.2;
uniform float fire_turbulence : hint_range(0.0, 2.0) = 1.2;

uniform float fluctuation_speed : hint_range(1.0, 25.0) = 12.0;
uniform float fluctuation_amount : hint_range(0.0, 0.8) = 0.45;

uniform float particle_count : hint_range(0.0, 25.0) = 18.0;
uniform float particle_size : hint_range(0.002, 0.04) = 0.014;
uniform float particle_speed : hint_range(0.5, 5.0) = 1.8;
uniform float particle_spread : hint_range(0.0, 0.6) = 0.4;
uniform vec3 particle_color : source_color = vec3(1.0, 0.7, 0.15);

uniform float rim_glow : hint_range(0.0, 3.0) = 1.5;
uniform vec3 rim_color : source_color = vec3(1.0, 0.35, 0.0);

uniform float heat_distortion : hint_range(0.0, 0.04) = 0.008;
uniform float edge_warp_strength : hint_range(0.0, 0.1) = 0.03;
uniform float edge_warp_speed : hint_range(1.0, 30.0) = 15.0;

uniform vec3 char_color : source_color = vec3(0.05, 0.03, 0.02);

// =============================================================================
// NOISE
// =============================================================================

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 5; i++) {
		val += amp * value_noise(p * freq);
		freq *= 2.03;
		amp *= 0.48;
	}
	return val;
}

float jagged_noise(vec2 p, float t) {
	float n1 = value_noise(p * 8.0 + vec2(t * 5.3, t * 3.7));
	float n2 = value_noise(p * 16.0 + vec2(-t * 7.1, t * 4.9));
	float n3 = value_noise(p * 24.0 + vec2(t * 9.2, -t * 6.3));
	return (n1 * 0.5 + n2 * 0.3 + n3 * 0.2) * 2.0 - 1.0;
}

// =============================================================================
// FIRE PARTICLE SIMULATION
// =============================================================================

float simulate_particles(vec2 uv, float t, float center_x) {
	float result = 0.0;
	for (float i = 0.0; i < particle_count; i++) {
		float id = i + 1.0;
		float cycle_offset = hash11(id * 73.13);
		float ct = fract(t * particle_speed * 0.3 + cycle_offset);
		float seed = hash11(id * 37.97 + floor(t * particle_speed * 0.3 + cycle_offset));

		float start_x = center_x + (seed - 0.5) * particle_spread;
		float drift_x = (hash11(id * 91.1 + seed) - 0.5) * particle_spread;
		drift_x += sin(ct * 12.0 + id) * 0.03;

		vec2 particle_pos = vec2(
			start_x + drift_x * ct,
			0.5 - ct * fire_reach * 2.5
		);

		float sz = particle_size * (1.0 - ct * 0.6);
		float d = length(uv - particle_pos);
		float glow = smoothstep(sz, sz * 0.15, d);
		float life_fade = smoothstep(1.0, 0.5, ct) * smoothstep(0.0, 0.06, ct);
		result += glow * life_fade;
	}
	return min(result, 1.5);
}

// =============================================================================
// FRAGMENT
// =============================================================================

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;

	float f1 = sin(TIME * fluctuation_speed);
	float f2 = sin(TIME * fluctuation_speed * 1.73 + 2.0);
	float f3 = sin(TIME * fluctuation_speed * 2.41 + 4.5);
	float f4 = sin(TIME * fluctuation_speed * 0.67 + 1.2);
	float fluctuation = 1.0 - fluctuation_amount
		+ fluctuation_amount * (0.25 + 0.25 * f1 + 0.2 * f2 + 0.15 * f3 + 0.15 * f4);

	// Edge warp + heat shimmer
	float warp_x = jagged_noise(uv, TIME * edge_warp_speed) * edge_warp_strength;
	float warp_y = jagged_noise(uv + vec2(50.0, 50.0), TIME * edge_warp_speed * 0.8) * edge_warp_strength * 0.6;

	vec2 shimmer = vec2(
		value_noise(uv * 10.0 + vec2(t * 1.5, t * 0.6)) - 0.5,
		value_noise(uv * 10.0 + vec2(t * 0.7, t * 1.4)) - 0.5
	) * heat_distortion * fire_intensity;

	vec2 warped_uv = uv + vec2(warp_x, warp_y) * fire_intensity + shimmer;
	vec4 sprite = texture(TEXTURE, clamp(warped_uv, vec2(0.0), vec2(1.0)));
	vec4 sprite_raw = texture(TEXTURE, uv);

	// Fuel / edge detection for rectangular objects
	float fuel = 0.0;
	float dist_to_fuel = 99.0;
	float sprite_edge = 0.0;

	if (sprite_raw.a < 0.15) {
		// Outside the object — search downward and sideways for fuel
		for (float i = 1.0; i <= 10.0; i += 1.0) {
			float dy = i / 10.0 * fire_reach;
			float wobble = (fbm(vec2(i * 5.1, t * 0.9)) - 0.5) * fire_width * fire_turbulence;
			vec2 s_uv = vec2(uv.x + wobble, uv.y + dy);
			if (s_uv.x >= 0.0 && s_uv.x <= 1.0 && s_uv.y <= 1.0) {
				float a = texture(TEXTURE, s_uv).a;
				if (a > 0.15) {
					fuel = max(fuel, a);
					dist_to_fuel = min(dist_to_fuel, dy);
				}
			}
		}
		for (float j = 1.0; j <= 4.0; j += 1.0) {
			float dx = j / 4.0 * fire_width;
			float al = 0.0;
			float ar = 0.0;
			if (uv.x - dx >= 0.0) al = texture(TEXTURE, vec2(uv.x - dx, uv.y)).a;
			if (uv.x + dx <= 1.0) ar = texture(TEXTURE, vec2(uv.x + dx, uv.y)).a;
			float side_a = max(al, ar);
			if (side_a > 0.15) {
				fuel = max(fuel, side_a * 0.5);
				dist_to_fuel = min(dist_to_fuel, dx * 0.5);
			}
		}
	} else {
		dist_to_fuel = 0.0;
		fuel = sprite_raw.a;

		float a_u = texture(TEXTURE, uv + vec2(0.0, -px.y * 6.0)).a;
		float a_d = texture(TEXTURE, uv + vec2(0.0, px.y * 6.0)).a;
		float a_l = texture(TEXTURE, uv + vec2(-px.x * 6.0, 0.0)).a;
		float a_r = texture(TEXTURE, uv + vec2(px.x * 6.0, 0.0)).a;
		float a_ul = texture(TEXTURE, uv + vec2(-px.x * 5.0, -px.y * 5.0)).a;
		float a_ur = texture(TEXTURE, uv + vec2(px.x * 5.0, -px.y * 5.0)).a;
		sprite_edge = 1.0 - min(min(min(a_u, a_d), min(a_l, a_r)), min(a_ul, a_ur));
	}

	// Fire noise
	float fn1 = fbm(vec2(uv.x * 5.0, uv.y * 3.5 - t * 2.2));
	float fn2 = fbm(vec2(uv.x * 9.0 + 50.0, uv.y * 5.0 - t * 3.0));
	float fn3 = fbm(vec2(uv.x * 14.0 - 20.0, uv.y * 8.0 - t * 4.0));
	float fn4 = value_noise(vec2(uv.x * 20.0, uv.y * 12.0 - t * 5.5));
	float fire_noise = fn1 * 0.35 + fn2 * 0.3 + fn3 * 0.2 + fn4 * 0.15;

	// Fire mask
	float fire_mask = 0.0;

	if (sprite_raw.a < 0.15 && fuel > 0.1) {
		float height_fade = 1.0 - smoothstep(0.0, fire_reach, dist_to_fuel);
		fire_mask = height_fade * height_fade * fire_noise * fuel * 3.0;
		float spike = pow(fire_noise, 1.8) * height_fade * 2.0;
		fire_mask = max(fire_mask, spike * fuel);
	}

	if (sprite_raw.a > 0.1) {
		float top_weight = 1.0 - uv.y;
		float edge_fire = sprite_edge * fire_noise * rim_glow * mix(0.6, 1.5, top_weight);
		float edge_spike = sprite_edge * pow(fire_noise, 1.5) * 1.2;
		fire_mask = max(fire_mask, max(edge_fire, edge_spike));
	}

	fire_mask *= fire_intensity * fluctuation;

	// Per-column flicker
	float col_id = floor(uv.x * 7.0);
	float col_flicker = 0.65 + 0.35 * sin(TIME * 23.0 + hash11(col_id) * 6.283)
		* (0.7 + 0.3 * cos(TIME * 31.0 + hash11(col_id + 10.0) * 6.283));
	fire_mask *= col_flicker;

	// Fire color gradient
	float color_t = clamp(dist_to_fuel / max(fire_reach * 0.65, 0.001), 0.0, 1.0);
	vec3 fire_col = mix(color_core, color_mid, smoothstep(0.0, 0.3, color_t));
	fire_col = mix(fire_col, color_tip, smoothstep(0.2, 0.8, color_t));
	fire_col *= 0.85 + fire_noise * 0.5;

	// Ember particles
	float particles = simulate_particles(uv, TIME, 0.5) * fire_intensity * fluctuation;
	// Only show particles near the object
	float near_fuel = step(0.05, fuel + sprite_raw.a);
	particles *= near_fuel;

	// Rim glow
	float rim = sprite_edge * rim_glow * fluctuation * fire_intensity;
	rim *= 0.7 + 0.3 * sin(TIME * 16.0 + uv.y * 20.0);
	vec3 rim_col = rim_color * rim;

	// Charring: darken the base color toward black as char_amount increases
	vec3 base_color = sprite.rgb;
	float char_noise = fbm(uv * 6.0 + vec2(3.7, 1.2));
	float char_mask = smoothstep(0.0, 1.0, char_amount + char_noise * 0.3 - 0.15);
	base_color = mix(base_color, char_color, char_mask);

	// Composite
	float fire_alpha = smoothstep(0.05, 0.3, fire_mask);
	vec3 fire_result = fire_col;
	vec3 particle_result = particle_color * particles * 4.0;

	vec3 final_color = base_color + rim_col;
	if (sprite.a > 0.1) {
		final_color = mix(final_color, fire_result, fire_alpha);
		final_color += particle_result;
	} else {
		final_color = fire_result + particle_result;
	}

	float final_alpha = sprite.a;
	float fire_ext_alpha = max(fire_alpha, particles * 0.8) * fire_intensity;
	final_alpha = max(final_alpha, fire_ext_alpha);

	// Fade out the whole object during dying state via fire_intensity approaching 0
	COLOR = vec4(final_color, final_alpha);
}
