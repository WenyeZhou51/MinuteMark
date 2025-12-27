extends Node2D

# Inspector-adjustable properties
@export var bob_radius: float = 120.0
@export var pendulum_line_width: float = 4.0
@export_range(0.0, 2000.0, 10.0) var pendulum_length: float = 1500.0
@export_range(0.0, 90.0, 1.0) var max_swing_angle: float = 60.0  # Degrees from vertical
@export_range(0.0, 90.0, 1.0) var cutoff_angle: float = 50.0  # Degrees from vertical - when reached, show complete image

@export_group("Paint Splatter Shader")
@export_range(0.0, 90.0, 1.0) var reveal_start_angle_offset: float = 30.0  # Degrees past vertical center to start reveal
@export_range(0.0, 1.0, 0.01) var center_reveal_size: float = 0.4  # Inner area that reveals instantly
@export_range(0.0, 0.2, 0.001) var outline_thickness: float = 0.03
@export_range(0.0, 0.5, 0.01) var glow_softness: float = 0.05
@export var outline_color: Color = Color.BLACK
@export_range(1.0, 50.0, 0.1) var noise_detail: float = 10.0
@export_range(0.0, 1.0, 0.01) var noise_roughness: float = 0.4
@export_range(0.0, 0.5, 0.01) var noise_softness: float = 0.05
@export_range(0.0, 100.0, 0.1) var noise_seed: float = 1.0
@export var reveal_center: Vector2 = Vector2(0.5, 0.5)
@export var show_debug_tint: bool = false
@export var debug_show_shader_mask: bool = false

@onready var pendulum = $Pendulum
@onready var pivot_visual = $Pendulum/Pivot
@onready var line = $Pendulum/Line2D
@onready var bob = $Pendulum/Bob
@onready var bob_outline = $Pendulum/BobOutline
@onready var image_transform = $ImageTransform  # Template ColorRect for image sizing/positioning (visible guide)
@onready var image_bottom = $ImageBottom  # Current frame (test1)
@onready var image_top = $ImageTop  # Next frame (test2)

var pivot_point: Vector2
var is_dragging: bool = false
var current_angle: float = 0.0  # Angle from vertical (0 = pointing down)
var start_angle: float = 0.0  # Left side (pointing to bottom-left)
var end_angle: float = 0.0  # Right side (pointing to bottom-right)

func _ready():
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
	# Initialize meta for debug tracking
	set_meta("last_progress_shown", -1)
	
	# Set pivot at TOP CENTER of screen
	pivot_point = Vector2(viewport_size.x / 2, 0)
	
	# Update pivot visual position
	var pivot_poly = PackedVector2Array([
		pivot_point,
		pivot_point + Vector2(10, 10),
		pivot_point + Vector2(0, 20),
		pivot_point + Vector2(-10, 10)
	])
	pivot_visual.polygon = pivot_poly
	
	# If pendulum_length is 0, auto-calculate to reach near bottom of screen
	if pendulum_length <= 0:
		pendulum_length = viewport_size.y - bob_radius
	
	# Update pendulum line width
	line.width = pendulum_line_width
	
	# Generate bob polygons based on bob_radius
	update_bob_visuals()
	
	# Set swing angles based on max_swing_angle
	# 0 degrees = horizontal right, 90 degrees = vertical down
	# max_swing_angle to the left: 90 + max_swing_angle
	# max_swing_angle to the right: 90 - max_swing_angle
	start_angle = deg_to_rad(90 + max_swing_angle)  # Left of vertical
	end_angle = deg_to_rad(90 - max_swing_angle)    # Right of vertical
	
	current_angle = start_angle
	
	print("Pivot: ", pivot_point)
	print("Bob radius: ", bob_radius)
	print("Pendulum line width: ", pendulum_line_width)
	print("Pendulum length: ", pendulum_length)
	print("Max swing angle: ", max_swing_angle, "°")
	print("Cutoff angle: ", cutoff_angle, "° (auto-complete at this angle)")
	print("Start angle: ", rad_to_deg(start_angle), " degrees (", max_swing_angle, "° left of vertical)")
	print("End angle: ", rad_to_deg(end_angle), " degrees (", max_swing_angle, "° right of vertical)")
	print("Swing range: ", max_swing_angle * 2, " degrees total")
	print("Cutoff threshold: ", rad_to_deg(deg_to_rad(90 - cutoff_angle)), "° (when reached, show full image)")
	
	# Load story frame images
	image_bottom.texture = load("res://story frames/test1.webp")
	image_top.texture = load("res://story frames/test2.webp")
	
	# Ensure both images are visible
	image_bottom.visible = true
	image_top.visible = true
	
	# Verify images loaded
	print("\n=== Image Loading ===")
	print("ImageBottom texture loaded: ", image_bottom.texture != null)
	if image_bottom.texture:
		print("  - Size: ", image_bottom.texture.get_size())
	print("ImageBottom visible: ", image_bottom.visible)
	print("ImageTop texture loaded: ", image_top.texture != null)
	if image_top.texture:
		print("  - Size: ", image_top.texture.get_size())
	print("ImageTop visible: ", image_top.visible)
	print("=====================\n")
	
	# Get the target rect from ImageTransform ColorRect
	# IMPORTANT: Must account for the ColorRect's scale and position!
	print("\n=== ImageTransform Debug ===")
	print("ImageTransform offset_left: ", image_transform.offset_left)
	print("ImageTransform offset_top: ", image_transform.offset_top)
	print("ImageTransform offset_right: ", image_transform.offset_right)
	print("ImageTransform offset_bottom: ", image_transform.offset_bottom)
	print("ImageTransform scale: ", image_transform.scale)
	print("ImageTransform position: ", image_transform.position)
	
	# Calculate the base rect size (before scale)
	var base_width = image_transform.offset_right - image_transform.offset_left
	var base_height = image_transform.offset_bottom - image_transform.offset_top
	
	print("Base rect size (before scale): ", Vector2(base_width, base_height))
	
	# Apply the ColorRect's scale to get the actual visual size
	# IMPORTANT: The scale only affects SIZE, not position!
	var actual_width = base_width * image_transform.scale.x
	var actual_height = base_height * image_transform.scale.y
	
	# The actual top-left corner position is just the offset values
	# (ColorRect offsets are already absolute screen positions)
	var actual_top_left = Vector2(image_transform.offset_left, image_transform.offset_top)
	
	# Calculate the actual center
	var actual_center = actual_top_left + Vector2(actual_width / 2, actual_height / 2)
	
	print("Actual visual size (after scale): ", Vector2(actual_width, actual_height))
	print("Actual top-left position: ", actual_top_left)
	print("Actual center position: ", actual_center)
	print("ColorRect global_position: ", image_transform.global_position)
	print("ColorRect size: ", image_transform.size)
	
	# Position images at the center of the actual visual rect
	image_bottom.position = actual_center
	image_bottom.centered = true
	
	image_top.position = actual_center
	image_top.centered = true
	
	print("\n=== Image Scaling Debug ===")
	
	# Calculate scale to make both images fit the actual visual size
	# regardless of their source texture resolution/aspect ratio
	if image_bottom.texture:
		var tex_size_bottom = image_bottom.texture.get_size()
		print("ImageBottom texture size: ", tex_size_bottom)
		# Scale needed to reach target size
		var scale_x = actual_width / tex_size_bottom.x
		var scale_y = actual_height / tex_size_bottom.y
		image_bottom.scale = Vector2(scale_x, scale_y)
		print("ImageBottom scale applied: ", image_bottom.scale)
		print("ImageBottom position: ", image_bottom.position)
	
	if image_top.texture:
		var tex_size_top = image_top.texture.get_size()
		print("ImageTop texture size: ", tex_size_top)
		# Scale needed to reach target size
		var scale_x = actual_width / tex_size_top.x
		var scale_y = actual_height / tex_size_top.y
		image_top.scale = Vector2(scale_x, scale_y)
		print("ImageTop scale applied: ", image_top.scale)
		print("ImageTop position: ", image_top.position)
	
	print("=== End Debug ===\n")
	
	# Load and set up the paint splatter reveal shader
	var splatter_shader = load("res://shaders/paint_splatter_reveal.gdshader")
	if splatter_shader == null:
		print("ERROR: Failed to load paint splatter shader!")
		return
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = splatter_shader
	image_top.material = shader_material
	
	print("Paint splatter shader loaded and applied to ImageTop")
	
	# Initialize shader parameters from exported variables
	shader_material.set_shader_parameter("reveal_progress", 0.0)
	shader_material.set_shader_parameter("center_position", reveal_center)
	shader_material.set_shader_parameter("center_reveal_size", center_reveal_size)
	shader_material.set_shader_parameter("outline_thickness", outline_thickness)
	shader_material.set_shader_parameter("outline_color", outline_color)
	shader_material.set_shader_parameter("edge_roughness", noise_roughness)
	shader_material.set_shader_parameter("detail_scale", noise_detail)
	shader_material.set_shader_parameter("edge_softness", noise_softness)
	shader_material.set_shader_parameter("noise_seed", noise_seed)
	shader_material.set_shader_parameter("shader_active_check", show_debug_tint)
	shader_material.set_shader_parameter("debug_show_mask_only", debug_show_shader_mask)
	
	if image_top.texture:
		var tex_size = image_top.texture.get_size()
		shader_material.set_shader_parameter("aspect_ratio", tex_size.x / tex_size.y)
	
	print("\n=== Paint Splatter Shader Initialized ===")
	print("Reveal starts when pendulum swings ", reveal_start_angle_offset, "° PAST vertical center")
	print("========================================\n")
	
	# Initialize mask
	update_pendulum()

func _process(_delta):
	update_pendulum()

func _input(event):
	# Debug: Manual shader control with keyboard (T key to test)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			# Toggle between 0 and 1 for testing
			var shader_material = image_top.material as ShaderMaterial
			if shader_material:
				var current_progress = shader_material.get_shader_parameter("reveal_progress")
				var new_progress = 1.0 if current_progress < 0.5 else 0.0
				shader_material.set_shader_parameter("reveal_progress", new_progress)
				print("DEBUG: Manual reveal_progress set to: ", new_progress)
		elif event.keycode == KEY_R:
			# Reset to start position
			current_angle = start_angle
			print("DEBUG: Reset pendulum to start position")
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicking near the pendulum line or bob
				var bob_pos = get_pendulum_end()
				var closest_point = Geometry2D.get_closest_point_to_segment(event.position, pivot_point, bob_pos)
				var distance = event.position.distance_to(closest_point)
				
				if distance < 80.0:  # Click within 80px of line or bob
					is_dragging = true
					var current_deg = rad_to_deg(current_angle)
					var start_deg = rad_to_deg(start_angle)
					print("Started dragging | Current angle: %.1f° | Start angle: %.1f°" % [current_deg, start_deg])
			else:
				is_dragging = false
				# Check if drag is complete (within 10 degrees of end)
				var angle_to_end = abs(current_angle - end_angle)
				if angle_to_end < deg_to_rad(10):
					complete_transition()
	
	elif event is InputEventMouseMotion and is_dragging:
		# Calculate angle from pivot to mouse
		var mouse_vector = event.position - pivot_point
		
		# Only process if mouse is below the pivot (can't swing upward)
		if mouse_vector.y > 0:
			var target_angle = atan2(mouse_vector.y, mouse_vector.x)
			
			# Clamp between start and end angles
			# start_angle is bottom-left (~135°), end_angle is bottom-right (~45°)
			# Both are positive, start > end
			current_angle = clamp(target_angle, end_angle, start_angle)

func get_pendulum_end() -> Vector2:
	return pivot_point + Vector2(cos(current_angle), sin(current_angle)) * pendulum_length

func update_pendulum():
	# Update line visual
	var pendulum_end = get_pendulum_end()
	line.points = PackedVector2Array([pivot_point, pendulum_end])
	
	# Update bob position (the weight at the end)
	bob.position = pendulum_end
	bob_outline.position = pendulum_end
	
	# Update mask
	update_mask()

func update_mask():
	# Paint splatter reveal that begins when pendulum swings reveal_start_angle_offset PAST vertical center
	
	var swing_from_start = rad_to_deg(start_angle - current_angle)
	var reveal_trigger_angle = max_swing_angle + reveal_start_angle_offset
	
	# Calculate reveal progress
	var progress = 0.0
	
	if swing_from_start >= reveal_trigger_angle:
		# Map from reveal_trigger_angle to total_swing (max_swing_angle * 2)
		var total_swing_range = max_swing_angle * 2.0
		var reveal_range = total_swing_range - reveal_trigger_angle
		
		if reveal_range > 0:
			progress = (swing_from_start - reveal_trigger_angle) / reveal_range
			progress = clamp(progress, 0.0, 1.0)
		else:
			progress = 1.0
	
	# Update shader parameters for paint splatter reveal
	var shader_material = image_top.material as ShaderMaterial
	if shader_material != null:
		# Update progress
		shader_material.set_shader_parameter("reveal_progress", progress)
		
		# Allow real-time tweaking in the inspector
		shader_material.set_shader_parameter("center_position", reveal_center)
		shader_material.set_shader_parameter("center_reveal_size", center_reveal_size)
		shader_material.set_shader_parameter("outline_thickness", outline_thickness)
		shader_material.set_shader_parameter("outline_color", outline_color)
		shader_material.set_shader_parameter("edge_roughness", noise_roughness)
		shader_material.set_shader_parameter("detail_scale", noise_detail)
		shader_material.set_shader_parameter("edge_softness", noise_softness)
		shader_material.set_shader_parameter("noise_seed", noise_seed)
		shader_material.set_shader_parameter("shader_active_check", show_debug_tint)
		shader_material.set_shader_parameter("debug_show_mask_only", debug_show_shader_mask)
		
		# Debug output - check center_reveal_size
		if Engine.get_frames_drawn() % 60 == 0:
			print("[DEBUG] Shader center_reveal_size: ", center_reveal_size, " | Progress: ", progress)
		
		# Debug output - show every 10% increment
		var progress_percent = int(progress * 10)
		if progress_percent != get_meta("last_progress_shown", -1):
			set_meta("last_progress_shown", progress_percent)
			print("Swing from start: %.1f° | Progress: %.1f%%" % [swing_from_start, progress * 100.0])
	else:
		print("WARNING: Shader material is null!")

func update_bob_visuals():
	# Generate bob polygon (circle approximation with 8 points)
	var bob_polygon = PackedVector2Array()
	var outline_radius = bob_radius + 15.0  # Outline is 15px larger
	
	for i in range(8):
		var angle = i * PI / 4.0  # 45 degrees per point
		bob_polygon.append(Vector2(
			cos(angle) * bob_radius,
			sin(angle) * bob_radius
		))
	
	# Generate outline polygon
	var outline_polygon = PackedVector2Array()
	for i in range(8):
		var angle = i * PI / 4.0
		outline_polygon.append(Vector2(
			cos(angle) * outline_radius,
			sin(angle) * outline_radius
		))
	
	bob.polygon = bob_polygon
	bob_outline.polygon = outline_polygon

func complete_transition():
	print("Transition complete! Showing full test2 with paint splatter reveal")
	# Here you can load the next frame or trigger the next story beat
	# The image_top (test2) will be fully visible via the shader

