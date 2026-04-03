shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float max_brightness : hint_range(0.3, 2.0) = 1.0;

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	// Reinhard tonemap: soft clamp approaching max_brightness
	// Single light looks normal; stacked lights compress instead of blowing out
	COLOR.rgb = screen * max_brightness / (screen + vec3(max_brightness));
	COLOR.a = 1.0;
}
