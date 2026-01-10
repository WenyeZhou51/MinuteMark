extends ColorRect

# For paint splatter effect
var splatter_shader: Shader
var splatter_mode: bool = true  # Set to true to use paint splatter effect

func _ready():
	if splatter_mode:
		# Load the paint splatter shader
		splatter_shader = load("res://shaders/paint_splatter_mask.gdshader")
		
		# Create shader material
		var mat = ShaderMaterial.new()
		mat.shader = splatter_shader
		material = mat
		
		# Initialize shader parameters - adjust these for desired look
		# Note: sizes are in normalized coordinates (0-1), where 0.1 = 10% of screen
		material.set_shader_parameter("splatter_size", 0.12)  # Larger splatters to fill area
		material.set_shader_parameter("edge_roughness", 1.5)  # How rough/organic the edges are
		material.set_shader_parameter("droplet_count", 25)  # Number of satellite droplets
		material.set_shader_parameter("droplet_size_min", 0.005)  # Min droplet size (normalized)
		material.set_shader_parameter("droplet_size_max", 0.02)  # Max droplet size (normalized)
		material.set_shader_parameter("splatter_opacity", 1.0)
		material.set_shader_parameter("noise_scale", 5.0)
		material.set_shader_parameter("detail_noise_scale", 12.0)
		material.set_shader_parameter("num_trail_splatters", 4)  # Extra splatters near current position
		material.set_shader_parameter("pendulum_position", Vector2(0.0, 0.5))
		material.set_shader_parameter("accumulation_progress", 0.0)
		# Arc parameters will be set by update_arc_parameters()

func set_arc_parameters(pivot_pos: Vector2, viewport_size: Vector2, pend_length: float, start_angle: float, end_angle: float):
	"""Set the pendulum arc parameters for accurate splatter placement"""
	if !splatter_mode or material == null:
		return
	
	# Normalize pivot position to 0-1 range
	var normalized_pivot = pivot_pos / viewport_size
	
	# Normalize pendulum length (as a fraction of viewport height for consistency)
	var normalized_length = pend_length / viewport_size.y
	
	material.set_shader_parameter("pivot_position", normalized_pivot)
	material.set_shader_parameter("pendulum_length", normalized_length)
	material.set_shader_parameter("start_angle_rad", start_angle)
	material.set_shader_parameter("end_angle_rad", end_angle)

func _draw():
	if !splatter_mode:
		# Original polygon drawing mode (fallback)
		if has_meta("polygon"):
			var polygon = get_meta("polygon") as PackedVector2Array
			if polygon.size() > 0:
				draw_colored_polygon(polygon, Color.WHITE)

func update_splatter(pendulum_pos: Vector2, viewport_size: Vector2, progress: float):
	if !splatter_mode or material == null:
		return
	
	# Normalize pendulum position to 0-1 range for the shader
	var normalized_pos = pendulum_pos / viewport_size
	
	# Update shader parameters
	material.set_shader_parameter("pendulum_position", normalized_pos)
	material.set_shader_parameter("accumulation_progress", progress)

func reset_splatters():
	"""Reset the accumulated splatters"""
	if splatter_mode and material != null:
		material.set_shader_parameter("accumulation_progress", 0.0)
		material.set_shader_parameter("pendulum_position", Vector2(0.0, 0.5))
