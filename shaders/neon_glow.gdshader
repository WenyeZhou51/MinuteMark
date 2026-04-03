shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(0.2, 0.6, 1.0, 0.6);
uniform float pulse_speed : hint_range(0.5, 8.0) = 3.0;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.5;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.15;

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	float pulse = mix(pulse_min, 1.0, 0.5 + 0.5 * sin(TIME * pulse_speed));
	float flicker = 1.0 - flicker_intensity * hash(floor(TIME * 30.0));
	float brightness = pulse * flicker;
	COLOR = vec4(neon_color.rgb * brightness, neon_color.a * brightness);
}
