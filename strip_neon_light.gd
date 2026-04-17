@tool
extends Node2D

@export var light_color: Color = Color(0.2, 0.6, 1.0, 1.0):
	set(v):
		light_color = v
		if is_node_ready():
			_rebuild()

@export var strip_length: float = 200.0:
	set(v):
		strip_length = v
		if is_node_ready():
			_rebuild()

@export var light_radius: float = 300.0:
	set(v):
		light_radius = v
		if is_node_ready():
			_rebuild()

@export var energy: float = 2.0:
	set(v):
		energy = v
		base_energy = v
		if is_node_ready():
			_rebuild()

@export var glow_spread: float = 80.0:
	set(v):
		glow_spread = v
		if is_node_ready():
			_rebuild()

@export var pulse_speed: float = 1.5:
	set(v):
		pulse_speed = v
		if is_node_ready():
			_rebuild()

@onready var tube_glow: Polygon2D = $TubeGlow
@onready var light_overlay: Polygon2D = $LightOverlay
@onready var point_light: PointLight2D = $PointLight2D

var base_energy: float
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	base_energy = energy
	_rebuild()


func _rebuild() -> void:
	_build_tube_glow()
	_build_overlay()
	_build_directional_light()


func _build_tube_glow() -> void:
	if not tube_glow:
		return
	var half_len := strip_length / 2.0
	tube_glow.polygon = PackedVector2Array([
		Vector2(-half_len, -glow_spread),
		Vector2(half_len, -glow_spread),
		Vector2(half_len, glow_spread),
		Vector2(-half_len, glow_spread),
	])
	tube_glow.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var mat := tube_glow.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("glow_color", light_color)
		mat.set_shader_parameter("pulse_speed", pulse_speed)


func _build_overlay() -> void:
	if not light_overlay:
		return
	var half_len := strip_length / 2.0
	light_overlay.polygon = PackedVector2Array([
		Vector2(-half_len, 0),
		Vector2(half_len, 0),
		Vector2(half_len, light_radius),
		Vector2(-half_len, light_radius),
	])
	light_overlay.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var mat := light_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("light_color", Color(light_color.r, light_color.g, light_color.b, 0.5))
		mat.set_shader_parameter("pulse_speed", pulse_speed)


func _build_directional_light() -> void:
	if not point_light:
		return

	var tex_w := 128
	var tex_h := 128
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	var center_y := 0.15

	for y in tex_h:
		for x in tex_w:
			var ux := float(x) / float(tex_w)
			var uy := float(y) / float(tex_h)

			var forward_dist := (uy - center_y) / (1.0 - center_y)

			var a := 0.0
			if uy >= center_y:
				var v := 1.0 - clampf(forward_dist, 0.0, 1.0)
				v = v * v
				var hx := absf(ux - 0.5) * 2.0
				var h := 1.0 - clampf((hx - 0.7) / 0.3, 0.0, 1.0)
				h = smoothstep(0.0, 1.0, h)
				a = v * h

			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

	point_light.texture = ImageTexture.create_from_image(img)
	point_light.color = light_color
	point_light.energy = energy
	var tex_scale := light_radius / (64.0 * (1.0 - center_y))
	point_light.texture_scale = tex_scale
	point_light.position = Vector2(0, (0.5 - center_y) * tex_scale * 128.0)


func _process(_delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * pulse_speed)
	var noise := rng.randf_range(-0.03, 0.03)
	var mult := 0.9 + 0.1 * pulse + noise
	if point_light:
		point_light.energy = base_energy * mult
