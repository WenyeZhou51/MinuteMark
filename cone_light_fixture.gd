extends Node2D

@export var light_color: Color = Color(1.0, 0.95, 0.8, 1.0)
@export var energy: float = 2.0
@export var cone_angle_deg: float = 50.0
@export var cone_height: float = 250.0
@export var posterize_levels: float = 5.0
@export var cone_alpha: float = 0.35

@onready var light: PointLight2D = $PointLight2D
@onready var cone_visual: Polygon2D = $ConeVisual
@onready var fixture_body: Polygon2D = $FixtureBody

func _ready() -> void:
	if light:
		light.color = light_color
		light.energy = energy

	_build_cone()

func _build_cone() -> void:
	if not cone_visual:
		return
	var half_w = tan(deg_to_rad(cone_angle_deg / 2.0)) * cone_height * 1.15
	cone_visual.polygon = PackedVector2Array([
		Vector2(-half_w, 0),
		Vector2(half_w, 0),
		Vector2(half_w, cone_height),
		Vector2(-half_w, cone_height),
	])
	cone_visual.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var mat := cone_visual.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("posterize_levels", posterize_levels)
		mat.set_shader_parameter("light_color", Color(light_color.r, light_color.g, light_color.b, cone_alpha))
