extends Node2D

@export var rope_length: float = 120.0
@export var gravity: float = 980.0
@export var damping: float = 0.997
@export var impulse_strength: float = 3.0
@export var cone_angle_deg: float = 40.0
@export var light_energy: float = 2.0
@export var rope_segments: int = 6

@onready var string_line: Line2D = $StringLine
@onready var bulb_pivot: Node2D = $BulbPivot
@onready var light: PointLight2D = $BulbPivot/PointLight2D
@onready var cone_visual: Polygon2D = $BulbPivot/ConeVisual
@onready var player_detector: Area2D = $PlayerDetector

var current_angle: float = 0.0
var angular_velocity: float = 0.0

var rope_points: PackedVector2Array
var rope_velocities: PackedVector2Array

func _ready() -> void:
	if light:
		light.energy = light_energy

	_init_rope()
	_build_cone_polygon()

	if player_detector:
		player_detector.body_entered.connect(_on_player_entered)

func _init_rope() -> void:
	rope_points.resize(rope_segments + 1)
	rope_velocities.resize(rope_segments + 1)
	for i in range(rope_segments + 1):
		var t = float(i) / float(rope_segments)
		rope_points[i] = Vector2(0, t * rope_length)
		rope_velocities[i] = Vector2.ZERO

func _build_cone_polygon() -> void:
	if not cone_visual:
		return
	var half_spread = tan(deg_to_rad(cone_angle_deg / 2.0)) * rope_length * 1.5
	var cone_height = rope_length * 1.5
	cone_visual.polygon = PackedVector2Array([
		Vector2(-6, 0),
		Vector2(6, 0),
		Vector2(half_spread, cone_height),
		Vector2(-half_spread, cone_height),
	])

func _physics_process(delta: float) -> void:
	var angular_accel = -(gravity / rope_length) * sin(current_angle)
	angular_velocity += angular_accel * delta
	angular_velocity *= damping
	current_angle += angular_velocity * delta

	if abs(current_angle) < 0.0005 and abs(angular_velocity) < 0.001:
		current_angle = 0.0
		angular_velocity = 0.0

	_simulate_rope(delta)
	_update_visuals()

func _simulate_rope(delta: float) -> void:
	rope_points[0] = Vector2.ZERO

	var bulb_pos = Vector2(sin(current_angle) * rope_length, cos(current_angle) * rope_length)

	var segment_len = rope_length / float(rope_segments)
	for i in range(1, rope_segments + 1):
		var t = float(i) / float(rope_segments)
		var target = bulb_pos * t

		rope_velocities[i] += Vector2(0, gravity * 0.5) * delta
		rope_velocities[i] *= 0.92
		rope_points[i] += rope_velocities[i] * delta

		var spring_force = (target - rope_points[i]) * 25.0
		rope_velocities[i] += spring_force * delta

		var dir_from_prev = rope_points[i] - rope_points[i - 1]
		var dist = dir_from_prev.length()
		if dist > segment_len:
			dir_from_prev = dir_from_prev.normalized() * segment_len
			rope_points[i] = rope_points[i - 1] + dir_from_prev
			var correction_vel = (rope_points[i] - (rope_points[i] - rope_velocities[i] * delta))
			rope_velocities[i] = correction_vel / max(delta, 0.001)

	rope_points[rope_segments] = bulb_pos

func _update_visuals() -> void:
	if string_line:
		string_line.points = rope_points

	if bulb_pivot:
		var end_pos = rope_points[rope_segments]
		bulb_pivot.position = end_pos
		bulb_pivot.rotation = current_angle

func _on_player_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var player_vel_x: float = 0.0
	if "velocity" in body:
		player_vel_x = body.velocity.x

	var dir = sign(player_vel_x) if abs(player_vel_x) > 10.0 else [-1.0, 1.0].pick_random()
	var speed_factor = clamp(abs(player_vel_x) / 800.0, 0.3, 1.0)
	angular_velocity += dir * impulse_strength * speed_factor

	for i in range(1, rope_segments):
		rope_velocities[i] += Vector2(dir * 40.0 * speed_factor, 0)
