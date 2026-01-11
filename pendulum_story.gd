extends Node2D

signal story_finished

# Inspector-adjustable properties
@export var bob_radius: float = 120.0
@export var bob_sprite_scale_multiplier: float = 2.25
@export var pendulum_line_width: float = 4.0
@export_range(0.0, 2000.0, 10.0) var pendulum_length: float = 1500.0
@export_range(0.0, 90.0, 1.0) var max_swing_angle: float = 60.0  # Degrees from vertical
@export_range(0.0, 90.0, 1.0) var cutoff_angle: float = 50.0  # Degrees from vertical - when reached, show complete image

@export_range(0.0, 1.0, 0.01) var transition_threshold: float = 0.98  # Trigger transition at 98% of swing
@export_range(0.0, 90.0, 1.0) var reveal_start_angle_offset: float = -10.0  # Start reveal earlier

@export_group("Physics")
@export var gravity: float = 980.0
@export var damping: float = 0.995 # Air resistance
@export var drag_stiffness: float = 10.0 # How fast it follows mouse

# Variables
var smoothed_reveal_progress: float = 0.0
var is_transitioning: bool = false

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
var angular_velocity: float = 0.0
var start_angle: float = 0.0  # Left side (pointing to bottom-left)
var end_angle: float = 0.0  # Right side (pointing to bottom-right)

var frame_border: Sprite2D

func _ready():
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	print("DEBUG: Viewport size: ", viewport_size)
	
	# Initialize meta for debug tracking
	set_meta("last_progress_shown", -1)
	
	# --- BACKGROUND SETUP ---
	# We're already inside a CanvasLayer from the trigger (layer 100).
	# To ensure the background covers the game (layer 0) but is behind the pendulum (z=0),
	# we add these background nodes as children of THIS node (PendulumStory)
	# and use negative z_index to push them behind the other children (images/pendulum).
	
	# 1. Solid White Base
	var solid_bg = ColorRect.new()
	solid_bg.name = "SolidBackground"
	solid_bg.color = Color.WHITE
	# Since we are in a Node2D, anchors don't automatically fill parent unless parent is Control.
	# But we can set size manually to viewport size.
	solid_bg.size = viewport_size
	solid_bg.position = Vector2.ZERO
	solid_bg.z_index = -100 # Put behind everything else in this scene
	add_child(solid_bg)
	
	# 2. Static Pocket Watch Background (semi-transparent)
	var sprite_frames = SpriteFrames.new()
	var frames_loaded = 0
	for i in range(11): # frames 0000 to 0010
		var frame_path = "res://Sprites/pocket_watch_frames/frame_%04d.png" % i
		var tex = load(frame_path)
		if tex:
			sprite_frames.add_frame("default", tex)
			frames_loaded += 1
	
	if frames_loaded > 0:
		# Use Sprite2D for better positioning control
		var static_bg = Sprite2D.new()
		static_bg.name = "BackgroundStatic"
		var tex = sprite_frames.get_frame_texture("default", 0)
		static_bg.texture = tex
		
		# Calculate scale to cover viewport
		var tex_size = tex.get_size()
		var scale_x = viewport_size.x / tex_size.x
		var scale_y = viewport_size.y / tex_size.y
		var final_scale = max(scale_x, scale_y)
		static_bg.scale = Vector2(final_scale, final_scale)
		
		# Position at center + offset to move the "shadow" watch to the right
		# Moving right by 250px
		static_bg.position = Vector2(viewport_size.x / 2.0 + 250.0, viewport_size.y / 2.0)
		
		static_bg.modulate = Color(1, 1, 1, 0.5)
		static_bg.z_index = -99 # Slightly above solid bg
		add_child(static_bg)
		print("DEBUG: Loaded pocket watch background frame")
	else:
		print("WARNING: Could not load pocket watch frames for background!")

	# 3. Texture Overlay
	var bg_tex = load("res://Sprites/Bg white overlay .png")
	if bg_tex:
		var bg_overlay = TextureRect.new()
		bg_overlay.name = "BackgroundOverlay"
		bg_overlay.texture = bg_tex
		bg_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_overlay.stretch_mode = TextureRect.STRETCH_SCALE
		bg_overlay.size = viewport_size
		bg_overlay.position = Vector2.ZERO
		bg_overlay.z_index = -98 # Above static bg
		# Ensure it blends nicely (multiply if possible, or just normal with alpha)
		# Assuming the texture is a paper grain/texture
		bg_overlay.modulate = Color(0.9, 0.9, 0.9, 1.0) 
		add_child(bg_overlay)
		print("DEBUG: Loaded background overlay")
	# ------------------------
	
	# Create border frame
	var border_tex = load("res://Sprites/Border.png")
	if border_tex:
		frame_border = Sprite2D.new()
		frame_border.texture = border_tex
		frame_border.name = "FrameBorder"
		add_child(frame_border)
		# Ensure it's above images but below pendulum
		# Pendulum is a separate node, images are separate nodes. 
		# We need to check scene tree order.
		# ImageBottom and ImageTop are direct children. Pendulum is direct child.
		# We want order: BG -> Images -> Border -> Pendulum
		# Currently: BG (0,1), ImageBottom, ImageTop, Pendulum
		# So we can move border to be after ImageTop
	
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
	
	# Debug: Print pendulum children and remove potential ghost shadows
	print("Checking Pendulum children:")
	for child in pendulum.get_children():
		print("- ", child.name, " (", child.get_class(), ")")
		# Remove any Sprite2D that isn't the Bob (e.g. leftover shadows)
		if child is Sprite2D and child != bob:
			print("Removing rogue sprite: ", child.name)
			child.queue_free()
	
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
	
	# Center the image transform
	# var viewport_w = viewport_size.x
	# var viewport_h = viewport_size.y
	
	# Hide the debug transform guide
	image_transform.visible = false
	
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

func _process(delta):
	# Don't update physics if we are in the middle of a transition pause
	if is_transitioning:
		return

	# Physics simulation
	if is_dragging:
		# When dragging, we don't simulate full gravity, but we calculate velocity based on drag
		# This makes it feel heavy when released
		# Actually, let's just use simple following for now to avoid complexity, but track velocity?
		# No, let's make it follow the mouse with some springiness
		var mouse_pos = get_global_mouse_position()
		var mouse_vector = mouse_pos - pivot_point
		if mouse_vector.y > 0:
			var target_angle = atan2(mouse_vector.y, mouse_vector.x)
			
			# Calculate torque towards mouse
			var angle_diff = target_angle - current_angle
			
			# Correct for wrapping if necessary (though with clamp it might not be needed)
			while angle_diff > PI: angle_diff -= 2 * PI
			while angle_diff < -PI: angle_diff += 2 * PI
			
			# Spring force
			var spring_accel = angle_diff * drag_stiffness
			
			# Damping
			angular_velocity *= 0.9 # Heavy damping while dragging
			angular_velocity += spring_accel * delta
			
			current_angle += angular_velocity * delta
			
			# Hard limits still apply? Maybe softer limits?
			# Let's keep hard limits for the game logic
			var min_angle = min(start_angle, end_angle)
			var max_angle = max(start_angle, end_angle)
			
			if current_angle < min_angle:
				current_angle = min_angle
				angular_velocity = 0
			elif current_angle > max_angle:
				current_angle = max_angle
				angular_velocity = 0
				
	else:
		# Free swing with gravity
		# Gravity torque = -g/L * sin(theta - PI/2)
		# Angle is 0 at right, PI/2 at down
		# We want 0 torque at PI/2.
		# Torque = - (g / length) * sin(angle - PI/2)
		# sin(angle - PI/2) = -cos(angle)
		
		# Pendulum physics: alpha = - (g / L) * sin(theta)
		# BUT our theta 0 is Horizontal Right.
		# Real pendulum theta 0 is usually straight down.
		# Let's convert: real_theta = current_angle - PI/2
		# alpha = - (g / L) * sin(current_angle - PI/2)
		
		var angular_accel = - (gravity / pendulum_length) * cos(current_angle)
		
		angular_velocity += angular_accel * delta
		angular_velocity *= damping
		
		current_angle += angular_velocity * delta
		
		# Bounce off limits?
		var min_angle = min(start_angle, end_angle)
		var max_angle = max(start_angle, end_angle)
		
		# Simple bounce
		if current_angle < min_angle:
			current_angle = min_angle
			angular_velocity *= -0.5
		elif current_angle > max_angle:
			current_angle = max_angle
			angular_velocity *= -0.5

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
			angular_velocity = 0
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
				
				if distance < max(80.0, bob_radius):  # Click within 80px of line or within bob radius
					is_dragging = true
					angular_velocity = 0 # Reset velocity on grab
					var current_deg = rad_to_deg(current_angle)
					var start_deg = rad_to_deg(start_angle)
					print("Started dragging | Current angle: %.1f° | Start angle: %.1f°" % [current_deg, start_deg])
			else:
				is_dragging = false
	
	# Mouse motion handled in _process now

func get_pendulum_end() -> Vector2:
	return pivot_point + Vector2(cos(current_angle), sin(current_angle)) * pendulum_length

func update_pendulum():
	# Update line visual
	var pendulum_end = get_pendulum_end()
	line.points = PackedVector2Array([pivot_point, pendulum_end])
	
	# Update bob position (the weight at the end) and rotation
	bob.rotation = current_angle - PI/2 # Point the top of the sprite towards the pivot
	
	# Position bob directly at the end of the line
	bob.position = pendulum_end
	
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
		# Smooth the reveal progress
		smoothed_reveal_progress = lerp(smoothed_reveal_progress, reveal_progress, 5.0 * get_process_delta_time())
		
		# Update progress
		shader_material.set_shader_parameter("reveal_progress", smoothed_reveal_progress)
		
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
	# Use the viewport center instead of the ImageTransform guide
	var viewport_size = get_viewport_rect().size
	var actual_center = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0 + 50.0) # Slightly lower than center
	
	# Calculate target size (use ImageTransform scale as a reference for size)
	var base_width = image_transform.offset_right - image_transform.offset_left
	var base_height = image_transform.offset_bottom - image_transform.offset_top
	# Reduce scale to 60% of original
	var actual_width = base_width * image_transform.scale.x * 0.6
	var actual_height = base_height * image_transform.scale.y * 0.6
	
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

	# Update border scale/position
	if frame_border and frame_border.texture:
		frame_border.position = actual_center
		var border_size = frame_border.texture.get_size()
		# Scale border to be slightly larger than the images
		# Assuming border texture has some thickness and inner transparent area
		# We want the inner area to match actual_width/height roughly
		# Let's just match the outer dimensions plus a bit of padding if needed, 
		# or scale to fit exactly if it's a frame.
		# Let's scale it to be slightly larger than the image (e.g. 1.15x)
		var scale_x = (actual_width / border_size.x) * 1.15
		var scale_y = (actual_height / border_size.y) * 1.15
		frame_border.scale = Vector2(scale_x, scale_y)
		
		# Move border in scene tree to be above images
		if frame_border.get_parent() == self:
			move_child(frame_border, image_top.get_index() + 1)
			
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
	
	# Start transition pause
	is_transitioning = true
	# Stop momentum
	angular_velocity = 0.0
	
	# Wait for a moment to let the user see the full image
	await get_tree().create_timer(0.4).timeout
	
	print("DEBUG: Transitioning from index %d to %d" % [current_story_index, current_story_index + 1])
	
	# Play transition sound if available
	var transition_sound = load("res://audio/menu transition.wav")
	if transition_sound:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = transition_sound
		audio_player.bus = "Master"
		add_child(audio_player)
		audio_player.play()
		# Auto-cleanup
		audio_player.finished.connect(func(): audio_player.queue_free())
	
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
			smoothed_reveal_progress = 0.0 # Reset smoothing
			
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
		angular_velocity = 0
		
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
		
		# Emit finished signal after a short delay
		await get_tree().create_timer(1.0).timeout
		story_finished.emit()
	
	# End transition pause
	is_transitioning = false
