shader_type canvas_item;
render_mode unshaded;

uniform float visibility_boost : hint_range(0.5, 2.5) = 1.25;

void fragment() {
	COLOR = vec4(COLOR.rgb * visibility_boost, COLOR.a);
}
