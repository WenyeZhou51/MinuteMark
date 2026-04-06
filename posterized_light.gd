extends Node2D

@export var light_color: Color = Color(1.0, 0.3, 0.6, 1.0)
@export var energy: float = 1.8
@export var posterize_levels: float = 5.0
@export var radius: float = 300.0

@onready var light: PointLight2D = $PointLight2D
@onready var overlay: Polygon2D = $PosterizeOverlay

var base_energy: float

func _ready() -> void:
	base_energy = energy

	if light:
		light.color = light_color
		light.energy = energy

	if overlay:
		overlay.polygon = PackedVector2Array([
			Vector2(-radius, -radius),
			Vector2(radius, -radius),
			Vector2(radius, radius),
			Vector2(-radius, radius),
		])
		overlay.uv = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
		])
		var mat := overlay.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("posterize_levels", posterize_levels)
			mat.set_shader_parameter("light_color", Color(light_color.r, light_color.g, light_color.b, 0.5))

func _process(_delta: float) -> void:
	if not light:
		return
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * 1.5)
	light.energy = base_energy * (0.9 + 0.1 * pulse)
