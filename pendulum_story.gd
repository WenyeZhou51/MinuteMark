extends Node2D

# Inspector-adjustable properties
@export var bob_radius: float = 120.0
@export var bob_sprite_scale_multiplier: float = 2.25
@export var pendulum_line_width: float = 4.0
@export_range(0.0, 2000.0, 10.0) var pendulum_length: float = 1500.0
@export_range(0.0, 90.0, 1.0) var max_swing_angle: float = 60.0  # Degrees from vertical
@export_range(0.0, 90.0, 1.0) var cutoff_angle: float = 50.0  # Degrees from vertical - when reached, show complete image

@export_range(0.0, 1.0, 0.01) var transition_threshold: float = 0.9  # 0.9 = 90% of total swing (~60° past center if max_swing is 75°)

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
@onready var pendulum_sound = $PendulumSound
@onready var image_transform = $ImageTransform  # Template ColorRect for image sizing/positioning (visible guide)
@onready var image_bottom = $ImageBottom  # Current frame
@onready var image_top = $ImageTop  # Next frame

var story_textures: Array[Texture2D] = []
var current_story_index: int = 0  # Index of the image currently being revealed (top image)
var is_swinging_right: bool = true # True if moving L->R, False if moving R->L
var sound_played_this_swing: bool = false

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
	load_story_textures()
	
	if story_textures.size() >= 2:
		image_bottom.texture = story_textures[0]
		image_top.texture = story_textures[1]
	elif story_textures.size() == 1:
		image_bottom.texture = story_textures[0]
		image_top.visible = false
	
	# Ensure images are correctly sized and positioned
	setup_images()
	
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
	
	# Debug print all loaded textures
	print("\n=== All Story Textures Loaded ===")
	for i in range(story_textures.size()):
		print("Index ", i, ": ", story_textures[i].resource_path)
	print("=================================\n")

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
				# Don't allow dragging if we've reached the end of the sequence
				if current_story_index + 1 >= story_textures.size():
					return
					
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
	
	elif event is InputEventMouseMotion and is_dragging:
		# Calculate angle from pivot to mouse
		var mouse_vector = event.position - pivot_point
		
		# Only process if mouse is below the pivot (can't swing upward)
		if mouse_vector.y > 0:
			var target_angle = atan2(mouse_vector.y, mouse_vector.x)
			
			# Clamp between start and end angles
			var min_angle = min(start_angle, end_angle)
			var max_angle = max(start_angle, end_angle)
			current_angle = clamp(target_angle, min_angle, max_angle)

func get_pendulum_end() -> Vector2:
	return pivot_point + Vector2(cos(current_angle), sin(current_angle)) * pendulum_length

func update_pendulum():
	# Update line visual
	var pendulum_end = get_pendulum_end()
	line.points = PackedVector2Array([pivot_point, pendulum_end])
	
	# Update bob position (the weight at the end) and rotation
	bob.position = pendulum_end
	bob.rotation = current_angle - PI/2 # Point the top of the sprite towards the pivot
	
	# Update mask
	update_mask()

func update_mask():
	# Paint splatter reveal that begins when pendulum swings reveal_start_angle_offset PAST vertical center
	
	var swing_from_start = rad_to_deg(abs(current_angle - start_angle))
	var total_swing_range = max_swing_angle * 2.0
	
	# Calculate total swing progress (0.0 to 1.0)
	var total_progress = swing_from_start / total_swing_range if total_swing_range > 0 else 0.0
	
	# AUTOMATIC TRANSITION: Trigger when swing threshold is reached
	# No is_dragging or release check required anymore
	if total_progress >= transition_threshold:
		complete_transition()
		return
	
	var reveal_trigger_angle = max_swing_angle + reveal_start_angle_offset
	
	# Calculate reveal progress for shader
	var reveal_progress = 0.0
	
	if swing_from_start >= reveal_trigger_angle:
		var reveal_range = total_swing_range - reveal_trigger_angle
		
		if reveal_range > 0:
			reveal_progress = (swing_from_start - reveal_trigger_angle) / reveal_range
			reveal_progress = clamp(reveal_progress, 0.0, 1.0)
		else:
			reveal_progress = 1.0
			
		# Play pendulum sound when reveal starts
		if !sound_played_this_swing and reveal_progress > 0.01:
			if pendulum_sound:
				pendulum_sound.play()
				sound_played_this_swing = true
	
	# Update shader parameters for paint splatter reveal
	var shader_material = image_top.material as ShaderMaterial
	if shader_material != null:
		# Update progress
		shader_material.set_shader_parameter("reveal_progress", reveal_progress)
		
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
		
		# Debug output
		var progress_percent = int(total_progress * 10)
		if progress_percent != get_meta("last_progress_shown", -1):
			set_meta("last_progress_shown", progress_percent)
			print("Total Swing: %.1f%% | Reveal: %.1f%%" % [total_progress * 100.0, reveal_progress * 100.0])
	else:
		print("WARNING: Shader material is null!")

func load_story_textures():
	var dir = DirAccess.open("res://story frames/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var frame_files = []
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".png") and file_name.begins_with("P"):
				frame_files.append(file_name)
			file_name = dir.get_next()
		
		# Sort files numerically (P1, P2, P3...)
		frame_files.sort_custom(func(a, b):
			var num_a = a.substr(1).to_int()
			var num_b = b.substr(1).to_int()
			return num_a < num_b
		)
		
		for frame in frame_files:
			var tex = load("res://story frames/" + frame)
			if tex:
				story_textures.append(tex)
		
		print("Loaded ", story_textures.size(), " story textures: ", frame_files)
	else:
		print("Error: Could not open story frames directory")

func setup_images():
	# Calculate the base rect size (before scale)
	var base_width = image_transform.offset_right - image_transform.offset_left
	var base_height = image_transform.offset_bottom - image_transform.offset_top
	
	# Apply the ColorRect's scale to get the actual visual size
	var actual_width = base_width * image_transform.scale.x
	var actual_height = base_height * image_transform.scale.y
	
	# The actual top-left corner position is just the offset values
	var actual_top_left = Vector2(image_transform.offset_left, image_transform.offset_top)
	
	# Calculate the actual center
	var actual_center = actual_top_left + Vector2(actual_width / 2, actual_height / 2)
	
	# Position images at the center
	image_bottom.position = actual_center
	image_bottom.centered = true
	image_top.position = actual_center
	image_top.centered = true
	
	# Scale images to fit
	if image_bottom.texture:
		var tex_size = image_bottom.texture.get_size()
		image_bottom.scale = Vector2(actual_width / tex_size.x, actual_height / tex_size.y)
	
	if image_top.texture:
		var tex_size = image_top.texture.get_size()
		image_top.scale = Vector2(actual_width / tex_size.x, actual_height / tex_size.y)

func update_bob_visuals():
	# Load and set the sprite texture
	bob.texture = load("res://Sprites/New bob.png")
	if bob.texture:
		bob.centered = true
		var tex_size = bob.texture.get_size()
		# Scale the bob based on bob_radius and the multiplier
		var max_dim = max(tex_size.x, tex_size.y)
		var scale_factor = (bob_radius * 2.0) / max_dim * bob_sprite_scale_multiplier
		bob.scale = Vector2(scale_factor, scale_factor)
	
	# Load the pendulum sound
	var sound_stream = load("res://audio/pendulum sound.wav")
	if sound_stream:
		pendulum_sound.stream = sound_stream

func complete_transition():
	# Check if we have more images before proceeding
	if current_story_index + 1 >= story_textures.size():
		return

	print("DEBUG: complete_transition() triggered automatically at end of swing")
	print("DEBUG: Transitioning from index %d to %d" % [current_story_index, current_story_index + 1])
	
	current_story_index += 1
	
	# Update images for the next reveal
	# Current top (which is now fully revealed) becomes the new bottom
	image_bottom.texture = story_textures[current_story_index]
	
	# If there's a next image, load it into the top
	if current_story_index + 1 < story_textures.size():
		image_top.texture = story_textures[current_story_index + 1]
		image_top.visible = true
		
		# Reset shader for the NEW top image
		var shader_material = image_top.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("reveal_progress", 0.0)
			if image_top.texture:
				var tex_size = image_top.texture.get_size()
				shader_material.set_shader_parameter("aspect_ratio", tex_size.x / tex_size.y)
		
		# SWAP SWING DIRECTION
		# The end of the previous swing is the START of the next swing
		var temp = start_angle
		start_angle = end_angle
		end_angle = temp
		
		is_swinging_right = !is_swinging_right
		
		# Force update current_angle to the new start so we don't trigger again immediately
		current_angle = start_angle
		
		# Reset sound flag for the next swing
		sound_played_this_swing = false
		
		# Update scaling for the new textures
		setup_images()
		
		print("DEBUG: Ready for next swing. New start: %.1f, end: %.1f" % [rad_to_deg(start_angle), rad_to_deg(end_angle)])
	else:
		print("DEBUG: Final image reached. Sequence complete.")
		# Last image revealed, hide image_top or set it to fully visible
		var shader_material = image_top.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("reveal_progress", 1.0)
		is_dragging = false # Finished the whole thing

