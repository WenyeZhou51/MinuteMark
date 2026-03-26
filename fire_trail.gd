extends Node2D

## Small fire left behind by the on-fire player.
## Draws procedural flickering flames, emits light, and fades out.

@export var lifetime: float = 0.6
@export var base_size: float = 10.0
@export var light_energy: float = 0.6
@export var light_radius: float = 80.0

var elapsed: float = 0.0
var rng := RandomNumberGenerator.new()
var seed_val: float = 0.0
var trail_light: PointLight2D = null


func _ready() -> void:
	rng.randomize()
	seed_val = rng.randf() * 100.0
	z_index = -1

	trail_light = PointLight2D.new()
	trail_light.color = Color(1.0, 0.45, 0.1, 1.0)
	trail_light.energy = light_energy
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in 64:
		for x in 64:
			var d := Vector2(x, y).distance_to(center) / 30.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	trail_light.texture = ImageTexture.create_from_image(img)
	trail_light.texture_scale = light_radius / 32.0
	add_child(trail_light)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return

	var life_frac := 1.0 - (elapsed / lifetime)

	if trail_light:
		trail_light.energy = light_energy * life_frac * (0.8 + 0.2 * sin(elapsed * 20.0 + seed_val))

	queue_redraw()


func _draw() -> void:
	var life_frac := 1.0 - clampf(elapsed / lifetime, 0.0, 1.0)
	var t := elapsed + seed_val

	for i in range(5):
		var fi := float(i)
		var x_off := sin(t * (8.0 + fi * 3.0) + fi * 1.7) * base_size * 0.4
		var height := base_size * life_frac * (0.6 + 0.4 * sin(t * (12.0 + fi * 2.0) + fi))
		var width := base_size * 0.35 * life_frac * (0.7 + 0.3 * cos(t * 5.0 + fi * 2.5))
		var y_base: float = 0.0
		var y_top: float = -height

		var h := life_frac * (0.7 + 0.3 * sin(t * 6.0 + fi))
		var color: Color
		if h > 0.7:
			color = Color(1.0, 0.9, 0.4, life_frac * 0.9)
		elif h > 0.4:
			color = Color(1.0, 0.5, 0.1, life_frac * 0.8)
		else:
			color = Color(0.7, 0.15, 0.0, life_frac * 0.6)

		var points := PackedVector2Array([
			Vector2(x_off - width, y_base),
			Vector2(x_off + width, y_base),
			Vector2(x_off + width * 0.3, y_top),
			Vector2(x_off - width * 0.3, y_top),
		])
		draw_colored_polygon(points, color)

	# Hot core glow at base
	var core_alpha := life_frac * (0.5 + 0.3 * sin(t * 15.0))
	draw_circle(Vector2.ZERO, base_size * 0.4 * life_frac, Color(1.0, 0.8, 0.3, core_alpha))
