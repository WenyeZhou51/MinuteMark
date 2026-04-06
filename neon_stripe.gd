extends Node2D

@export var stripe_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var glow_energy: float = 1.5
@export var flicker_speed: float = 3.0
@export var stripe_length: float = 200.0
@export var glow_spread: float = 80.0
@export var posterize_levels: float = 5.0

@onready var neon_tube: Polygon2D = $NeonTube
@onready var light: PointLight2D = $PointLight2D

var base_energy: float
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	base_energy = glow_energy

	var half_len = stripe_length / 2.0
	if neon_tube:
		neon_tube.polygon = PackedVector2Array([
			Vector2(-half_len, -glow_spread),
			Vector2(half_len, -glow_spread),
			Vector2(half_len, glow_spread),
			Vector2(-half_len, glow_spread),
		])
		neon_tube.uv = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
		])
		var mat := neon_tube.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("neon_color", stripe_color)
			mat.set_shader_parameter("pulse_speed", flicker_speed)
			mat.set_shader_parameter("posterize_levels", posterize_levels)

	if light:
		light.color = stripe_color
		light.energy = glow_energy
		light.texture_scale = max(stripe_length / 32.0, 6.0)

func _process(_delta: float) -> void:
	if not light:
		return
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * flicker_speed)
	var noise = rng.randf_range(-0.05, 0.05)
	light.energy = base_energy * (0.85 + 0.15 * pulse + noise)
