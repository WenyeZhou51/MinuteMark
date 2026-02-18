extends StaticBody2D

# ====================================
# WINDOW OBJECT
# ====================================
# A window that shatters into many pieces when the player kicks or dashes through it
# Unlike kickable objects, it doesn't fly away - it just breaks immediately
# Acts as a physical barrier until shattered
# NOTE: Windows can be broken by both kick and dash actions

# CONFIGURATION
@export_group("Window Properties")
@export var window_size: Vector2 = Vector2(60, 800)  ## Size of the window
@export var fragment_count: int = 20  ## Number of fragments when shattered (more for glass effect)
@export var fragment_lifetime: float = 1.5  ## How long fragments last
@export var shatter_force: float = 500.0  ## Base force for fragment explosion
@export var shatter_force_variation: float = 300.0  ## Variation in shatter force

@export_group("Visual")
@export var window_color: Color = Color(0.7, 0.9, 1.0, 0.6)  ## Glass-like color (light blue, semi-transparent)
@export var window_frame_color: Color = Color(0.3, 0.2, 0.1, 1.0)  ## Frame color (brown)
@export var frame_thickness: float = 4.0  ## Thickness of window frame

@export_group("Break Text")
@export var break_text_content: String = "CRASH"  ## Text to display when window breaks
@export var break_text_font_size: int = 64  ## Initial font size of break text
@export var break_text_font: Font = null  ## Font to use for break text (optional, uses default if null)
@export var break_text_expansion_rate: float = 1.5  ## How much the text expands (1.0 = no expansion, 2.0 = doubles in size)
@export var break_text_color: Color = Color.WHITE  ## Color of the break text
@export var slow_mo_duration: float = 0.7  ## Duration of slow motion effect in seconds
@export var text_shake_intensity: float = 8.0  ## How much the text shakes (in pixels)
@export var text_shake_speed: float = 30.0  ## How fast the text shakes (higher = faster)

# Internal state
var is_shattered: bool = false
var player_direction: Vector2 = Vector2.ZERO  # Store player direction when broken
var spawned_fragments: Array = []  # Track spawned fragments for color changes

# Audio
var sfx_player: AudioStreamPlayer
var shatter_sfx: AudioStream

# Visual references
@onready var glass_visual: Polygon2D = $GlassVisual
@onready var frame_visual: Polygon2D = $FrameVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var break_text_marker: Node2D = $BreakTextMarker

# Break text overlay
var break_text_label: Label = null
var original_time_scale: float = 1.0


func _ready() -> void:
	# Setup collision layers
	# Layer 1 (value 1) for walls/platforms - this makes it block player and other objects
	collision_layer = 1
	# No collision mask needed for StaticBody2D (it doesn't detect, it blocks)
	collision_mask = 0
	
	# Add to group for detection (same group as kickable objects)
	add_to_group("kickable_objects")
	
	# Update visuals
	_update_visuals()
	
	# Setup audio
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	# Try to use Game bus if it exists, otherwise Master
	if AudioServer.get_bus_index("Game") != -1:
		sfx_player.bus = "Game"
	else:
		sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# Load shatter sound
	if ResourceLoader.exists("res://audio/brokenWindow.wav"):
		shatter_sfx = load("res://audio/brokenWindow.wav")
	elif ResourceLoader.exists("res://audio/glassBroken.wav"):
		shatter_sfx = load("res://audio/glassBroken.wav")
	elif ResourceLoader.exists("res://audio/glassBroken.mp3"):
		shatter_sfx = load("res://audio/glassBroken.mp3")
		
	if not shatter_sfx:
		print("Window: Failed to load brokenWindow/glassBroken sound!")
	else:
		print("Window: Loaded shatter sound: ", shatter_sfx.resource_path)


func _update_visuals() -> void:
	"""Update visual polygons for glass and frame."""
	var half_size = window_size / 2.0
	
	# Glass visual (slightly smaller than frame to show frame border)
	var glass_half = half_size - Vector2(frame_thickness, frame_thickness)
	if glass_visual:
		# Reset position/scale so the centered polygon aligns with the Window origin
		glass_visual.position = Vector2.ZERO
		glass_visual.scale = Vector2.ONE
		glass_visual.polygon = PackedVector2Array([
			Vector2(-glass_half.x, -glass_half.y),
			Vector2(glass_half.x, -glass_half.y),
			Vector2(glass_half.x, glass_half.y),
			Vector2(-glass_half.x, glass_half.y)
		])
		glass_visual.color = window_color
	
	# Frame visual (full size rectangle)
	if frame_visual:
		# Reset position/scale so the centered polygon aligns with the Window origin
		frame_visual.position = Vector2.ZERO
		frame_visual.scale = Vector2.ONE
		frame_visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		frame_visual.color = window_frame_color
	
	# Update collision shape
	if collision_shape:
		# Reset position so the collision is centered on the Window origin
		collision_shape.position = Vector2.ZERO
		var shape = RectangleShape2D.new()
		shape.size = window_size
		collision_shape.shape = shape


func kick(direction: Vector2, speed: float = 0.0) -> void:
	"""Called when player kicks or dashes through this window - shatter immediately."""
	if is_shattered:
		return  # Already shattered
	
	is_shattered = true
	player_direction = direction.normalized()
	
	# Shatter in the direction the player is dashing BEFORE time slow
	_shatter(player_direction)
	
	# If broken by player dash, extend the dash duration
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("extend_dash_duration"):
		player.extend_dash_duration()
	
	# Play shatter sound
	if shatter_sfx:
		sfx_player.stream = shatter_sfx
		sfx_player.pitch_scale = randf_range(0.9, 1.1)
		sfx_player.play()
	
	# Trigger time slow effect with tile hiding and break text
	_trigger_break_effect()


func _trigger_break_effect() -> void:
	"""Trigger time slow, make tiles and fragments black, add red background overlay, and show break text with animation."""
	# Store original time scale
	original_time_scale = Engine.time_scale
	
	# Slow time to 30%
	Engine.time_scale = 0.3
	
	# Find all TileMapLayer nodes and make them pure black
	var tilemaps = _find_all_tilemaps(get_tree().root)
	var original_tilemap_colors = {}
	for tilemap in tilemaps:
		# Store original color
		original_tilemap_colors[tilemap] = tilemap.modulate
		# Set to pure black
		tilemap.modulate = Color.BLACK
	
	# Make glass fragments pure black
	var original_fragment_colors = {}
	for fragment in spawned_fragments:
		if is_instance_valid(fragment):
			original_fragment_colors[fragment] = fragment.modulate
			fragment.modulate = Color.BLACK
	
	# Create a red rectangle that covers the entire screen
	var red_overlay = ColorRect.new()
	red_overlay.color = Color.RED
	red_overlay.z_index = -100  # Behind everything
	
	# Get the viewport size to cover entire screen
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		red_overlay.size = viewport_size * 10  # Make it huge to cover everything
		red_overlay.position = -viewport_size * 5  # Center it
	else:
		# Fallback: very large rectangle
		red_overlay.size = Vector2(100000, 100000)
		red_overlay.position = Vector2(-50000, -50000)
	
	# Add to a CanvasLayer so it follows camera
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = -100  # Behind everything
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(red_overlay)
	
	# Hide parallax background and background tilemaps
	var hidden_nodes = []
	var parallax_bg = get_tree().root.find_child("ParallaxBackground", true, false)
	if parallax_bg:
		hidden_nodes.append(parallax_bg)
		parallax_bg.visible = false
	
	var bg_tilemap = get_tree().root.find_child("BackgroundTileMap", true, false)
	if bg_tilemap:
		hidden_nodes.append(bg_tilemap)
		bg_tilemap.visible = false
	
	# Apply camera shake for the duration of the slow-mo effect
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.apply_camera_shake(15.0, slow_mo_duration)  # Match slow-mo duration
	
	# Create and show break text at marker position
	if break_text_marker:
		break_text_label = Label.new()
		break_text_label.text = break_text_content
		break_text_label.z_index = 1000  # Render on top of everything
		
		# Setup label settings
		break_text_label.add_theme_font_size_override("font_size", break_text_font_size)
		if break_text_font:
			break_text_label.add_theme_font_override("font", break_text_font)
		break_text_label.add_theme_color_override("font_color", break_text_color)
		break_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
		break_text_label.add_theme_constant_override("outline_size", 4)
		
		# Center the text horizontally and vertically
		break_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		break_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Add to a CanvasLayer so it renders in screen space
		var text_canvas_layer = CanvasLayer.new()
		text_canvas_layer.layer = 100  # On top of everything
		get_tree().root.add_child(text_canvas_layer)
		text_canvas_layer.add_child(break_text_label)
		
		# Position at marker location in screen space
		# Get camera to convert world position to screen position
		var camera = get_viewport().get_camera_2d()
		if camera:
			var screen_pos = break_text_marker.global_position - camera.get_screen_center_position() + get_viewport().get_visible_rect().size / 2
			break_text_label.position = screen_pos
		else:
			# Fallback: use viewport center
			break_text_label.position = get_viewport().get_visible_rect().size / 2
		
		# Wait one frame for label to calculate its size
		await get_tree().process_frame
		
		# Now set pivot to center for proper scaling
		break_text_label.pivot_offset = break_text_label.size / 2
		
		# Adjust position to account for pivot (so it's truly centered)
		break_text_label.position -= break_text_label.size / 2
		
		# Start and wait for animation coroutine to complete
		await _animate_break_text()
	
	# Restore everything
	Engine.time_scale = original_time_scale
	
	# Restore tilemap colors
	for tilemap in tilemaps:
		if is_instance_valid(tilemap) and tilemap in original_tilemap_colors:
			tilemap.modulate = original_tilemap_colors[tilemap]
	
	# Restore fragment colors
	for fragment in spawned_fragments:
		if is_instance_valid(fragment) and fragment in original_fragment_colors:
			fragment.modulate = original_fragment_colors[fragment]
	
	# Show hidden nodes again
	for node in hidden_nodes:
		if is_instance_valid(node):
			node.visible = true
	
	# Remove red overlay
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	
	# Remove break text and its canvas layer
	if break_text_label and is_instance_valid(break_text_label):
		var text_canvas = break_text_label.get_parent()
		if text_canvas and is_instance_valid(text_canvas):
			text_canvas.queue_free()
		break_text_label = null
	
	# Now that restoration is complete, clean up the window node
	queue_free()


func _animate_break_text() -> void:
	"""Animate the break text with slow expansion and shake effect."""
	if not break_text_label or not is_instance_valid(break_text_label):
		return
	
	var start_time = Time.get_ticks_msec() / 1000.0
	var duration = slow_mo_duration  # Use configurable duration
	var original_pos = break_text_label.position
	var start_scale = 1.0
	var end_scale = break_text_expansion_rate
	
	# Run animation loop
	while Time.get_ticks_msec() / 1000.0 - start_time < duration:
		# Safety check: ensure label still exists
		if not break_text_label or not is_instance_valid(break_text_label):
			return
		
		var elapsed = Time.get_ticks_msec() / 1000.0 - start_time
		var progress = elapsed / duration
		
		# Expand: smoothly scale from start_scale to end_scale over the duration
		var scale_factor = lerp(start_scale, end_scale, progress)
		break_text_label.scale = Vector2(scale_factor, scale_factor)
		
		# Shake/Vibrate: Add random offset to position
		var shake_offset = Vector2(
			randf_range(-text_shake_intensity, text_shake_intensity),
			randf_range(-text_shake_intensity, text_shake_intensity)
		)
		# Increase shake intensity slightly over time for impact
		var shake_multiplier = 1.0 + progress * 0.5
		shake_offset *= shake_multiplier
		
		break_text_label.position = original_pos + shake_offset
		
		# Wait for next frame (using process_always to work during time_scale)
		await get_tree().process_frame
	
	# Reset to final state
	if break_text_label and is_instance_valid(break_text_label):
		break_text_label.scale = Vector2(end_scale, end_scale)
		break_text_label.position = original_pos


func _find_all_tilemaps(node: Node) -> Array:
	"""Recursively find all TileMapLayer nodes in the scene tree."""
	var tilemaps = []
	
	# Check if current node is a TileMapLayer
	if node is TileMapLayer:
		tilemaps.append(node)
	# Also check for TileMap (Godot 3.x compatibility)
	elif node.get_class() == "TileMap":
		tilemaps.append(node)
	
	# Recursively check children
	for child in node.get_children():
		tilemaps.append_array(_find_all_tilemaps(child))
	
	return tilemaps


func _shatter(kick_direction: Vector2) -> void:
	"""Shatter the window into many fragments with varied, realistic shapes."""
	var half_size = window_size / 2.0
	var glass_half = half_size - Vector2(frame_thickness, frame_thickness)
	var fragment_script = load("res://kickable_fragment.gd")
	
	# Generate random seed points for Voronoi-like fragmentation
	var seed_points: Array[Vector2] = []
	var min_distance = min(glass_half.x * 2, glass_half.y * 2) / sqrt(fragment_count) * 0.6
	
	# Generate seed points with some spacing (simple Poisson-like sampling)
	for i in range(fragment_count * 3):  # Try more points than needed
		if seed_points.size() >= fragment_count:
			break
		
		var attempts = 0
		var valid_point = false
		var new_point: Vector2
		
		while attempts < 50 and not valid_point:
			new_point = Vector2(
				randf_range(-glass_half.x, glass_half.x),
				randf_range(-glass_half.y, glass_half.y)
			)
			
			valid_point = true
			# Check distance from existing points
			for existing_point in seed_points:
				if new_point.distance_to(existing_point) < min_distance:
					valid_point = false
					break
			
			attempts += 1
		
		if valid_point:
			seed_points.append(new_point)
	
	# If we don't have enough points, fill with random points
	while seed_points.size() < fragment_count:
		seed_points.append(Vector2(
			randf_range(-glass_half.x, glass_half.x),
			randf_range(-glass_half.y, glass_half.y)
		))
	
	# Generate fragments using Voronoi-like approach
	# For each seed point, find its "territory" by checking nearby points
	for seed_idx in range(min(seed_points.size(), fragment_count)):
		var seed_point = seed_points[seed_idx]
		
		# Find boundary points for this fragment using Voronoi-like method
		# We'll create a polygon by finding points that are closer to this seed than others
		var fragment_points = _generate_fragment_polygon(seed_point, seed_points, glass_half)
		
		if fragment_points.size() < 3:
			continue  # Skip invalid fragments
		
		# Calculate fragment center (centroid)
		var fragment_center = Vector2.ZERO
		for point in fragment_points:
			fragment_center += point
		fragment_center /= fragment_points.size()
		
		# Direction from window center to fragment center
		var radial_dir = fragment_center.normalized() if fragment_center.length() > 0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# Combine kick direction with slight radial spread (mostly in kick direction)
		var shatter_dir = (kick_direction.normalized() * 0.85 + radial_dir * 0.15).normalized()
		var shatter_vel = shatter_dir * randf_range(
			shatter_force - shatter_force_variation,
			shatter_force + shatter_force_variation
		)
		
		# Add minimal random rotation to keep some variation
		shatter_vel = shatter_vel.rotated(randf_range(-0.15, 0.15))
		
		# Add slight color variation for glass effect
		var fragment_color = window_color
		fragment_color.r = clamp(fragment_color.r + randf_range(-0.1, 0.1), 0.0, 1.0)
		fragment_color.g = clamp(fragment_color.g + randf_range(-0.1, 0.1), 0.0, 1.0)
		fragment_color.b = clamp(fragment_color.b + randf_range(-0.05, 0.15), 0.0, 1.0)
		fragment_color.a = clamp(fragment_color.a + randf_range(-0.1, 0.1), 0.3, 0.9)
		
		var fragment = fragment_script.new()
		get_parent().add_child(fragment)
		fragment.life_time = fragment_lifetime
		fragment.setup(
			fragment_points,
			global_position + fragment_center,
			rotation + randf_range(-0.2, 0.2),
			shatter_vel,
			fragment_color,
			2000.0
		)
		
		# Track this fragment so we can change its color during timeslow
		spawned_fragments.append(fragment)
	
	# Hide the window visuals
	if glass_visual:
		glass_visual.visible = false
	if frame_visual:
		frame_visual.visible = false
	
	# Remove collision - disable collision shape and set collision layer to 0
	if collision_shape:
		collision_shape.disabled = true
	# Also set collision layer to 0 to ensure nothing can collide with it
	collision_layer = 0
	
	# Remove from group so it can't be kicked again
	remove_from_group("kickable_objects")


func _generate_fragment_polygon(seed_point: Vector2, all_seeds: Array[Vector2], glass_half: Vector2) -> PackedVector2Array:
	"""Generate an irregular polygon for a fragment using Voronoi-like approach."""
	# Find the closest seeds to determine fragment boundaries
	var nearby_seeds: Array[Vector2] = []
	var max_check_distance = min(glass_half.x, glass_half.y) * 1.5
	
	for other_seed in all_seeds:
		if other_seed == seed_point:
			continue
		var dist = seed_point.distance_to(other_seed)
		if dist < max_check_distance:
			nearby_seeds.append(other_seed)
	
	# If no nearby seeds, create a simple polygon
	if nearby_seeds.size() == 0:
		return _create_simple_irregular_polygon(seed_point, glass_half)
	
	# Sample points around seed to find Voronoi boundaries
	var sample_count = 24  # More samples = smoother but more expensive
	var boundary_points: Array[Vector2] = []
	var two_pi = PI * 2.0
	
	for i in range(sample_count):
		var angle = (two_pi * i) / sample_count
		var direction = Vector2(cos(angle), sin(angle))
		
		# Find boundary by checking when we're closer to another seed
		var step_size = min(glass_half.x, glass_half.y) / 30.0
		var last_point_in_territory = seed_point
		var found_boundary = false
		
		for step in range(30):
			var test_point = seed_point + direction * (step * step_size)
			
			# Check window bounds
			if abs(test_point.x) > glass_half.x or abs(test_point.y) > glass_half.y:
				boundary_points.append(test_point)
				found_boundary = true
				break
			
			# Check if closer to another seed
			var dist_to_seed = test_point.distance_to(seed_point)
			for other_seed in nearby_seeds:
				if test_point.distance_to(other_seed) < dist_to_seed:
					# Crossed boundary
					boundary_points.append(last_point_in_territory)
					found_boundary = true
					break
			
			if found_boundary:
				break
			
			last_point_in_territory = test_point
		
		if not found_boundary:
			boundary_points.append(last_point_in_territory)
	
	# Remove duplicate or very close points
	var cleaned_points: Array[Vector2] = []
	var min_point_distance = min(glass_half.x, glass_half.y) * 0.05
	
	for point in boundary_points:
		var is_duplicate = false
		for existing in cleaned_points:
			if point.distance_to(existing) < min_point_distance:
				is_duplicate = true
				break
		if not is_duplicate:
			cleaned_points.append(point)
	
	# Need at least 3 points for a polygon
	if cleaned_points.size() < 3:
		return _create_simple_irregular_polygon(seed_point, glass_half)
	
	# Sort points by angle from seed to create proper polygon order
	cleaned_points.sort_custom(func(a, b): return (a - seed_point).angle() < (b - seed_point).angle())
	
	# Create polygon: start from seed, go to boundary points, return to seed
	var polygon_points = PackedVector2Array()
	polygon_points.append(seed_point)
	
	for point in cleaned_points:
		polygon_points.append(point)
	
	# Close polygon by returning to first boundary point (or seed)
	if polygon_points.size() > 2:
		polygon_points.append(polygon_points[0])
	
	return polygon_points


func _create_simple_irregular_polygon(center: Vector2, glass_half: Vector2) -> PackedVector2Array:
	"""Create a simple irregular polygon as fallback."""
	# Create a random polygon with 3-7 vertices (more variety)
	var vertex_count = randi_range(3, 7)
	var base_radius = randf_range(min(glass_half.x, glass_half.y) * 0.15, min(glass_half.x, glass_half.y) * 0.35)
	var two_pi = PI * 2.0
	
	var points = PackedVector2Array()
	points.append(center)  # Start from center
	
	# Generate vertices with random angles and distances for irregularity
	var angles: Array[float] = []
	for i in range(vertex_count):
		angles.append((two_pi * i) / vertex_count + randf_range(-0.4, 0.4))
	
	angles.sort()  # Sort angles to ensure proper polygon order
	
	for angle in angles:
		var distance = base_radius * randf_range(0.6, 1.4)  # Vary distance for irregularity
		var point = center + Vector2(cos(angle), sin(angle)) * distance
		points.append(point)
	
	# Close polygon
	if points.size() > 2:
		points.append(points[0])
	
	return points




func can_be_kicked() -> bool:
	"""Check if this window can currently be kicked."""
	return not is_shattered
