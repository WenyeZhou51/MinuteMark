extends CanvasLayer

enum TransitionType {
	SCREEN_TRANSITION,  # Texture-based dissolve
	POLKA_DOTS          # Circular dots dissolve
}

@export_group("Transition Settings")
@export var use_transition_effect: bool = true
@export var transition_type: TransitionType = TransitionType.SCREEN_TRANSITION
@export var transition_duration: float = 0.4
@export var transition_texture: Texture2D

@export_group("Animation Settings")
@export var pause_bg_fade_duration: float = 0.2  # Duration of pause background fade-in
@export var pocket_watch_fade_duration: float = 0.2  # Duration of pocket watch fade-in
@export var pocket_watch_fps: float = 10.0  # Speed of pocket watch animation (frames per second)
@export var white_overlay_slide_distance: float = 50.0  # Distance to slide white overlay
@export var white_overlay_slide_duration: float = 0.3  # Duration of white overlay slide
@export var menu_fade_duration: float = 0.3  # Duration of menu text/buttons fade-in

var transition_shader_screen: Shader = preload("res://shaders/screen_transition_shader.gdshader")
var transition_shader_polka: Shader = preload("res://shaders/polka_dots.gdshader")
var transition_rect: TextureRect
var is_transitioning: bool = false
var is_animating_in: bool = false

func _ready():
	# Initialize pause menu
	hide()
	
	# Load default transition texture if not set
	if transition_texture == null:
		transition_texture = load("res://textures/screen_transition_test.png")
	
	# Setup pocket watch animation frames
	setup_pocket_watch_animation()
	
	# Setup initial visibility states for animation elements
	if has_node("PauseBg"):
		$PauseBg.visible = false
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false


var pocket_watch_frames: Array[Texture2D] = []

func setup_pocket_watch_animation():
	"""Load pocket watch GIF frames"""
	if not has_node("PocketWatch"):
		return
	
	# Load all frame images
	var frame_path = "res://Sprites/pocket_watch_frames/frame_%04d.png"
	
	# Try loading frames (we have 11 frames: 0-10)
	for i in range(20):  # Try up to 20 frames to be safe
		var path = frame_path % i
		if ResourceLoader.exists(path):
			var texture = load(path)
			pocket_watch_frames.append(texture)
		else:
			break  # No more frames
	
	if pocket_watch_frames.size() > 0:
		print("Loaded %d frames for pocket watch animation" % pocket_watch_frames.size())
	else:
		push_warning("No pocket watch frames found! Make sure to run convert_gif_to_frames.py")


func _input(event):
	if event.is_action_pressed("ui_cancel") and not is_transitioning and not is_animating_in:  # ESC key by default
		toggle_pause()


func toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = true
		play_pause_menu_intro()
	else:
		# Play transition effect when exiting pause menu
		if use_transition_effect:
			play_exit_transition()
		else:
			visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func play_pause_menu_intro():
	"""Plays the complete pause menu introduction animation sequence"""
	is_animating_in = true
	
	# Step 1: Show pause background immediately
	if has_node("PauseBg"):
		$PauseBg.visible = true
		$PauseBg.modulate.a = 0.0
		var tween_bg = create_tween()
		tween_bg.tween_property($PauseBg, "modulate:a", 1.0, pause_bg_fade_duration)
	
	# Step 2: Wait a moment, then show pocket watch
	await get_tree().create_timer(pause_bg_fade_duration).timeout
	
	if has_node("PocketWatch") and pocket_watch_frames.size() > 0:
		$PocketWatch.visible = true
		$PocketWatch.modulate.a = 0.0
		
		# Set first frame
		$PocketWatch.texture = pocket_watch_frames[0]
		
		var tween_watch = create_tween()
		tween_watch.tween_property($PocketWatch, "modulate:a", 1.0, pocket_watch_fade_duration)
		
		# Play the animation by cycling through frames using the FPS inspector variable
		var time_per_frame = 1.0 / pocket_watch_fps
		
		for i in range(pocket_watch_frames.size()):
			await get_tree().create_timer(time_per_frame).timeout
			if has_node("PocketWatch"):
				$PocketWatch.texture = pocket_watch_frames[i]
		
		# Animation complete - pocket watch stays visible on last frame
	
	# Step 4: Show white overlay with slide-in effect
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = true
		$WhiteOverlay.modulate.a = 0.0
		$WhiteOverlay.position.x = -white_overlay_slide_distance
		
		var tween_overlay = create_tween()
		tween_overlay.set_parallel(true)
		tween_overlay.tween_property($WhiteOverlay, "modulate:a", 1.0, white_overlay_slide_duration)
		tween_overlay.tween_property($WhiteOverlay, "position:x", 0.0, white_overlay_slide_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tween_overlay.finished
	
	# Step 5: Show menu container (text and buttons)
	if has_node("MenuContainer"):
		$MenuContainer.visible = true
		$MenuContainer.modulate.a = 0.0
		var tween_menu = create_tween()
		tween_menu.tween_property($MenuContainer, "modulate:a", 1.0, menu_fade_duration)
		await tween_menu.finished
	
	# Animation complete, allow interaction
	is_animating_in = false
	if has_node("MenuContainer/ResumeButton"):
		$MenuContainer/ResumeButton.grab_focus()


func play_exit_transition():
	is_transitioning = true
	
	# Capture current viewport screenshot
	var img = get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(img)
	
	# Create transition overlay
	transition_rect = TextureRect.new()
	transition_rect.name = "TransitionOverlay"
	transition_rect.texture = texture
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.z_index = 1000  # Make sure it's on top
	
	# Apply the appropriate shader
	var shader_material = ShaderMaterial.new()
	if transition_type == TransitionType.SCREEN_TRANSITION:
		shader_material.shader = transition_shader_screen
		shader_material.set_shader_parameter("transition_pattern", transition_texture)
	else:  # POLKA_DOTS
		shader_material.shader = transition_shader_polka
	
	shader_material.set_shader_parameter("transition_state", 0.0)
	transition_rect.material = shader_material
	
	# Add to scene
	add_child(transition_rect)
	
	# Hide menu content but keep canvas layer visible for transition
	$MenuContainer.visible = false
	if has_node("Background"):
		$Background.visible = false
	
	# Hide animation elements
	if has_node("PauseBg"):
		$PauseBg.visible = false
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
	
	# Animate the transition
	var tween = create_tween()
	tween.tween_method(update_transition_state, 0.0, 1.0, transition_duration)
	tween.tween_callback(finish_exit_transition)


func update_transition_state(value: float):
	if transition_rect and transition_rect.material:
		transition_rect.material.set_shader_parameter("transition_state", value)


func finish_exit_transition():
	# Clean up transition overlay
	if transition_rect:
		remove_child(transition_rect)
		transition_rect.queue_free()
		transition_rect = null
	
	# Hide pause menu and restore game
	visible = false
	$MenuContainer.visible = true
	if has_node("Background"):
		$Background.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_transitioning = false
	
	# Reset animation elements for next time
	reset_animation_elements()


func reset_animation_elements():
	"""Reset all animation elements to their initial state"""
	if has_node("PauseBg"):
		$PauseBg.visible = false
		$PauseBg.modulate.a = 1.0
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
		$PocketWatch.modulate.a = 1.0
		# Reset to first frame
		if pocket_watch_frames.size() > 0:
			$PocketWatch.texture = pocket_watch_frames[0]
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 1.0
		$WhiteOverlay.position.x = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
		$MenuContainer.modulate.a = 1.0


func _on_resume_pressed():
	toggle_pause()


func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed():
	get_tree().quit()
