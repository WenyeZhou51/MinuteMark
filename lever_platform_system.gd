extends Node2D

@export_group("Platform System")
@export var platform_count: int = 6
@export var platform_spacing: float = 96.0 ## Center-to-center spacing (pixels)
@export var platform_speed: float = 80.0 ## Upward speed (pixels/sec)
@export var platform_size: Vector2 = Vector2(160, 24)
@export var system_size: Vector2 = Vector2(320, 600) ## Rect bounds for placement
@export_range(0.0, 1.0, 0.01) var start_phase: float = 0.0
@export var platform_scene: PackedScene = preload("res://wrap_platform.tscn")
@export var debug_logs: bool = false

var is_active: bool = false
var platforms: Array[Node2D] = []
var cycle_height: float = 0.0
var center_min_y: float = 0.0
var half_platform_height: float = 0.0


func _ready() -> void:
	_rebuild_platforms()


func start_motion() -> void:
	if is_active:
		return
	is_active = true


func _physics_process(delta: float) -> void:
	if not is_active or platforms.is_empty():
		return
	
	var step = platform_speed * delta
	for i in range(platforms.size()):
		var platform = platforms[i]
		if not platform:
			continue
		var next_y = platform.position.y - step
		if next_y < center_min_y:
			_despawn_platform(platform)
			var respawn_y = _wrap_center_y(next_y + cycle_height)
			var new_platform = _spawn_platform_at(respawn_y)
			platforms[i] = new_platform
		else:
			platform.position.y = next_y


func _rebuild_platforms() -> void:
	_clear_platforms()
	
	if platform_count <= 0 or platform_scene == null:
		return
	
	half_platform_height = platform_size.y / 2.0
	cycle_height = platform_spacing * platform_count
	center_min_y = -system_size.y / 2.0 + half_platform_height
	
	if debug_logs and abs(system_size.y - (cycle_height + platform_size.y)) > 0.1:
		print("[LeverPlatformSystem] Warning: system_size.y doesn't match cycle height.")
	
	for i in range(platform_count):
		var base_y = center_min_y + (i * platform_spacing)
		var y = base_y - (start_phase * cycle_height)
		y = _wrap_center_y(y)
		var platform = _spawn_platform_at(y)
		platforms.append(platform)
	
	if debug_logs:
		print("[LeverPlatformSystem] Spawned platforms=", platforms.size(), " cycle_height=", cycle_height)


func _configure_platform(platform: Node2D) -> void:
	if platform is AnimatableBody2D:
		var body := platform as AnimatableBody2D
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("platforms")
	
	var shape_node = platform.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		rect_shape.size = platform_size
	
	var visual = platform.get_node_or_null("Visual")
	if visual is Polygon2D:
		var poly := visual as Polygon2D
		var half = platform_size / 2.0
		poly.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		])


func _spawn_platform_at(y: float) -> Node2D:
	var platform = platform_scene.instantiate() as Node2D
	add_child(platform)
	_configure_platform(platform)
	platform.position = Vector2(0.0, y)
	return platform


func _despawn_platform(platform: Node2D) -> void:
	if platform and is_instance_valid(platform):
		platform.queue_free()


func _wrap_center_y(y: float) -> float:
	if cycle_height <= 0.0:
		return y
	
	var min_y = center_min_y
	var max_y = center_min_y + cycle_height
	
	while y < min_y:
		y += cycle_height
	while y >= max_y:
		y -= cycle_height
	return y


func _clear_platforms() -> void:
	for platform in platforms:
		if platform and is_instance_valid(platform):
			platform.queue_free()
	platforms.clear()
