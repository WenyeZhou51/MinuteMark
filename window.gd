extends StaticBody2D

# ====================================
# WINDOW OBJECT
# ====================================
# A window that shatters into many pieces when kicked
# Unlike kickable objects, it doesn't fly away - it just breaks immediately
# Acts as a physical barrier until shattered

# CONFIGURATION
@export_group("Window Properties")
@export var window_size: Vector2 = Vector2(60, 80)  ## Size of the window
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
	"""Shatter the window into many fragments."""
	var half_size = window_size / 2.0
	var glass_half = half_size - Vector2(frame_thickness, frame_thickness)
	var fragment_script = load("res://kickable_fragment.gd")
	
	# Create a grid of fragments for more realistic glass shattering
	# Calculate grid dimensions
	var grid_cols = int(sqrt(fragment_count)) + 1
	var grid_rows = int(sqrt(fragment_count)) + 1
	
	# Size of each grid cell
	var cell_width = (glass_half.x * 2) / grid_cols
	var cell_height = (glass_half.y * 2) / grid_rows
	
	# Create fragments in a grid pattern
	var fragment_index = 0
	for row in range(grid_rows):
		for col in range(grid_cols):
			if fragment_index >= fragment_count:
				break
			
			# Calculate cell position (top-left corner of cell)
			var cell_x = -glass_half.x + col * cell_width
			var cell_y = -glass_half.y + row * cell_height
			
			# Create a fragment from this cell (triangle from center of cell to corners)
			var cell_center = Vector2(
				cell_x + cell_width / 2.0,
				cell_y + cell_height / 2.0
			)
			
			# Create triangle fragments from cell center to two adjacent corners
			var corner1 = Vector2(cell_x, cell_y)
			var corner2 = Vector2(cell_x + cell_width, cell_y)
			var corner3 = Vector2(cell_x + cell_width, cell_y + cell_height)
			var corner4 = Vector2(cell_x, cell_y + cell_height)
			
			# Create fragments - use different triangle patterns for variety
			var fragment_patterns = [
				PackedVector2Array([cell_center, corner1, corner2]),
				PackedVector2Array([cell_center, corner2, corner3]),
				PackedVector2Array([cell_center, corner3, corner4]),
				PackedVector2Array([cell_center, corner4, corner1])
			]
			
			# Create 1-2 fragments per cell depending on remaining count
			var fragments_per_cell = 2 if (fragment_count - fragment_index) >= 2 else 1
			
			for i in range(fragments_per_cell):
				if fragment_index >= fragment_count:
					break
				
				var fragment_points = fragment_patterns[i % fragment_patterns.size()]
				var fragment_center_local = cell_center
				
				# Direction from window center to fragment center
				var radial_dir = fragment_center_local.normalized() if fragment_center_local.length() > 0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				
				# Combine kick direction with radial explosion
				var shatter_dir = (kick_direction.normalized() * 0.3 + radial_dir * 0.7).normalized()
				var shatter_vel = shatter_dir * randf_range(
					shatter_force - shatter_force_variation,
					shatter_force + shatter_force_variation
				)
				
				# Add some random rotation
				shatter_vel = shatter_vel.rotated(randf_range(-0.3, 0.3))
				
				# Add slight color variation for glass effect (slight brightness/transparency variation)
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
					global_position + fragment_center_local,
					rotation + randf_range(-0.2, 0.2),  # Add slight rotation variation
					shatter_vel,
					fragment_color,
					2000.0  # Gravity strength
				)
				
				fragment_index += 1
		
		if fragment_index >= fragment_count:
			break
	
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
	await get_tree().create_timer(0.1).timeout
	queue_free()


func can_be_kicked() -> bool:
	"""Check if this window can currently be kicked."""
	return not is_shattered
