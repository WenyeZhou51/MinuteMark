extends Node2D

signal story_finished

# Inspector-adjustable properties
@export var bob_radius: float = 250.0
@export var bob_sprite_scale_multiplier: float = 2.25
@export var pendulum_line_width: float = 8.0
@export_range(0.0, 2000.0, 10.0) var pendulum_length: float = 950.0
@export_range(0.0, 90.0, 1.0) var max_swing_angle: float = 75.0  # Degrees from vertical
@export_range(0.0, 90.0, 1.0) var cutoff_angle: float = 50.0  # Degrees from vertical - when reached, show complete image

@export_range(0.0, 1.0, 0.01) var transition_threshold: float = 0.98  # Trigger transition at 98% of swing
@export_range(0.0, 90.0, 1.0) var reveal_start_angle_offset: float = -10.0  # Start reveal earlier

@export_group("Physics")
@export var gravity: float = 980.0
@export var damping: float = 0.995 # Air resistance
@export var drag_stiffness: float = 25.0 # How fast it follows mouse
@export var keyboard_force: float = 8.0 # Force applied by keyboard controls

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

@export_group("Story Frames")
@export var frames_directory: String = "res://story frames/"
@export var file_prefix: String = "P"

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
var instruction_label: Label
var instructions_faded: bool = false

var idle_hint_label: Label
var frame_idle_time: float = 0.0
var idle_hint_visible: bool = false
@export var idle_hint_delay: float = 5.0

@export_range(0.0, 1.0, 0.01) var auto_complete_threshold: float = 0.5
@export var auto_complete_angular_speed: float = 10.0
var is_auto_completing: bool = false
var awaiting_final_swing: bool = false

func _ready():
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
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
	else:
		pass

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
	# ------------------------
	
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
	
	# Remove potential ghost shadows
	for child in pendulum.get_children():
		# Remove any Sprite2D that isn't the Bob (e.g. leftover shadows)
		if child is Sprite2D and child != bob:
			child.queue_free()
	
	# Set swing angles based on max_swing_angle
	# 0 degrees = horizontal right, 90 degrees = vertical down
	# max_swing_angle to the left: 90 + max_swing_angle
	# max_swing_angle to the right: 90 - max_swing_angle
	start_angle = deg_to_rad(90 + max_swing_angle)  # Left of vertical
	end_angle = deg_to_rad(90 - max_swing_angle)    # Right of vertical
	
	current_angle = start_angle
	
	
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
	
	# Hide the transform guide
	image_transform.visible = false
	
	# Load and set up the paint splatter reveal shader
	var splatter_shader = load("res://shaders/paint_splatter_reveal.gdshader")
	if splatter_shader == null:
		return
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = splatter_shader
	image_top.material = shader_material
	
	
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
	
	if image_top.texture:
		var tex_size = image_top.texture.get_size()
		shader_material.set_shader_parameter("aspect_ratio", tex_size.x / tex_size.y)
	
	
	# Initialize mask
	update_pendulum()
	
	# Setup instructions
	setup_instructions()
	

func _process(delta):
	if is_transitioning:
		return

	if is_auto_completing:
		var direction = sign(end_angle - start_angle)
		current_angle += direction * auto_complete_angular_speed * delta
		var min_a = min(start_angle, end_angle)
		var max_a = max(start_angle, end_angle)
		current_angle = clamp(current_angle, min_a, max_a)
		update_pendulum()
		return

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
		
		# Keyboard/Gamepad Input
		# move_left (negative axis) -> we want positive angle change (towards left/PI)
		# move_right (positive axis) -> we want negative angle change (towards right/0)
		var input_axis = Input.get_axis("move_left", "move_right")
		if input_axis != 0:
			angular_accel -= input_axis * keyboard_force
		
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

	var swing_from_start_deg = rad_to_deg(abs(current_angle - start_angle))
	var total_swing_range = max_swing_angle * 2.0
	var swing_progress = swing_from_start_deg / total_swing_range if total_swing_range > 0 else 0.0
	if swing_progress >= auto_complete_threshold and not is_auto_completing:
		is_dragging = false
		is_auto_completing = true

	if not is_dragging and not is_auto_completing:
		frame_idle_time += delta
		if frame_idle_time >= idle_hint_delay and not idle_hint_visible:
			show_idle_hint()

	update_pendulum()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_auto_completing:
					return
				if current_story_index + 1 >= story_textures.size() and not awaiting_final_swing:
					return
					
				# Check if clicking near the pendulum line or bob
				var bob_pos = get_pendulum_end()
				var closest_point = Geometry2D.get_closest_point_to_segment(event.position, pivot_point, bob_pos)
				var distance = event.position.distance_to(closest_point)
				
				if distance < max(80.0, bob_radius):  # Click within 80px of line or within bob radius
					is_dragging = true
					angular_velocity = 0 # Reset velocity on grab
					hide_idle_hint()
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
	
	# Check for instruction fade out
	if !instructions_faded and instruction_label:
		# If moving significantly or dragging or using keys
		var is_moving = abs(angular_velocity) > 0.1
		var input_active = Input.get_axis("move_left", "move_right") != 0
		
		if is_dragging or input_active:
			fade_out_instructions()

func update_mask():
	var swing_from_start = rad_to_deg(abs(current_angle - start_angle))
	var total_swing_range = max_swing_angle * 2.0
	var total_progress = swing_from_start / total_swing_range if total_swing_range > 0 else 0.0
	
	if total_progress >= transition_threshold:
		complete_transition()
		return
	
	if awaiting_final_swing:
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
	else:
		pass

func load_story_textures():
	var image_extensions = ["png", "jpg", "jpeg", "webp"]
	var max_probe = 50
	for i in range(1, max_probe + 1):
		var found = false
		for ext in image_extensions:
			var path = frames_directory.path_join(file_prefix + str(i) + "." + ext)
			if ResourceLoader.exists(path):
				var tex = load(path)
				if tex:
					story_textures.append(tex)
					found = true
					break
		if not found and i > 1:
			break

func _extract_frame_number(filename: String) -> int:
	var base = filename.get_basename()
	if !file_prefix.is_empty() and base.begins_with(file_prefix):
		base = base.substr(file_prefix.length())
	return base.to_int()

func setup_images():
	# Use the viewport center instead of the ImageTransform guide
	var viewport_size = get_viewport_rect().size
	var actual_center = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0) # True center
	
	# Position images at the center
	image_bottom.position = actual_center
	image_bottom.centered = true
	image_top.position = actual_center
	image_top.centered = true
	
	# Scale images to fit
	if image_bottom.texture:
		var tex_size = image_bottom.texture.get_size()
		# Calculate scale to FIT the viewport (min of x/y ratios)
		var scale_x = viewport_size.x / tex_size.x
		var scale_y = viewport_size.y / tex_size.y
		# Use max to ensure it covers the whole screen (Aspect Fill)
		var final_scale = max(scale_x, scale_y) * 1.0
		
		image_bottom.scale = Vector2(final_scale, final_scale)
		
		if image_top.texture:
			# Assume same size/aspect ratio for top image or recalculate
			var top_tex_size = image_top.texture.get_size()
			# Apply same logic to top image
			var top_scale_x = viewport_size.x / top_tex_size.x
			var top_scale_y = viewport_size.y / top_tex_size.y
			var top_final_scale = max(top_scale_x, top_scale_y) * 1.0
			image_top.scale = Vector2(top_final_scale, top_final_scale)

func update_bob_visuals():
	# Load and set the sprite texture
	bob.texture = load("res://Sprites/Final new bob.png")
	if bob.texture:
		bob.centered = true
		bob.modulate = Color.WHITE
		bob.self_modulate = Color.WHITE
		var tex_size = bob.texture.get_size()
		var max_dim = max(tex_size.x, tex_size.y)
		var scale_factor = (bob_radius * 2.0) / max_dim * bob_sprite_scale_multiplier
		bob.scale = Vector2(scale_factor, scale_factor)
	
	# Load the pendulum sound
	var sound_stream = load("res://audio/pendulum sound.ogg")
	if sound_stream:
		pendulum_sound.stream = sound_stream

func setup_instructions():
	instruction_label = Label.new()
	instruction_label.text = "Hold [A][D] / [←][→] or Drag Mouse to Swing"
	
	# Style the label
	instruction_label.add_theme_font_size_override("font_size", 64)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_constant_override("outline_size", 12)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Add shadow for extra visibility
	instruction_label.add_theme_constant_override("shadow_offset_x", 4)
	instruction_label.add_theme_constant_override("shadow_offset_y", 4)
	instruction_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	
	# Try to load custom font
	var font = load("res://Fonts/Funkrocker.otf")
	if font:
		instruction_label.add_theme_font_override("font", font)
	
	# Center at bottom
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var viewport_size = get_viewport_rect().size
	instruction_label.size = Vector2(viewport_size.x, 100)
	instruction_label.position = Vector2(0, viewport_size.y - 200) # Slightly higher
	instruction_label.z_index = 100 # Ensure it's on top of everything (z=10 might be too low if bg layers are weird)
	
	add_child(instruction_label)

func fade_out_instructions():
	if instructions_faded: return
	instructions_faded = true
	
	var tween = create_tween()
	tween.tween_property(instruction_label, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(instruction_label.queue_free)

func show_idle_hint():
	if idle_hint_visible:
		return
	if current_story_index + 1 >= story_textures.size() and not awaiting_final_swing:
		return
	idle_hint_visible = true
	
	idle_hint_label = Label.new()
	idle_hint_label.text = "Drag pendulum across to continue"
	idle_hint_label.add_theme_font_size_override("font_size", 52)
	idle_hint_label.add_theme_color_override("font_color", Color.WHITE)
	idle_hint_label.add_theme_constant_override("outline_size", 10)
	idle_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	idle_hint_label.add_theme_constant_override("shadow_offset_x", 3)
	idle_hint_label.add_theme_constant_override("shadow_offset_y", 3)
	idle_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	
	var font = load("res://Fonts/Funkrocker.otf")
	if font:
		idle_hint_label.add_theme_font_override("font", font)
	
	idle_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idle_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var viewport_size = get_viewport_rect().size
	idle_hint_label.size = Vector2(viewport_size.x, 100)
	idle_hint_label.position = Vector2(0, viewport_size.y - 180)
	idle_hint_label.z_index = 100
	idle_hint_label.modulate.a = 0.0
	add_child(idle_hint_label)
	
	var tween = create_tween()
	tween.tween_property(idle_hint_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_idle_hint():
	if not idle_hint_visible:
		return
	idle_hint_visible = false
	frame_idle_time = 0.0
	if idle_hint_label and is_instance_valid(idle_hint_label):
		var tween = create_tween()
		tween.tween_property(idle_hint_label, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(idle_hint_label.queue_free)
		idle_hint_label = null

func complete_transition():
	if awaiting_final_swing:
		awaiting_final_swing = false
		is_transitioning = true
		is_auto_completing = false
		angular_velocity = 0.0
		hide_idle_hint()
		await get_tree().create_timer(0.5).timeout
		story_finished.emit()
		return
	
	if current_story_index + 1 >= story_textures.size():
		return
	
	is_transitioning = true
	is_auto_completing = false
	angular_velocity = 0.0
	
	await get_tree().create_timer(0.4).timeout
	
	var transition_sound = load("res://audio/menu transition.ogg")
	if transition_sound:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = transition_sound
		audio_player.bus = "Master"
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(func(): audio_player.queue_free())
	
	current_story_index += 1
	image_bottom.texture = story_textures[current_story_index]
	
	if current_story_index + 1 < story_textures.size():
		image_top.texture = story_textures[current_story_index + 1]
		image_top.visible = true
		
		var shader_material = image_top.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("reveal_progress", 0.0)
			smoothed_reveal_progress = 0.0
			
			if image_top.texture:
				var tex_size = image_top.texture.get_size()
				shader_material.set_shader_parameter("aspect_ratio", tex_size.x / tex_size.y)
		
		_reset_swing_for_next_frame()
		setup_images()
		
	else:
		var shader_material = image_top.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("reveal_progress", 1.0)
		
		awaiting_final_swing = true
		_reset_swing_for_next_frame()
	
	is_transitioning = false

func _reset_swing_for_next_frame():
	var temp = start_angle
	start_angle = end_angle
	end_angle = temp
	is_swinging_right = !is_swinging_right
	current_angle = start_angle
	angular_velocity = 0
	is_dragging = false
	sound_played_this_swing = false
	frame_idle_time = 0.0
	hide_idle_hint()
