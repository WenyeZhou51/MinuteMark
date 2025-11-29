shader_type spatial;
render_mode unshaded;

// ===== MANUAL LIGHTING PARAMETERS =====
uniform vec3 light_direction : source_color = vec3(0.0, -1.0, 0.0);
uniform vec3 light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float light_energy : hint_range(0.0, 16.0, 0.1) = 1.0;
uniform float ambient_light : hint_range(0.0, 1.0, 0.01) = 0.1;

// ===== COMIC COLOR RAMP PARAMETERS (POSTERIZATION) =====
uniform bool enable_color_ramp = true;

// Threshold 1 (darkest range: 0.0 to threshold_1_position)
uniform float threshold_1_position : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform vec4 threshold_1_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Threshold 2 (threshold_1_position to threshold_2_position)
uniform float threshold_2_position : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec4 threshold_2_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);

// Threshold 3 (threshold_2_position to threshold_3_position)
uniform float threshold_3_position : hint_range(0.0, 1.0, 0.01) = 0.6;
uniform vec4 threshold_3_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);

// Threshold 4 (threshold_3_position to threshold_4_position)
uniform float threshold_4_position : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform vec4 threshold_4_color : source_color = vec4(1.0, 0.75, 0.8, 1.0);

// Threshold 5 (brightest: threshold_4_position to 1.0)
uniform vec4 threshold_5_color : source_color = vec4(0.91, 0.44, 0.64, 1.0);

// ===== HALFTONE DOT PATTERN PARAMETERS =====
// Threshold 1 Dots (darkest range)
uniform bool threshold_1_enable_dots = false;
uniform float threshold_1_dot_scale : hint_range(1.0, 100.0, 0.5) = 20.0;
uniform float threshold_1_dot_size : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float threshold_1_dot_softness : hint_range(0.0, 0.5, 0.01) = 0.1;
uniform float threshold_1_dot_rotation : hint_range(0.0, 360.0, 1.0) = 45.0;
uniform vec4 threshold_1_dot_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Threshold 2 Dots (mid tone)
uniform bool threshold_2_enable_dots = false;
uniform float threshold_2_dot_scale : hint_range(1.0, 100.0, 0.5) = 15.0;
uniform float threshold_2_dot_size : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float threshold_2_dot_softness : hint_range(0.0, 0.5, 0.01) = 0.1;
uniform float threshold_2_dot_rotation : hint_range(0.0, 360.0, 1.0) = 15.0;
uniform vec4 threshold_2_dot_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);

// Threshold 3 Dots
uniform bool threshold_3_enable_dots = false;
uniform float threshold_3_dot_scale : hint_range(1.0, 100.0, 0.5) = 12.0;
uniform float threshold_3_dot_size : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float threshold_3_dot_softness : hint_range(0.0, 0.5, 0.01) = 0.1;
uniform float threshold_3_dot_rotation : hint_range(0.0, 360.0, 1.0) = 30.0;
uniform vec4 threshold_3_dot_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);

// Threshold 4 Dots
uniform bool threshold_4_enable_dots = false;
uniform float threshold_4_dot_scale : hint_range(1.0, 100.0, 0.5) = 10.0;
uniform float threshold_4_dot_size : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float threshold_4_dot_softness : hint_range(0.0, 0.5, 0.01) = 0.1;
uniform float threshold_4_dot_rotation : hint_range(0.0, 360.0, 1.0) = 0.0;
uniform vec4 threshold_4_dot_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);

// Threshold 5 Dots (brightest range)
uniform bool threshold_5_enable_dots = false;
uniform float threshold_5_dot_scale : hint_range(1.0, 100.0, 0.5) = 8.0;
uniform float threshold_5_dot_size : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float threshold_5_dot_softness : hint_range(0.0, 0.5, 0.01) = 0.1;
uniform float threshold_5_dot_rotation : hint_range(0.0, 360.0, 1.0) = 45.0;
uniform vec4 threshold_5_dot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ===== WATERCOLOR EFFECT =====
uniform bool enable_watercolor = false;
uniform float watercolor_scale : hint_range(0.1, 20.0, 0.1) = 5.0;
uniform float watercolor_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float watercolor_noise_scale : hint_range(0.1, 10.0, 0.1) = 2.0;
uniform float watercolor_voronoi_scale : hint_range(0.1, 20.0, 0.1) = 3.0;
uniform float watercolor_color_variation : hint_range(0.0, 1.0, 0.01) = 0.3;

// ===== OIL PAINTING / KUWAHARA FILTER =====
uniform bool enable_oil_painting = false;
uniform int kuwahara_radius : hint_range(1, 8, 1) = 3;
uniform float kuwahara_sharpness : hint_range(0.0, 2.0, 0.1) = 1.0;

// ===== LIGHTING =====
// Note: Lighting is now handled by Godot's lighting system via diffuse_toon render mode

// Calculate luminance for color ramp
float get_luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float a = dot(hash22(i + vec2(0.0, 0.0)) - 0.5, vec2(1.0));
	float b = dot(hash22(i + vec2(1.0, 0.0)) - 0.5, vec2(1.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)) - 0.5, vec2(1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)) - 0.5, vec2(1.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	
	float min_dist = 1.0;
	vec2 min_point = vec2(0.0);
	
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 neighbor = vec2(float(i), float(j));
			vec2 point = hash22(n + neighbor);
			vec2 diff = neighbor + point - f;
			float dist = length(diff);
			
			if (dist < min_dist) {
				min_dist = dist;
				min_point = point;
			}
		}
	}
	
	return vec2(min_dist, hash22(n + min_point).x);
}

float linear_light(float base, float blend) {
	if (blend < 0.5) {
		return max(0.0, base + 2.0 * blend - 1.0);
	} else {
		return min(1.0, base + 2.0 * (blend - 0.5));
	}
}

vec3 apply_watercolor(vec3 base_color, vec2 coords, float luminosity) {
	vec2 geometry_input = coords * watercolor_scale;
	float noise_value = noise(coords * watercolor_noise_scale);
	noise_value = noise_value * 0.5 + 0.5;
	float geometry_base = fract(length(geometry_input) * 0.5);
	float blended = linear_light(geometry_base, noise_value);
	vec2 voronoi_input = coords * watercolor_voronoi_scale + vec2(blended);
	vec2 voronoi_result = voronoi(voronoi_input);
	float color_mod = voronoi_result.y;
	vec3 watercolor_variation = vec3(
		color_mod,
		voronoi_result.x * 0.5 + 0.5,
		1.0 - color_mod * 0.5
	);
	vec3 result = mix(base_color, base_color * watercolor_variation, watercolor_color_variation * watercolor_intensity);
	return result;
}

// 2D rotation matrix
vec2 rotate_2d(vec2 p, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(
		p.x * c - p.y * s,
		p.x * s + p.y * c
	);
}

// Grid-based halftone pattern (comic book style)
float halftone_grid(vec2 p, float rotation_degrees) {
	// Convert rotation from degrees to radians
	float angle = rotation_degrees * 3.14159265359 / 180.0;
	
	// Apply rotation to coordinates
	vec2 rotated_p = rotate_2d(p, angle);
	
	// Create regular grid
	vec2 cell = floor(rotated_p);
	vec2 fract_p = fract(rotated_p);
	
	// Grid point is at center of each cell (0.5, 0.5)
	vec2 grid_center = vec2(0.5, 0.5);
	
	// Distance from current position to grid center
	float dist = length(fract_p - grid_center);
	
	return dist;
}

// B-spline basis function (cubic)
float bspline_basis(float t, int i) {
	if (i == 0) {
		float one_minus_t = 1.0 - t;
		return one_minus_t * one_minus_t * one_minus_t / 6.0;
	} else if (i == 1) {
		return (3.0 * t * t * t - 6.0 * t * t + 4.0) / 6.0;
	} else if (i == 2) {
		return (-3.0 * t * t * t + 3.0 * t * t + 3.0 * t + 1.0) / 6.0;
	} else { // i == 3
		return t * t * t / 6.0;
	}
}

// B-spline interpolation for 5 control points (colors)
vec4 bspline_interpolate(float t, vec4 c0, vec4 c1, vec4 c2, vec4 c3, vec4 c4) {
	// For 5 control points, we have 4 segments
	// Map t from [0,1] to the valid B-spline parameter range
	float segment = t * 4.0;
	int seg_index = int(floor(segment));
	seg_index = clamp(seg_index, 0, 3);
	float local_t = fract(segment);
	
	vec4 result;
	if (seg_index == 0) {
		// First segment: c0 to c1
		vec4 p0 = c0; // Duplicate first point for clamping
		vec4 p1 = c0;
		vec4 p2 = c1;
		vec4 p3 = c2;
		result = bspline_basis(local_t, 0) * p0 +
		         bspline_basis(local_t, 1) * p1 +
		         bspline_basis(local_t, 2) * p2 +
		         bspline_basis(local_t, 3) * p3;
	} else if (seg_index == 1) {
		// Second segment: c1 to c2
		vec4 p0 = c0;
		vec4 p1 = c1;
		vec4 p2 = c2;
		vec4 p3 = c3;
		result = bspline_basis(local_t, 0) * p0 +
		         bspline_basis(local_t, 1) * p1 +
		         bspline_basis(local_t, 2) * p2 +
		         bspline_basis(local_t, 3) * p3;
	} else if (seg_index == 2) {
		// Third segment: c2 to c3
		vec4 p0 = c1;
		vec4 p1 = c2;
		vec4 p2 = c3;
		vec4 p3 = c4;
		result = bspline_basis(local_t, 0) * p0 +
		         bspline_basis(local_t, 1) * p1 +
		         bspline_basis(local_t, 2) * p2 +
		         bspline_basis(local_t, 3) * p3;
	} else {
		// Fourth segment: c3 to c4
		vec4 p0 = c2;
		vec4 p1 = c3;
		vec4 p2 = c4;
		vec4 p3 = c4; // Duplicate last point for clamping
		result = bspline_basis(local_t, 0) * p0 +
		         bspline_basis(local_t, 1) * p1 +
		         bspline_basis(local_t, 2) * p2 +
		         bspline_basis(local_t, 3) * p3;
	}
	
	return result;
}

// Apply color ramp based on luminosity with optional halftone dots
vec4 apply_color_ramp(float luminosity, vec2 world_coords) {
	if (!enable_color_ramp) {
		return vec4(vec3(luminosity), 1.0);
	}
	
	// Apply color ramp with 5 thresholds
	vec4 result_color;
	bool apply_dots = false;
	float dot_scale = 10.0;
	float dot_size = 0.3;
	float dot_softness = 0.1;
	float dot_rotation = 0.0;
	vec4 dot_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	// Use B-spline interpolation when watercolor mode is enabled
	if (enable_watercolor) {
		// B-spline mode: smooth interpolation between colors
		// Map luminosity [0,1] to normalized [0,1] for 5 color points
		float normalized_lum;
		if (luminosity < threshold_1_position) {
			// Below first threshold - extrapolate
			normalized_lum = (luminosity / max(threshold_1_position, 0.001)) * 0.25;
			normalized_lum = clamp(normalized_lum, 0.0, 0.25);
		} else if (luminosity < threshold_2_position) {
			// Between threshold 1 and 2 - first segment [0.0, 0.25]
			float range = threshold_2_position - threshold_1_position;
			normalized_lum = (luminosity - threshold_1_position) / max(range, 0.001);
			normalized_lum = normalized_lum * 0.25; // Map to [0.0, 0.25]
		} else if (luminosity < threshold_3_position) {
			// Between threshold 2 and 3 - second segment [0.25, 0.5]
			float range = threshold_3_position - threshold_2_position;
			normalized_lum = (luminosity - threshold_2_position) / max(range, 0.001);
			normalized_lum = 0.25 + normalized_lum * 0.25; // Map to [0.25, 0.5]
		} else if (luminosity < threshold_4_position) {
			// Between threshold 3 and 4 - third segment [0.5, 0.75]
			float range = threshold_4_position - threshold_3_position;
			normalized_lum = (luminosity - threshold_3_position) / max(range, 0.001);
			normalized_lum = 0.5 + normalized_lum * 0.25; // Map to [0.5, 0.75]
		} else {
			// Above threshold 4 - fourth segment [0.75, 1.0]
			float range = 1.0 - threshold_4_position;
			normalized_lum = (luminosity - threshold_4_position) / max(range, 0.001);
			normalized_lum = 0.75 + normalized_lum * 0.25; // Map to [0.75, 1.0]
		}
		
		// Apply B-spline interpolation with 5 colors
		result_color = bspline_interpolate(normalized_lum, threshold_1_color, threshold_2_color, threshold_3_color, threshold_4_color, threshold_5_color);
		
		// Don't apply dots in B-spline mode (watercolor doesn't use halftone)
		apply_dots = false;
	} else {
		// Standard threshold mode: hard color bands
		if (luminosity < threshold_1_position) {
			// Below first threshold - use first color
			result_color = threshold_1_color;
			apply_dots = threshold_1_enable_dots;
			dot_scale = threshold_1_dot_scale;
			dot_size = threshold_1_dot_size;
			dot_softness = threshold_1_dot_softness;
			dot_rotation = threshold_1_dot_rotation;
			dot_color = threshold_1_dot_color;
		} else if (luminosity < threshold_2_position) {
			// Between threshold 1 and 2 - use second color
			result_color = threshold_2_color;
			apply_dots = threshold_2_enable_dots;
			dot_scale = threshold_2_dot_scale;
			dot_size = threshold_2_dot_size;
			dot_softness = threshold_2_dot_softness;
			dot_rotation = threshold_2_dot_rotation;
			dot_color = threshold_2_dot_color;
		} else if (luminosity < threshold_3_position) {
			// Between threshold 2 and 3 - use third color
			result_color = threshold_3_color;
			apply_dots = threshold_3_enable_dots;
			dot_scale = threshold_3_dot_scale;
			dot_size = threshold_3_dot_size;
			dot_softness = threshold_3_dot_softness;
			dot_rotation = threshold_3_dot_rotation;
			dot_color = threshold_3_dot_color;
		} else if (luminosity < threshold_4_position) {
			// Between threshold 3 and 4 - use fourth color
			result_color = threshold_4_color;
			apply_dots = threshold_4_enable_dots;
			dot_scale = threshold_4_dot_scale;
			dot_size = threshold_4_dot_size;
			dot_softness = threshold_4_dot_softness;
			dot_rotation = threshold_4_dot_rotation;
			dot_color = threshold_4_dot_color;
		} else {
			// Above threshold 4 - use fifth color
			result_color = threshold_5_color;
			apply_dots = threshold_5_enable_dots;
			dot_scale = threshold_5_dot_scale;
			dot_size = threshold_5_dot_size;
			dot_softness = threshold_5_dot_softness;
			dot_rotation = threshold_5_dot_rotation;
			dot_color = threshold_5_dot_color;
		}
	}
	
	// Apply halftone grid dot pattern if enabled for this threshold
	if (apply_dots) {
		// Use world coordinates for dots (they'll stick to surfaces)
		float distance_to_center = halftone_grid(world_coords * dot_scale, dot_rotation);
		
		// Normalize distance (max distance in a cell is ~0.707 from corner to center)
		distance_to_center = distance_to_center / 0.707;
		
		// Create circular dots with smooth edges
		float dot_mask = 1.0 - smoothstep(dot_size, dot_size + dot_softness, distance_to_center);
		
		// Blend dot color with base color
		result_color = mix(result_color, dot_color, dot_mask);
	}
	
	return result_color;
}

// Kuwahara filter for oil painting effect
// This edge-preserving filter creates a painted look by analyzing local color regions
vec3 apply_kuwahara_filter(vec3 input_color, vec2 uv, vec3 normal) {
	if (!enable_oil_painting) {
		return input_color;
	}
	
	int radius = kuwahara_radius;
	float radius_f = float(radius);
	
	// We'll divide the kernel into 4 quadrants and find which has lowest variance
	// Quadrants: top-left, top-right, bottom-left, bottom-right
	
	vec3 mean[4];
	vec3 std_dev[4];
	float variance[4];
	int samples[4];
	
	// Initialize accumulators
	for (int q = 0; q < 4; q++) {
		mean[q] = vec3(0.0);
		std_dev[q] = vec3(0.0);
		variance[q] = 0.0;
		samples[q] = 0;
	}
	
	// Sample the neighborhood using world-space derivative-based approach
	// Since we're in a spatial shader without screen texture, we'll use UV-based sampling
	// with lighting information
	
	// Calculate pixel size based on UV derivatives
	vec2 pixel_size = vec2(
		length(vec2(dFdx(uv.x), dFdy(uv.x))),
		length(vec2(dFdx(uv.y), dFdy(uv.y)))
	) * 0.5;
	
	// First pass: calculate means for each quadrant
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * 5.0; // Scale for visible effect
			vec2 sample_uv = uv + offset;
			
			// Sample lighting based on offset (approximate)
			// In a real implementation with screen texture, we'd sample that
			// Here we approximate based on UV and normal variation
			float noise_sample = noise(sample_uv * 20.0) * 0.3;
			vec3 sample_color = input_color * (1.0 + noise_sample);
			sample_color = clamp(sample_color, 0.0, 1.0);
			
			// Determine which quadrant this sample belongs to
			int quadrant = -1;
			if (x <= 0 && y <= 0) quadrant = 0; // top-left
			else if (x > 0 && y <= 0) quadrant = 1; // top-right
			else if (x <= 0 && y > 0) quadrant = 2; // bottom-left
			else if (x > 0 && y > 0) quadrant = 3; // bottom-right
			
			if (quadrant >= 0) {
				mean[quadrant] += sample_color;
				samples[quadrant]++;
			}
		}
	}
	
	// Calculate actual means
	for (int q = 0; q < 4; q++) {
		if (samples[q] > 0) {
			mean[q] /= float(samples[q]);
		}
	}
	
	// Second pass: calculate variance for each quadrant
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * 5.0;
			vec2 sample_uv = uv + offset;
			
			float noise_sample = noise(sample_uv * 20.0) * 0.3;
			vec3 sample_color = input_color * (1.0 + noise_sample);
			sample_color = clamp(sample_color, 0.0, 1.0);
			
			// Determine quadrant
			int quadrant = -1;
			if (x <= 0 && y <= 0) quadrant = 0;
			else if (x > 0 && y <= 0) quadrant = 1;
			else if (x <= 0 && y > 0) quadrant = 2;
			else if (x > 0 && y > 0) quadrant = 3;
			
			if (quadrant >= 0) {
				vec3 diff = sample_color - mean[quadrant];
				std_dev[quadrant] += diff * diff;
			}
		}
	}
	
	// Calculate final variance
	float min_variance = 999999.0;
	int min_quadrant = 0;
	
	for (int q = 0; q < 4; q++) {
		if (samples[q] > 0) {
			std_dev[q] /= float(samples[q]);
			variance[q] = (std_dev[q].r + std_dev[q].g + std_dev[q].b) / 3.0;
			
			if (variance[q] < min_variance) {
				min_variance = variance[q];
				min_quadrant = q;
			}
		}
	}
	
	// Return the mean color from the quadrant with lowest variance
	// This preserves edges while creating smooth painted regions
	vec3 result = mean[min_quadrant];
	
	// Apply sharpness control - blend between filtered and original
	result = mix(result, input_color, 1.0 - kuwahara_sharpness);
	
	return result;
}

void fragment() {
	// FIX: Use UV coordinates instead of world position to prevent stretching
	// This ensures dots maintain uniform circular shape regardless of object scale
	vec2 halftone_coords = UV;
	
	// ===== MANUAL LIGHTING CALCULATION =====
	// Calculate diffuse lighting (N dot L)
	vec3 normalized_light_dir = normalize(light_direction);
	vec3 normal = NORMAL;
	float NdotL = dot(normal, -normalized_light_dir);
	NdotL = max(NdotL, 0.0);
	
	// Apply light energy and add ambient light
	float lighting_intensity = (NdotL * light_energy) + ambient_light;
	lighting_intensity = clamp(lighting_intensity, 0.0, 1.0);
	
	// ===== USE LIGHTING TO DETERMINE THRESHOLD COLOR =====
	// Now the threshold color selection is based on actual scene lighting!
	vec4 material_color = apply_color_ramp(lighting_intensity, halftone_coords);
	
	// Apply watercolor effect if enabled
	if (enable_watercolor) {
		material_color.rgb = apply_watercolor(material_color.rgb, UV, lighting_intensity);
	}
	
	// Apply oil painting / Kuwahara filter if enabled
	if (enable_oil_painting) {
		material_color.rgb = apply_kuwahara_filter(material_color.rgb, UV, NORMAL);
	}
	
	// Apply light color to the final result
	vec3 final_color = material_color.rgb * light_color;
	
	// Set final output
	ALBEDO = final_color;
	ALPHA = material_color.a;
}

