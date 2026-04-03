extends Node2D

@export var stripe_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var glow_energy: float = 1.5
@export var flicker_speed: float = 3.0
@export var stripe_length: float = 200.0

@onready var stripe_mesh: Line2D = $StripeMesh
@onready var glow_overlay: Line2D = $GlowOverlay
@onready var light: PointLight2D = $PointLight2D

var base_energy: float
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	base_energy = glow_energy

	var half = stripe_length / 2.0
	var points := PackedVector2Array([Vector2(-half, 0), Vector2(half, 0)])
	stripe_mesh.points = points
	stripe_mesh.default_color = stripe_color
	glow_overlay.points = points

	if light:
		light.color = stripe_color
		light.energy = glow_energy
		light.texture_scale = max(stripe_length / 32.0, 6.0)

	var mat := glow_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("neon_color", Color(stripe_color.r, stripe_color.g, stripe_color.b, 0.6))
		mat.set_shader_parameter("pulse_speed", flicker_speed)

func _process(_delta: float) -> void:
	if not light:
		return
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * flicker_speed)
	var noise = rng.randf_range(-0.05, 0.05)
	light.energy = base_energy * (0.85 + 0.15 * pulse + noise)
