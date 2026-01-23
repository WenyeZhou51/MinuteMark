extends StaticBody2D

# ====================================
# WINDOW OBJECT
# ====================================
# A window that shatters into many pieces when kicked
# Unlike kickable objects, it doesn't fly away - it just breaks immediately
# Acts as a physical barrier until shattered

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

# Internal state
var is_shattered: bool = false

# Visual references
@onready var glass_visual: Polygon2D = $GlassVisual
@onready var frame_visual: Polygon2D = $FrameVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


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


func _update_visuals() -> void:
	"""Update visual polygons for glass and frame."""
	var half_size = window_size / 2.0
	
	# Glass visual (slightly smaller than frame to show frame border)
	var glass_half = half_size - Vector2(frame_thickness, frame_thickness)
	if glass_visual:
		glass_visual.polygon = PackedVector2Array([
			Vector2(-glass_half.x, -glass_half.y),
			Vector2(glass_half.x, -glass_half.y),
			Vector2(glass_half.x, glass_half.y),
			Vector2(-glass_half.x, glass_half.y)
		])
		glass_visual.color = window_color
	
	# Frame visual (full size rectangle)
	if frame_visual:
		frame_visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		frame_visual.color = window_frame_color
	
	# Update collision shape
	if collision_shape:
		var shape = RectangleShape2D.new()
		shape.size = window_size
		collision_shape.shape = shape


func kick(direction: Vector2, speed: float = 0.0) -> void:
	"""Called when player kicks this window - shatter immediately."""
	if is_shattered:
		return  # Already shattered
	
	is_shattered = true
	_shatter(direction)


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
		
		# Combine kick direction with radial explosion
		var shatter_dir = (kick_direction.normalized() * 0.3 + radial_dir * 0.7).normalized()
		var shatter_vel = shatter_dir * randf_range(
			shatter_force - shatter_force_variation,
			shatter_force + shatter_force_variation
		)
		
		# Add some random rotation
		shatter_vel = shatter_vel.rotated(randf_range(-0.3, 0.3))
		
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
	
	# Clean up after a short delay (in case we want to keep the frame visible)
	_cleanup_after_delay()


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


func _cleanup_after_delay() -> void:
	"""Clean up the window after a short delay."""
	await get_tree().create_timer(0.1).timeout
	queue_free()


func can_be_kicked() -> bool:
	"""Check if this window can currently be kicked."""
	return not is_shattered
