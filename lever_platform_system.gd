extends Node2D

@export_group("Platform System")
@export var platform_count: int = 6
@export var platform_spacing: float = 96.0 ## Center-to-center spacing (pixels)
@export var platform_speed: float = 80.0 ## Upward speed (pixels/sec)
@export var platform_size: Vector2 = Vector2(160, 24)
@export var system_size: Vector2 = Vector2(320, 600) ## Rect bounds for placement
@export_range(0.0, 1.0, 0.01) var start_phase: float = 0.0
@export var always_active: bool = false ## If true, system is always active and lever trigger has no effect
@export var platform_scene: PackedScene = preload("res://wrap_platform.tscn")
@export var debug_logs: bool = false

@export_group("Editor Visuals")
@export var show_bounds: bool = true ## Show system bounds and platform zones in editor
@export var bounds_color: Color = Color(0.2, 0.8, 0.4, 0.35) ## Color for boundary outlines
@export var platform_preview_color: Color = Color(0.4, 0.7, 1.0, 0.25) ## Color for platform start positions

var is_active: bool = false
var platforms: Array[Node2D] = []
var cycle_height: float = 0.0
var center_min_y: float = 0.0
var half_platform_height: float = 0.0
var _pending_collision_enable: Array[CollisionShape2D] = []


func _ready() -> void:
	_rebuild_platforms()
	if always_active:
		is_active = true
	queue_redraw()


func start_motion() -> void:
	if is_active or always_active:
		return
	is_active = true


func _physics_process(delta: float) -> void:
	# Re-enable collision shapes that were disabled during a wrap teleport last frame.
	# This ensures the AnimatableBody2D has one clean frame at the new position before
	# collisions resume, preventing a massive velocity spike from the teleport.
	for shape in _pending_collision_enable:
		if is_instance_valid(shape):
			shape.disabled = false
	_pending_collision_enable.clear()
	
	if not is_active or platforms.is_empty():
		return
	
	var step = platform_speed * delta
	for i in range(platforms.size()):
		var platform = platforms[i]
		if not platform or not is_instance_valid(platform):
			continue
		var next_y = platform.position.y - step
		if next_y < center_min_y:
			# Wrap: reuse existing platform instead of destroy + create.
			# Destroying and recreating an AnimatableBody2D causes it to lose its
			# velocity history for 1-2 frames (velocity = 0). Since the platform
			# moves ~12 px/frame at 700 px/sec, exceeding floor_snap_length (8 px),
			# the player loses floor contact and falls through.
			var respawn_y = _wrap_center_y(next_y + cycle_height)
			# Briefly disable collision during the teleport so the physics server
			# doesn't compute a huge velocity from the large position jump.
			var shape = platform.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape:
				shape.disabled = true
				_pending_collision_enable.append(shape)
			platform.position.y = respawn_y
		else:
			platform.position.y = next_y


func _rebuild_platforms() -> void:
	_clear_platforms()
	
	if platform_count <= 0 or platform_scene == null:
		return
	
	half_platform_height = platform_size.y / 2.0
	cycle_height = platform_spacing * platform_count
	center_min_y = -system_size.y / 2.0 + half_platform_height
	
	for i in range(platform_count):
		var base_y = center_min_y + (i * platform_spacing)
		var y = base_y - (start_phase * cycle_height)
		y = _wrap_center_y(y)
		var platform = _spawn_platform_at(y)
		platforms.append(platform)
	


func _configure_platform(platform: Node2D) -> void:
	if platform is AnimatableBody2D:
		var body := platform as AnimatableBody2D
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("platforms")
	
	# Resize collision shape to match platform_size
	var shape_node = platform.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		rect_shape.size = platform_size
	
	# Configure metal beam visual
	var visual = platform.get_node_or_null("Visual")
	if visual and visual.has_method("set_beam_size"):
		visual.set_beam_size(platform_size)
	elif visual is Polygon2D:
		# Fallback: plain Polygon2D visual
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


# ---- Editor / runtime visual indicators ----

func _draw() -> void:
	if not show_bounds:
		return
	
	var half_sys := system_size / 2.0
	var half_plat_w := platform_size.x / 2.0
	
	# --- System bounds rectangle ---
	var bounds_rect := Rect2(-half_sys, system_size)
	draw_rect(bounds_rect, bounds_color, false, 2.0)
	
	# --- Top boundary label line (spawn/despawn edge) ---
	var top_y := -half_sys.y
	var bot_y := half_sys.y
	
	# Top line - "EXIT" zone where platforms despawn
	var exit_color := Color(1.0, 0.3, 0.3, 0.5)
	draw_line(Vector2(-half_sys.x, top_y), Vector2(half_sys.x, top_y), exit_color, 2.0)
	_draw_dashed_line(Vector2(-half_sys.x, top_y + half_platform_height), Vector2(half_sys.x, top_y + half_platform_height), exit_color * Color(1, 1, 1, 0.6), 1.0, 8.0)
	
	# Bottom line - "ENTRY" zone where platforms wrap to
	var entry_color := Color(0.3, 1.0, 0.3, 0.5)
	draw_line(Vector2(-half_sys.x, bot_y), Vector2(half_sys.x, bot_y), entry_color, 2.0)
	_draw_dashed_line(Vector2(-half_sys.x, bot_y - half_platform_height), Vector2(half_sys.x, bot_y - half_platform_height), entry_color * Color(1, 1, 1, 0.6), 1.0, 8.0)
	
	# --- Platform start position previews ---
	if platform_count > 0 and platform_spacing > 0:
		var preview_half := platform_size / 2.0
		var local_cycle := platform_spacing * platform_count
		var local_min_y := -system_size.y / 2.0 + platform_size.y / 2.0
		
		for i in range(platform_count):
			var base_y := local_min_y + (i * platform_spacing)
			var y := base_y - (start_phase * local_cycle)
			# Wrap
			var wrap_min := local_min_y
			var wrap_max := local_min_y + local_cycle
			while y < wrap_min:
				y += local_cycle
			while y >= wrap_max:
				y -= local_cycle
			
			var plat_rect := Rect2(
				Vector2(-preview_half.x, y - preview_half.y),
				platform_size
			)
			draw_rect(plat_rect, platform_preview_color, true)
			draw_rect(plat_rect, platform_preview_color * Color(1, 1, 1, 2.0), false, 1.0)
	


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var direction := (to - from).normalized()
	var total_length := from.distance_to(to)
	var drawn := 0.0
	var drawing := true
	
	while drawn < total_length:
		var segment_end := minf(drawn + dash_length, total_length)
		if drawing:
			draw_line(
				from + direction * drawn,
				from + direction * segment_end,
				color, width
			)
		drawn = segment_end
		drawing = not drawing
