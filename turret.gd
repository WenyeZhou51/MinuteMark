extends Area2D

@export_group("Fan")
@export var fan_radius: float = 600.0
@export var fan_angle_degrees: float = 90.0
@export var fan_resolution: int = 24
@export var fan_fill_color: Color = Color(1.0, 0.2, 0.2, 0.15)
@export var fan_outline_color: Color = Color(1.0, 0.2, 0.2, 0.6)
@export var fan_outline_width: float = 2.0

@export_group("Sweep")
@export var base_direction_degrees: float = 0.0  # 0 = right, 90 = down
@export var sweep_angle_degrees: float = 120.0
@export var sweep_speed_degrees: float = 45.0

@export_group("Laser")
@export var laser_scene: PackedScene = preload("res://laser_hazard.tscn")
@export var laser_range: float = 1500.0
@export var laser_width: float = 24.0
@export var laser_duration: float = 0.25
@export var laser_cooldown: float = 1.0
@export var laser_damage_cooldown: float = 0.2

@export_group("Behavior")
@export var require_line_of_sight: bool = true

@export_group("Visuals")
@export var body_size: Vector2 = Vector2(32, 24)
@export var body_color: Color = Color(0.35, 0.35, 0.35, 1.0)

var player_ref: Node2D = null
var gunpoint: Node2D = null
var fan_fill: Polygon2D = null
var fan_outline: Line2D = null
var laser_raycast: RayCast2D = null
var body_visual: Polygon2D = null

var sweep_offset_degrees: float = 0.0
var sweep_direction: int = 1
var cooldown_timer: float = 0.0

func _ready() -> void:
	visible = true
	modulate.a = 1.0
	z_as_relative = false
	z_index = 20
	_setup_gunpoint()
	_setup_body_visual()
	_setup_fan_visuals()
	_setup_laser_raycast()
	_update_fan_geometry()
	
	await get_tree().process_frame
	_find_player()

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
	
	_update_sweep(delta)
	_update_fan_visuals()
	
	if _player_in_fan():
		_try_fire()

func _setup_gunpoint() -> void:
	gunpoint = get_node_or_null("Gunpoint")
	if not gunpoint:
		gunpoint = Node2D.new()
		gunpoint.name = "Gunpoint"
		gunpoint.position = Vector2(24, 0)
		add_child(gunpoint)

func _setup_body_visual() -> void:
	body_visual = get_node_or_null("BodyVisual")
	if not body_visual:
		body_visual = Polygon2D.new()
		body_visual.name = "BodyVisual"
		add_child(body_visual)
	
	var half = body_size * 0.5
	body_visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	body_visual.color = body_color
	body_visual.visible = true
	body_visual.z_index = 2

func _setup_fan_visuals() -> void:
	fan_fill = get_node_or_null("FanFill")
	if not fan_fill:
		fan_fill = Polygon2D.new()
		fan_fill.name = "FanFill"
		add_child(fan_fill)
	
	fan_outline = get_node_or_null("FanOutline")
	if not fan_outline:
		fan_outline = Line2D.new()
		fan_outline.name = "FanOutline"
		add_child(fan_outline)
	
	fan_fill.color = fan_fill_color
	fan_fill.visible = true
	fan_fill.z_index = 0
	fan_outline.default_color = fan_outline_color
	fan_outline.width = fan_outline_width
	fan_outline.visible = true
	fan_outline.z_index = 1

func _setup_laser_raycast() -> void:
	laser_raycast = get_node_or_null("LaserRaycast")
	if not laser_raycast:
		laser_raycast = RayCast2D.new()
		laser_raycast.name = "LaserRaycast"
		add_child(laser_raycast)
	
	laser_raycast.enabled = true
	laser_raycast.collide_with_areas = false
	laser_raycast.collide_with_bodies = true
	laser_raycast.exclude_parent = true
	laser_raycast.collision_mask = 1

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]
		if laser_raycast:
			laser_raycast.add_exception(player_ref)

func _update_sweep(delta: float) -> void:
	var half_sweep = max(0.0, sweep_angle_degrees * 0.5)
	if half_sweep <= 0.0:
		sweep_offset_degrees = 0.0
		return
	
	sweep_offset_degrees += sweep_direction * sweep_speed_degrees * delta
	if sweep_offset_degrees > half_sweep:
		sweep_offset_degrees = half_sweep
		sweep_direction = -1
	elif sweep_offset_degrees < -half_sweep:
		sweep_offset_degrees = -half_sweep
		sweep_direction = 1

func _update_fan_visuals() -> void:
	var center_angle = _current_fan_angle()
	fan_fill.rotation = center_angle
	fan_outline.rotation = center_angle

func _update_fan_geometry() -> void:
	var angle_radians = deg_to_rad(max(1.0, fan_angle_degrees))
	var half_angle = angle_radians * 0.5
	var steps = max(4, fan_resolution)
	
	var polygon_points = PackedVector2Array()
	polygon_points.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var a = lerp(-half_angle, half_angle, t)
		polygon_points.append(Vector2(cos(a), sin(a)) * fan_radius)
	fan_fill.polygon = polygon_points
	
	var outline_points = PackedVector2Array()
	outline_points.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var a = lerp(-half_angle, half_angle, t)
		outline_points.append(Vector2(cos(a), sin(a)) * fan_radius)
	outline_points.append(Vector2.ZERO)
	fan_outline.points = outline_points

func _current_fan_angle() -> float:
	return deg_to_rad(base_direction_degrees + sweep_offset_degrees)

func _player_in_fan() -> bool:
	if not player_ref or not is_instance_valid(player_ref):
		return false
	
	var origin = gunpoint.global_position if gunpoint else global_position
	var to_player = player_ref.global_position - origin
	var distance = to_player.length()
	if distance > fan_radius:
		return false
	
	var center_angle = _current_fan_angle()
	var angle_diff = _angle_difference(center_angle, to_player.angle())
	var half_angle = deg_to_rad(fan_angle_degrees) * 0.5
	if abs(angle_diff) > half_angle:
		return false
	
	if require_line_of_sight and _is_line_blocked(origin, to_player.normalized(), distance):
		return false
	
	return true

func _is_line_blocked(origin: Vector2, direction: Vector2, max_distance: float) -> bool:
	if not laser_raycast:
		return false
	
	laser_raycast.global_position = origin
	laser_raycast.target_position = direction * max_distance
	laser_raycast.force_raycast_update()
	return laser_raycast.is_colliding()

func _try_fire() -> void:
	if cooldown_timer > 0.0:
		return
	
	if not laser_scene:
		return
	
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	var origin = gunpoint.global_position if gunpoint else global_position
	var direction = (player_ref.global_position - origin).normalized()
	if direction == Vector2.ZERO:
		return
	
	var beam_length = laser_range
	if laser_raycast:
		laser_raycast.global_position = origin
		laser_raycast.target_position = direction * laser_range
		laser_raycast.force_raycast_update()
		if laser_raycast.is_colliding():
			beam_length = origin.distance_to(laser_raycast.get_collision_point())
	
	var laser = laser_scene.instantiate()
	laser.global_position = origin
	laser.laser_direction = direction
	laser.laser_length = beam_length
	laser.laser_width = laser_width
	laser.damage_cooldown = laser_damage_cooldown
	get_parent().add_child(laser)
	
	get_tree().create_timer(laser_duration, true, false, true).timeout.connect(laser.queue_free)
	cooldown_timer = laser_cooldown

func _angle_difference(from_angle: float, to_angle: float) -> float:
	var diff = to_angle - from_angle
	while diff > PI:
		diff -= 2 * PI
	while diff < -PI:
		diff += 2 * PI
	return diff
