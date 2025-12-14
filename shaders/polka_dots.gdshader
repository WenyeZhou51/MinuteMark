shader_type canvas_item;

// Polka dots dissolve shader - creates expanding circular patterns

uniform float transition_state : hint_range(0.0, 1.0) = 0.0;
uniform float grid = 20.0;
uniform float dots_size = 1.5;
uniform vec4 dots_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float PI = 3.14159265359;

mat2 rotationMatrix(float angle) {
	angle *= PI / 180.0;
	float s = sin(angle), c = cos(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	vec2 iResolution = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 uv = FRAGCOORD.xy / iResolution.y * grid;
	
	uv *= rotationMatrix(45.0);
	uv = fract(uv);
	
	// Calculate radius based on transition state
	float radius = (1.0 - transition_state) * 2.0 * dots_size;
	
	vec2 uv1 = (uv - vec2(0.5)) * 2.0 - 1.0;
	vec2 uv2 = (uv + vec2(0.5)) * 2.0 - 1.0;
	vec2 uv3 = (uv - vec2(0.5, -0.5)) * 2.0 - 1.0;
	vec2 uv4 = (uv - vec2(-0.5, 0.5)) * 2.0 - 1.0;
	
	float distance1 = length(uv1);
	float distance2 = length(uv2);
	float distance3 = length(uv3);
	float distance4 = length(uv4);
	
	float d1 = smoothstep(radius, radius - 0.3, distance1);
	float d2 = smoothstep(radius, radius - 0.3, distance2);
	float d3 = smoothstep(radius, radius - 0.3, distance3);
	float d4 = smoothstep(radius, radius - 0.3, distance4);
	
	float alpha = 1.0 - max(max(d1, d2), max(d3, d4));
	
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}

